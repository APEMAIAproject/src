#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 /path/to/input.csv[.gz] [image] [output_dir]" >&2
  exit 2
fi

INPUT=$(realpath "$1")
IMAGE=${2:-ghcr.io/apemaiaproject/pms-prediction:latest}
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
INPUT_DIR=$(dirname "$INPUT")
INPUT_NAME=$(basename "$INPUT")
case "${INPUT_NAME,,}" in
  *.csv.gz) STEM=${INPUT_NAME:0:${#INPUT_NAME}-7} ;;
  *.csv)    STEM=${INPUT_NAME:0:${#INPUT_NAME}-4} ;;
  *) echo "Input must be a .csv or .csv.gz file: $INPUT_NAME" >&2; exit 2 ;;
esac
SAFE_STEM=$(printf '%s' "$STEM" | sed 's/[^A-Za-z0-9._-]/_/g')
OUT=${3:-"$ROOT/output/$SAFE_STEM"}
mkdir -p "$OUT"
OUT=$(realpath "$OUT")

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "Docker image not found locally. Pulling: $IMAGE"
  docker pull "$IMAGE"
fi

echo "Running PM10/PM2.5 inference..."
echo "Image : $IMAGE"
echo "Input : $INPUT"
echo "Output: $OUT"

docker run --rm \
  --mount "type=bind,source=$INPUT_DIR,target=/input,readonly" \
  --mount "type=bind,source=$OUT,target=/output" \
  -e "INPUT_PATH=/input/$INPUT_NAME" \
  -e OUTPUT_DIR=/output \
  "$IMAGE"

echo "Inference completed successfully."
echo "Results are in: $OUT"
