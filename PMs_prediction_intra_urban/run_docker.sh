#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 INPUT.csv[.gz] [IMAGE] [OUTPUT_DIR]"
  exit 2
fi

INPUT="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
IMAGE="${2:-ghcr.io/apemaiaproject/pms-prediction-intra-urban:latest}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

NAME="$(basename "${INPUT}")"
STEM="${NAME%.gz}"
STEM="${STEM%.csv}"
OUTPUT="${3:-${ROOT}/output/${STEM}}"
mkdir -p "${OUTPUT}"

if ! docker image inspect "${IMAGE}" >/dev/null 2>&1; then
  docker pull "${IMAGE}"
fi

docker run --rm \
  --mount "type=bind,source=$(dirname "${INPUT}"),target=/input,readonly" \
  --mount "type=bind,source=$(cd "${OUTPUT}" && pwd),target=/output" \
  -e "INPUT_PATH=/input/$(basename "${INPUT}")" \
  -e OUTPUT_DIR=/output \
  "${IMAGE}"

echo "Inference completed successfully."
echo "Results are in: ${OUTPUT}"
