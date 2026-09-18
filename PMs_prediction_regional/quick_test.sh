#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
IMAGE=${1:-ghcr.io/apemaiaproject/pms-prediction:latest}
EXAMPLE="$ROOT/examples/test.data.csv.gz"
OUT="$ROOT/output/example_test"

"$ROOT/run_docker.sh" "$EXAMPLE" "$IMAGE" "$OUT"

required=(
  predictions.csv predictions_puglia.gpkg predictions_bari.gpkg
  PM2.5_Puglia.png PM10_Puglia.png PM2.5_Bari.png PM10_Bari.png
  run_metadata.txt sessionInfo.txt
)
for f in "${required[@]}"; do
  [[ -s "$OUT/$f" ]] || { echo "Missing expected output: $OUT/$f" >&2; exit 1; }
done
echo "Quick test PASSED. All expected outputs are present in: $OUT"
