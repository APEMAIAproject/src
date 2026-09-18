#!/usr/bin/env python3
import json
import math
import os
import platform
import sys
from pathlib import Path

import joblib
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import xgboost as xgb


def fail(message: str) -> None:
    raise RuntimeError(message)


def safe_date_label(value) -> str:
    s = str(value)
    return "".join(ch if ch.isalnum() or ch in "-_." else "_" for ch in s)


def write_geojson(df: pd.DataFrame, output_path: Path) -> None:
    features = []
    for row in df.itertuples(index=False):
        features.append(
            {
                "type": "Feature",
                "geometry": {
                    "type": "Point",
                    "coordinates": [float(row.Longitude), float(row.Latitude)],
                },
                "properties": {
                    "id": int(row.id) if pd.notna(row.id) else None,
                    "Date": str(row.Date),
                    "PM10_pred": float(row.PM10_pred),
                },
            }
        )
    output_path.write_text(
        json.dumps({"type": "FeatureCollection", "features": features}),
        encoding="utf-8",
    )


def save_map(day_df: pd.DataFrame, output_path: Path, date_label: str) -> None:
    fig, ax = plt.subplots(figsize=(9, 7))
    sc = ax.scatter(
        day_df["Longitude"],
        day_df["Latitude"],
        c=day_df["PM10_pred"],
        marker="s",
        s=14,
        linewidths=0,
    )
    cb = fig.colorbar(sc, ax=ax)
    cb.set_label("PM10 prediction")
    ax.set_title(f"PM10 intra-urban prediction - Bari - {date_label}")
    ax.set_xlabel("Longitude")
    ax.set_ylabel("Latitude")

    mean_lat = float(day_df["Latitude"].mean())
    if np.isfinite(mean_lat):
        ax.set_aspect(1.0 / math.cos(math.radians(mean_lat)))

    fig.tight_layout()
    fig.savefig(output_path, dpi=180, bbox_inches="tight")
    plt.close(fig)


def main() -> None:
    input_path = Path(os.environ.get("INPUT_PATH", "/input/input.csv"))
    output_dir = Path(os.environ.get("OUTPUT_DIR", "/output"))
    model_dir = Path(os.environ.get("MODEL_DIR", "/opt/pms/models"))

    model_path = model_dir / "PM10_XGB_BARI_model.json"
    feature_path = model_dir / "PM10_XGB_BARI_model_features.joblib"

    if not input_path.is_file():
        fail(f"Input file not found: {input_path}")
    if input_path.name.lower().endswith((".csv", ".csv.gz")) is False:
        fail("Input must be a .csv or .csv.gz file.")
    if not model_path.is_file():
        fail(f"Model file not found: {model_path}")
    if not feature_path.is_file():
        fail(f"Feature-list file not found: {feature_path}")

    output_dir.mkdir(parents=True, exist_ok=True)

    print(f"Python version: {platform.python_version()}")
    print(f"xgboost version: {xgb.__version__}")
    print(f"pandas version: {pd.__version__}")
    print(f"Reading input: {input_path}")

    df = pd.read_csv(input_path)
    features = joblib.load(feature_path)

    if not isinstance(features, (list, tuple)) or len(features) == 0:
        fail("The model feature list is invalid.")

    metadata_cols = ["id", "Latitude", "Longitude", "Date"]
    required = metadata_cols + list(features)
    missing = [c for c in required if c not in df.columns]
    if missing:
        fail("Missing required input columns: " + ", ".join(missing))

    if len(set(features)) != len(features):
        fail("Duplicate feature names were found in the model feature list.")

    for c in list(features) + ["id", "Latitude", "Longitude"]:
        try:
            df[c] = pd.to_numeric(df[c], errors="raise")
        except Exception as exc:
            fail(f"Column '{c}' must be numeric: {exc}")

    if df[["Latitude", "Longitude"]].isna().any().any():
        fail("Latitude and Longitude cannot contain missing values.")

    parsed_dates = pd.to_datetime(df["Date"], errors="coerce")
    if parsed_dates.isna().any():
        bad = int(parsed_dates.isna().sum())
        fail(f"Date contains {bad} unparseable value(s).")
    df["Date"] = parsed_dates.dt.strftime("%Y-%m-%d")

    if df.duplicated(subset=["Date", "id"]).any():
        ndup = int(df.duplicated(subset=["Date", "id"]).sum())
        fail(f"Found {ndup} duplicate (Date, id) row(s).")

    # Use the native XGBoost Booster API. This avoids requiring scikit-learn
    # at inference time while preserving the exact trained model.
    model = xgb.Booster()
    model.load_model(model_path)

    booster_names = model.feature_names
    if booster_names is not None and list(booster_names) != list(features):
        fail(
            "Feature-order mismatch between model JSON and feature-list file. "
            "The container will not reorder or guess features."
        )

    print(f"Rows: {len(df)}")
    print(f"Dates: {df['Date'].nunique()}")
    print(f"Model features: {len(features)}")
    print("Predicting PM10...")

    dmatrix = xgb.DMatrix(df[list(features)], feature_names=list(features))
    df["PM10_pred"] = model.predict(dmatrix)

    output_cols = ["id", "Latitude", "Longitude", "Date", "PM10_pred"]
    predictions = df[output_cols].copy()
    predictions.to_csv(output_dir / "predictions.csv", index=False)
    write_geojson(predictions, output_dir / "predictions_bari.geojson")

    generated_maps = []
    for date_value, day_df in predictions.groupby("Date", sort=True):
        label = safe_date_label(date_value)
        map_name = f"PM10_Bari_intra_urban_{label}.png"
        save_map(day_df, output_dir / map_name, str(date_value))
        generated_maps.append(map_name)

    feature_missing = {c: int(df[c].isna().sum()) for c in features if int(df[c].isna().sum()) > 0}
    metadata = {
        "pipeline": "APEMAIA PM10 intra-urban inference",
        "version": "1.0.1",
        "input_file": input_path.name,
        "rows": int(len(df)),
        "dates": sorted(df["Date"].unique().tolist()),
        "feature_count": int(len(features)),
        "features": list(features),
        "missing_feature_values": feature_missing,
        "prediction_summary": {
            "min": float(predictions["PM10_pred"].min()),
            "max": float(predictions["PM10_pred"].max()),
            "mean": float(predictions["PM10_pred"].mean()),
            "median": float(predictions["PM10_pred"].median()),
        },
        "outputs": ["predictions.csv", "predictions_bari.geojson"] + generated_maps,
    }
    (output_dir / "run_metadata.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")

    env_text = "\n".join(
        [
            f"python={platform.python_version()}",
            f"pandas={pd.__version__}",
            f"xgboost={xgb.__version__}",
            f"joblib={joblib.__version__}",
            f"matplotlib={matplotlib.__version__}",
        ]
    ) + "\n"
    (output_dir / "environment.txt").write_text(env_text, encoding="utf-8")

    print("Prediction completed.")
    print(
        "PM10 summary: "
        f"min={predictions['PM10_pred'].min():.6f}, "
        f"mean={predictions['PM10_pred'].mean():.6f}, "
        f"max={predictions['PM10_pred'].max():.6f}"
    )
    print(f"Outputs written to: {output_dir}")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
