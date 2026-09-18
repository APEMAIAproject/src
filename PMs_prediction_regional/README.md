# APEMAIA PM10 / PM2.5 Docker inference — v5.1.0

Inference-only Docker deployment for daily PM10 and PM2.5 prediction over the 300 m Puglia grid, with automatic Puglia and Bari spatial outputs and maps.

## What is embedded in the image

The published container contains everything required by the trained model except the inference CSV:

- pre-trained XGBoost model for PM10;
- pre-trained XGBoost model for PM2.5;
- minimal 300 m Puglia reference grid;
- minimal 300 m Bari reference grid;
- R inference and plotting code.

The user supplies only an already-preprocessed daily `.csv` or `.csv.gz` file that follows the input contract below. The container does **not** download, resample, clean, impute, scale, or otherwise preprocess raw environmental data.

Published image:

```text
ghcr.io/apemaiaproject/pms-prediction:latest
```


## Reproducibility quick test

The repository includes a complete compressed inference example at:

```text
examples/test.data.csv.gz
```

It contains **219,832 Puglia grid cells** for **2019-02-28** and the same 26 preprocessed predictor columns expected by the trained models. Manual decompression is not required.

After building locally:

```powershell
.\build_local.ps1
.\quick_test.ps1 -Image "pms-prediction:local"
```

Or, after the GHCR image has been published:

```powershell
.\quick_test.ps1 -Pull
```

The quick-test script runs the full inference and verifies that all nine expected output files were created under `output\example_test\`. See `examples/README.md` for details.

## Quick start on Windows

Requirements: Docker Desktop must be installed and running.

From this folder:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\run_docker.ps1 "C:\path\to\input_2026-09-14.csv"
```

Compressed CSV input is accepted directly as well:

```powershell
.\run_docker.ps1 "C:\path\to\input_2026-09-14.csv.gz"
```

If the image is not present locally, the script pulls it from GitHub Container Registry automatically. To explicitly refresh `latest`:

```powershell
.\run_docker.ps1 "C:\path\to\input_2026-09-14.csv" -Pull
```

By default, results are written to:

```text
output\input_2026-09-14\
```

A custom output directory can be supplied:

```powershell
.\run_docker.ps1 "C:\path\to\input.csv" -OutputDir "C:\path\to\results"
```

## Linux / macOS

```bash
chmod +x run_docker.sh
./run_docker.sh /path/to/input_2026-09-14.csv
```

## Build locally from source

Windows:

```powershell
.\build_local.ps1
.\run_docker.ps1 "C:\path\to\input.csv" -Image "pms-prediction:local"
```

Linux/macOS:

```bash
./build_local.sh
./run_docker.sh /path/to/input.csv pms-prediction:local
```

## Input contract

The input must be a `.csv` or gzip-compressed `.csv.gz` file representing one complete daily snapshot of the Puglia 300 m grid.

### Spatial and temporal requirements

- exactly **219,832 data rows**;
- exactly one row for each Puglia `FID`;
- `FID` values must cover the embedded reference grid exactly (`0`–`219831` in the supplied grid);
- no duplicate `FID` values;
- exactly one unique `Date` per run;
- `Date` format: `YYYY-MM-DD`;
- no missing, `Inf`, or `-Inf` predictor values;
- all 26 model predictors must already be preprocessed exactly as in model training.

The reference Puglia grid uses **EPSG:32632 (WGS 84 / UTM zone 32N)** and has nominal **300 m × 300 m** cells. Coastal/edge geometries can be clipped and therefore smaller.

The Bari grid uses the same CRS and nominal resolution. It contains 1,932 geometries representing 1,875 unique Puglia source cells; repeated identifiers correspond to clipped/split geometries and are intentional.

### Required columns

Metadata:

| Column | Type | Requirement |
|---|---|---|
| `FID` | integer-like numeric | Puglia grid-cell identifier; must match the embedded grid exactly. |
| `Date` | text/date | ISO format `YYYY-MM-DD`; one unique date per run. |

Predictors, with **exact names**:

