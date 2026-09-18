suppressPackageStartupMessages({
  library(ggplot2)
  library(sf)
  library(xgboost)
  library(viridis)
})

message("R version: ", R.version.string)
message("xgboost version: ", as.character(packageVersion("xgboost")))
message("sf version: ", as.character(packageVersion("sf")))

model_dir <- Sys.getenv("MODEL_DIR", "/opt/pms/models")
spatial_dir <- Sys.getenv("SPATIAL_DIR", "/opt/pms/spatial")
output_dir <- Sys.getenv("OUTPUT_DIR", "/output")
input_path <- Sys.getenv("INPUT_PATH", "/input/input.csv")
input_label <- basename(input_path)

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

expected_features <- c(
  "Temperature_2_m",
  "u_wind_10_m",
  "v_wind_10_m",
  "Emissivity",
  "Rain_convective",
  "Rain_not_convective",
  "vertical_wind",
  "specific_humidity_2m",
  "Surface_temperature",
  "Cloud_fraction",
  "Surface_pressure",
  "AOD_sat",
  "NO2_sat",
  "O3_sat",
  "sin.month",
  "cos.month",
  "sin.week",
  "cos.week",
  "v_wind",
  "pop",
  "buildings_tot",
  "roads_tot",
  "corine",
  "Continuous.urban.fabric",
  "Discontinuous.urban.fabric",
  "Industrial.or.commercial.units"
)

model_pm25_path <- file.path(model_dir, "xg.pm2.5")
model_pm10_path <- file.path(model_dir, "xg.pm10")
puglia_grid_path <- file.path(spatial_dir, "grid_puglia_minimal.gpkg")
bari_grid_path <- file.path(spatial_dir, "grid_bari_minimal.gpkg")

required_assets <- c(model_pm25_path, model_pm10_path, puglia_grid_path, bari_grid_path)
missing_assets <- required_assets[!file.exists(required_assets)]
if (length(missing_assets) > 0) {
  stop("Container assets are missing: ", paste(missing_assets, collapse = ", "))
}
if (!file.exists(input_path)) {
  stop("Input CSV not found inside container: ", input_path)
}

message("Loading XGBoost models...")
model_pm25 <- xgb.load(model_pm25_path)
model_pm10 <- xgb.load(model_pm10_path)

message("Reading input: ", input_label)
is_gzip <- grepl("\\.csv\\.gz$", input_path, ignore.case = TRUE)
is_csv <- grepl("\\.csv$", input_path, ignore.case = TRUE)
if (!is_gzip && !is_csv) {
  stop("Input must be a .csv or .csv.gz file: ", input_label)
}

