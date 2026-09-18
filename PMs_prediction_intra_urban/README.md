# APEMAIA PM10 intra-urban inference

Inference-only Docker container for the **intra-urban PM10 model over Bari**.

This component is intentionally separated from the regional PM10/PM2.5 container. The regional model covers the Puglia-scale workflow, while this container runs the high-resolution Bari intra-urban XGBoost PM10 model.

## Scope

- pollutant: **PM10**
- model: **XGBoost regression**
- temporal resolution: **daily**
- spatial spacing of the supplied inference example: approximately **300 m**
- supplied example domain: Bari intra-urban study area
- inference only: **no training is performed inside the container**

The supplied XGBoost model contains **500 trees** and expects exactly **26 model features**. The feature order is stored in `models/PM10_XGB_BARI_model_features.joblib` and is validated at runtime. The model JSON itself contains the same feature names.

## Input contract

The container accepts `.csv` and `.csv.gz` files.

Each row represents one spatial cell / location for one day. The input must contain the following metadata columns:

| Column | Type | Purpose |
|---|---|---|
| `id` | integer/numeric | spatial-cell identifier |
| `Latitude` | numeric | latitude used for map/GeoJSON output |
| `Longitude` | numeric | longitude used for map/GeoJSON output |
| `Date` | date-like string | daily prediction date; `YYYY-MM-DD` is recommended |

and these **26 model features, with exactly these names**:

```
PBLH_daily_mean
P_daily_mean
T2_daily_mean
U_daily_mean
V_daily_mean
MODV
RAINC_daily
RH_daily_mean
NETRAD_daily_mean
TOTRAD_daily_mean
DUST_CONC
doy
dow
month_sin
day_sin
day_cos
LST
AOD
NDVI
POPgr
HHmean
BUclass__1
BUclass__3
WATER
BARE_SOIL
urbanity_fuzzy_3km
```

The four metadata columns are not model predictors; they are retained for output and mapping.

### Units and preprocessing

The artifacts supplied with the model do **not** document the physical units or all upstream preprocessing conventions for each predictor. Therefore the container does not transform, rescale, impute, or reinterpret the predictors. New input data must be generated with the **same preprocessing and units used to create the model inputs**.

The feature names indicate the roles of meteorological, aerosol/satellite, land-use and urban-form predictors, but those names alone should not be treated as a complete unit specification.

### Missing values

XGBoost can process missing feature values natively. The supplied test dataset contains missing values in:

- `LST`: 1380
- `POPgr`: 1130
- `HHmean`: 1244
- `urbanity_fuzzy_3km`: 688

No imputation is performed by this container. `Latitude` and `Longitude` must not be missing.

Extra input columns are allowed and ignored by the model. Missing required columns cause the run to stop with an explicit error.

## Supplied test data

`examples/bari_2022_07_25.csv.gz` contains:

- **5,394 rows**
- one date: **2022-07-25**
- **26 model features**
- 5,394 unique `id` values
- approximate 300 m spatial spacing

Reference prediction summary:

| Statistic | PM10 prediction |
|---|---:|
| Minimum | 22.099945 |
| Mean | 30.459034 |
| Median | 30.489225 |
| Maximum | 43.888046 |

These values are used to make the bundled quick test sensitive to accidental model/input changes.

## Outputs

For each inference run the container writes:

- `predictions.csv` — `id`, coordinates, date and `PM10_pred`
- `predictions_bari.geojson` — point GeoJSON for GIS use
- `PM10_Bari_intra_urban_<DATE>.png` — one map for each date in the input
- `run_metadata.json` — input, features, missingness and prediction summary
- `environment.txt` — software versions used inside the container

The input currently provides point centres rather than the original cell polygons, so the GIS output is deliberately a **point GeoJSON**; the container does not invent polygon boundaries.

## Local build

Requirements: Docker Desktop (Windows) or Docker Engine (Linux/macOS).

Windows PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\build_local.ps1
```

This creates:

```text
pms-prediction-intra-urban:local
```

## Quick test

Windows:

```powershell
.\quick_test.ps1 -Image "pms-prediction-intra-urban:local"
```

Linux/macOS:

```bash
./quick_test.sh pms-prediction-intra-urban:local
```

The Windows quick test verifies the expected 5,394 prediction rows and the reference mean prediction.

## Run a new preprocessed dataset

Windows:

```powershell
.\run_docker.ps1 "C:\path\to\my_input.csv" -Image "pms-prediction-intra-urban:local"
```

Compressed input:

```powershell
.\run_docker.ps1 "C:\path\to\my_input.csv.gz" -Image "pms-prediction-intra-urban:local"
```

After publication to GHCR:

```powershell
.\run_docker.ps1 "C:\path\to\my_input.csv" `
  -Image "ghcr.io/apemaiaproject/pms-prediction-intra-urban:latest"
```

If the requested image is not available locally, the launcher pulls it automatically.

## Repository organization

Recommended APEMAIA layout:

```text
src/
├── PMs_prediction_regional/
└── PMs_prediction_intra_urban/
```

The existing regional image can keep the compatibility tag:

```text
ghcr.io/apemaiaproject/pms-prediction:latest
```

while the intra-urban image is published separately as:

```text
ghcr.io/apemaiaproject/pms-prediction-intra-urban:latest
```

This prevents existing regional users from being broken by the repository reorganization.