| # | Column | Type | Interpretation / unit note |
|---:|---|---|---|
| 1 | `Temperature_2_m` | numeric | 2 m temperature; supplied test values are consistent with Kelvin. Preserve training preprocessing. |
| 2 | `u_wind_10_m` | numeric | 10 m zonal wind component; values are consistent with m/s. |
| 3 | `v_wind_10_m` | numeric | 10 m meridional wind component; values are consistent with m/s. |
| 4 | `Emissivity` | numeric | Surface emissivity; dimensionless. |
| 5 | `Rain_convective` | numeric | Convective precipitation variable; exact unit was not documented in the supplied package. |
| 6 | `Rain_not_convective` | numeric | Non-convective precipitation variable; preserve training preprocessing. |
| 7 | `vertical_wind` | numeric | Vertical-motion/wind variable; preserve training preprocessing. |
| 8 | `specific_humidity_2m` | numeric | 2 m specific humidity; preserve training convention. |
| 9 | `Surface_temperature` | numeric | Surface temperature; supplied test values are consistent with Kelvin. |
| 10 | `Cloud_fraction` | numeric | Cloud-fraction variable; preserve training preprocessing. |
| 11 | `Surface_pressure` | numeric | Surface pressure; supplied test values are consistent with Pa. |
| 12 | `AOD_sat` | numeric | Satellite aerosol optical depth; dimensionless. |
| 13 | `NO2_sat` | numeric | Satellite NO2 variable; exact product/unit was not documented in the supplied package. |
| 14 | `O3_sat` | numeric | Satellite O3 variable; exact product/unit was not documented in the supplied package. |
| 15 | `sin.month` | numeric | Precomputed cyclic month encoding. |
| 16 | `cos.month` | numeric | Precomputed cyclic month encoding. |
| 17 | `sin.week` | numeric | Precomputed cyclic week encoding. |
| 18 | `cos.week` | numeric | Precomputed cyclic week encoding. |
| 19 | `v_wind` | numeric | Wind-speed magnitude; in the supplied test set it equals `sqrt(u_wind_10_m^2 + v_wind_10_m^2)`. |
| 20 | `pop` | numeric | Population-related cell covariate; preserve training preprocessing. |
| 21 | `buildings_tot` | numeric/integer | Building-related cell covariate; preserve training preprocessing. |
| 22 | `roads_tot` | numeric | Road-related cell covariate; preserve training preprocessing. |
| 23 | `corine` | numeric/integer | CORINE land-cover code/covariate used during training. |
| 24 | `Continuous.urban.fabric` | numeric | Continuous urban-fabric covariate/fraction used during training. |
| 25 | `Discontinuous.urban.fabric` | numeric | Discontinuous urban-fabric covariate/fraction used during training. |
| 26 | `Industrial.or.commercial.units` | numeric | Industrial/commercial land-use covariate/fraction used during training. |

A header-only template is included as `input_template.csv`.

**Important:** matching column names is not enough. Each variable must use the same data source, physical units, spatial aggregation/resampling, scaling, and preprocessing used to create the training data. Where the original supplied package did not document a physical unit, this deployment intentionally does not infer or convert it.

An optional first CSV row-index column named `Unnamed: 0`, `X`, `...1`, or `row.names` is ignored automatically. Other unexpected columns are rejected.

## Bundled example: expected result

For `examples/test.data.csv.gz`, a successful run must complete without validation errors and create the following files:

```text
predictions.csv
predictions_puglia.gpkg
predictions_bari.gpkg
PM2.5_Puglia.png
PM10_Puglia.png
PM2.5_Bari.png
PM10_Bari.png
run_metadata.txt
sessionInfo.txt
```

The expected metadata invariants are:

- input date: `2019-02-28`;
- input rows: `219832`;
- predictors: `26`;
- Puglia spatial rows: `219832`;
- Bari geometry rows: `1932`;
- Bari unique source cells: `1875`;
- CRS: EPSG:32632.

Exact PNG/GPKG byte hashes are intentionally not used as acceptance criteria because geospatial library serialization and rendering metadata may differ between compatible runtimes. The model/runtime versions are pinned in the Docker image for prediction reproducibility.

## Outputs

Each successful run writes:

- `predictions.csv` — `FID`, `Date`, PM2.5 prediction, PM10 prediction;
- `predictions_puglia.gpkg` — georeferenced predictions for the full Puglia grid;
- `predictions_bari.gpkg` — georeferenced predictions for Bari;
- `PM2.5_Puglia.png`;
- `PM10_Puglia.png`;
- `PM2.5_Bari.png`;
- `PM10_Bari.png`;
- `run_metadata.txt`;
- `sessionInfo.txt`.

For each pollutant, the Puglia and Bari maps use the same colour limits, so the regional and local maps are directly comparable.

The CSV retains the identifier name `FID`. GeoPackage outputs use `source_FID` because `FID` is reserved by GDAL/GeoPackage as an internal feature identifier.

Raw XGBoost outputs are preserved; the container does not clip negative predictions or apply post-hoc corrections.

## Embedded spatial assets

The original Puglia shapefile included many attributes and a DBF of more than 200 MB. Those attributes are not required for inference because all model covariates come from the input CSV.

For deployment, the spatial assets were reduced to **identifier + geometry only**:

- Puglia: 219,832 geometries, EPSG:32632;
- Bari: 1,932 geometries, 1,875 unique source identifiers, EPSG:32632.

The repository stores the minimal GeoPackages as ZIP archives to keep Git lightweight; Docker expands them once at image-build time. See `spatial/README.md`.

## Example-data redistribution note

The bundled test dataset is included for reproducibility and smoke testing. Before making the repository public, project maintainers should confirm that redistribution of the derived variables is compatible with the licences or terms of the upstream data sources used to create them.

## Model/runtime compatibility

The supplied `xg.pm10` and `xg.pm2.5` files use the legacy XGBoost binary model format. The Docker image therefore pins the R package `xgboost` to **1.7.11.1**, the version used and tested for this deployment.

The base image is `rocker/geospatial:4.4.3`.

## GitHub Container Registry

The workflow at `.github/workflows/pms-prediction-container.yml` builds this folder and publishes:

```text
ghcr.io/apemaiaproject/pms-prediction:latest
```

It also publishes the version tag `5.1.0` and a commit-SHA tag for reproducibility. The first package created by GHCR may need to be made public once from the package settings of the APEMAIA organization/repository.