if (is_gzip) {
  input_connection <- gzfile(input_path, open = "rt")
  raw_input <- tryCatch(
    read.csv(
      input_connection,
      check.names = FALSE,
      stringsAsFactors = FALSE
    ),
    finally = close(input_connection)
  )
} else {
  raw_input <- read.csv(
    input_path,
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
}

# Ignore one common CSV-export row-number column if present.
if (ncol(raw_input) > 0) {
  first_name <- names(raw_input)[1]
  first_col <- raw_input[[1]]
  looks_like_index_name <- first_name %in% c("Unnamed: 0", "X", "...1", "row.names")
  looks_like_row_index <- is.numeric(first_col) && length(first_col) == nrow(raw_input) &&
    all(first_col == seq_len(nrow(raw_input)))
  if (looks_like_index_name || looks_like_row_index) {
    raw_input <- raw_input[, -1, drop = FALSE]
  }
}

required_columns <- c("FID", "Date", expected_features)
missing_columns <- setdiff(required_columns, names(raw_input))
extra_columns <- setdiff(names(raw_input), required_columns)

if (length(missing_columns) > 0) {
  stop("Input is missing required columns: ", paste(missing_columns, collapse = ", "))
}
if (length(extra_columns) > 0) {
  stop(
    "Input contains unexpected columns: ", paste(extra_columns, collapse = ", "),
    ". Keep only FID, Date and the 26 documented predictor columns."
  )
}

# The old XGBoost binary models do not reliably protect against a reordered matrix.
# Enforce the exact predictor order explicitly.
raw_input <- raw_input[, required_columns, drop = FALSE]

if (!is.numeric(raw_input$FID)) {
  raw_input$FID <- suppressWarnings(as.numeric(raw_input$FID))
}
if (anyNA(raw_input$FID) || any(abs(raw_input$FID - round(raw_input$FID)) > 1e-9)) {
  stop("FID must contain integer-like numeric values with no missing values.")
}
raw_input$FID <- as.integer(round(raw_input$FID))

if (anyDuplicated(raw_input$FID)) {
  stop("Duplicate FID values found in input. Exactly one row per Puglia grid cell is required.")
}

if (length(unique(raw_input$Date)) != 1) {
  stop(
    "This inference image expects exactly one Date per run. Found ",
    length(unique(raw_input$Date)), " unique dates."
  )
}

parsed_date <- as.Date(raw_input$Date, format = "%Y-%m-%d")
if (anyNA(parsed_date)) {
  stop("Date must use ISO format YYYY-MM-DD, e.g. 2019-02-28.")
}

non_numeric <- expected_features[!vapply(raw_input[expected_features], is.numeric, logical(1))]
if (length(non_numeric) > 0) {
  stop("These predictor columns are not numeric: ", paste(non_numeric, collapse = ", "))
}

x_pred <- as.matrix(raw_input[, expected_features, drop = FALSE])
if (anyNA(x_pred)) {
  stop("Predictor matrix contains NA values. The inference input must be fully populated.")
}
if (any(!is.finite(x_pred))) {
  stop("Predictor matrix contains Inf/-Inf values.")
}

message("Prediction matrix: ", nrow(x_pred), " rows x ", ncol(x_pred), " features")

message("Reading embedded Puglia and Bari grids...")
puglia <- st_read(puglia_grid_path, layer = "grid_puglia", quiet = TRUE)
bari <- st_read(bari_grid_path, layer = "grid_bari", quiet = TRUE)

for (nm in c("puglia", "bari")) {
  obj <- get(nm)
  if (!"source_FID" %in% names(obj)) stop(nm, " grid does not contain source_FID.")
  if (is.na(st_crs(obj))) stop(nm, " grid has no CRS.")
  if (any(st_is_empty(obj))) stop(nm, " grid contains empty geometries.")
}

if (st_crs(puglia) != st_crs(bari)) {
  stop("Puglia and Bari grids use different CRS values.")
}

puglia_fid <- as.integer(round(as.numeric(puglia$source_FID)))
bari_fid <- as.integer(round(as.numeric(bari$source_FID)))

if (nrow(puglia) != 219832L || length(unique(puglia_fid)) != 219832L) {
  stop("Embedded Puglia grid is not the expected 219,832-cell reference grid.")
}
if (anyDuplicated(puglia_fid)) {
  stop("Embedded Puglia grid contains duplicate source_FID values.")
}
if (!setequal(raw_input$FID, puglia_fid)) {
  missing_in_input <- setdiff(puglia_fid, raw_input$FID)
  unknown_in_input <- setdiff(raw_input$FID, puglia_fid)
  stop(
    "Input FID coverage does not match the embedded Puglia grid. Missing FIDs: ",
    length(missing_in_input), "; unknown FIDs: ", length(unknown_in_input), "."
  )
}
if (!all(bari_fid %in% puglia_fid)) {
  stop("Some embedded Bari source_FID values are absent from the Puglia reference grid.")
}

message("Predicting PM2.5 and PM10...")
pred_pm25 <- predict(model_pm25, x_pred)
pred_pm10 <- predict(model_pm10, x_pred)

if (length(pred_pm25) != nrow(raw_input) || length(pred_pm10) != nrow(raw_input)) {
  stop("Prediction length does not match input row count.")
}

pred_table <- data.frame(
  FID = raw_input$FID,
  Date = format(parsed_date, "%Y-%m-%d"),
  PM2_5_pred = as.numeric(pred_pm25),
  PM10_pred = as.numeric(pred_pm10),
  check.names = FALSE
)
write.csv(pred_table, file.path(output_dir, "predictions.csv"), row.names = FALSE)

# Join predictions by FID. Input row order is irrelevant.
pred_idx <- setNames(seq_len(nrow(pred_table)), as.character(pred_table$FID))

p_idx <- unname(pred_idx[as.character(puglia_fid)])
puglia_map <- puglia[, "source_FID", drop = FALSE]
puglia_map$PM2_5_pred <- pred_table$PM2_5_pred[p_idx]
puglia_map$PM10_pred <- pred_table$PM10_pred[p_idx]

# Bari can contain multiple clipped geometries with the same source_FID.
# Each piece intentionally receives the prediction of the same Puglia source cell.
b_idx <- unname(pred_idx[as.character(bari_fid)])
bari_map <- bari[, "source_FID", drop = FALSE]
bari_map$PM2_5_pred <- pred_table$PM2_5_pred[b_idx]
bari_map$PM10_pred <- pred_table$PM10_pred[b_idx]

message("Writing spatial outputs...")
st_write(
  puglia_map,
  file.path(output_dir, "predictions_puglia.gpkg"),
  layer = "pm_predictions_puglia",
  delete_dsn = TRUE,
  quiet = TRUE
)
st_write(
  bari_map,
  file.path(output_dir, "predictions_bari.gpkg"),
  layer = "pm_predictions_bari",
  delete_dsn = TRUE,
  quiet = TRUE
)

plot_date <- unique(pred_table$Date)

safe_range <- function(x) {
  r <- range(x, finite = TRUE)
  if (!all(is.finite(r))) stop("Cannot create map scale: prediction range is not finite.")
  if (r[1] == r[2]) {
    eps <- max(abs(r[1]) * 1e-6, 1e-6)
    r <- c(r[1] - eps, r[2] + eps)
  }
  r
}

make_map <- function(sf_data, value_col, pollutant_label, area_label, limits) {
  ggplot(sf_data) +
    geom_sf(aes(fill = .data[[value_col]]), color = NA, linewidth = 0) +
    scale_fill_viridis_c(
      option = "plasma",
      name = paste0(pollutant_label, "\nprediction"),
      limits = limits,
      na.value = "grey90"
    ) +
    coord_sf(datum = NA, expand = FALSE) +
    labs(
      title = paste0(pollutant_label, " prediction - ", area_label),
      subtitle = plot_date,
      caption = "Inference from embedded pre-trained XGBoost model"
    ) +
    theme_void(base_size = 12) +
    theme(
      plot.title = element_text(hjust = 0.5, face = "bold", size = 15),
      plot.subtitle = element_text(hjust = 0.5),
      plot.caption = element_text(hjust = 1, size = 8),
      legend.position = "right"
    )
}

# Use one common scale per pollutant for Puglia and Bari.
lim25 <- safe_range(puglia_map$PM2_5_pred)
lim10 <- safe_range(puglia_map$PM10_pred)

plots <- list(
  "PM2.5_Puglia.png" = make_map(puglia_map, "PM2_5_pred", "PM2.5", "Puglia", lim25),
  "PM10_Puglia.png"  = make_map(puglia_map, "PM10_pred", "PM10", "Puglia", lim10),
  "PM2.5_Bari.png"   = make_map(bari_map, "PM2_5_pred", "PM2.5", "Bari", lim25),
  "PM10_Bari.png"    = make_map(bari_map, "PM10_pred", "PM10", "Bari", lim10)
)

message("Saving maps...")
for (fn in names(plots)) {
  is_bari <- grepl("Bari", fn, fixed = TRUE)
  ggsave(
    file.path(output_dir, fn),
    plot = plots[[fn]],
    width = 9,
    height = if (is_bari) 7 else 10,
    dpi = 200,
    bg = "white"
  )
}

metadata <- c(
  "deployment_version=5.1.0",
  paste0("input_file=", input_label),
  paste0("input_path=", input_path),
  paste0("date=", plot_date),
  paste0("rows=", nrow(raw_input)),
  paste0("predictors=", length(expected_features)),
  paste0("puglia_grid_rows=", nrow(puglia_map)),
  paste0("bari_geometry_rows=", nrow(bari_map)),
  paste0("bari_unique_FID=", length(unique(bari_fid))),
  paste0("crs=", st_crs(puglia)$input),
  paste0("pm25_min=", min(pred_pm25)),
  paste0("pm25_max=", max(pred_pm25)),
  paste0("pm10_min=", min(pred_pm10)),
  paste0("pm10_max=", max(pred_pm10))
)
writeLines(metadata, file.path(output_dir, "run_metadata.txt"))
capture.output(sessionInfo(), file = file.path(output_dir, "sessionInfo.txt"))

message("Done. Outputs written to: ", normalizePath(output_dir, mustWork = FALSE))
message(" - predictions.csv")
message(" - predictions_puglia.gpkg")
message(" - predictions_bari.gpkg")
message(" - PM2.5_Puglia.png")
message(" - PM10_Puglia.png")
message(" - PM2.5_Bari.png")
message(" - PM10_Bari.png")
message(" - run_metadata.txt")
message(" - sessionInfo.txt")
