#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="${1:-ghcr.io/apemaiaproject/pms-prediction-intra-urban:latest}"
"${ROOT}/run_docker.sh" "${ROOT}/examples/bari_2022_07_25.csv.gz" "${IMAGE}" "${ROOT}/output/example_test"

for f in predictions.csv predictions_bari.geojson PM10_Bari_intra_urban_2022-07-25.png run_metadata.json environment.txt; do
  test -s "${ROOT}/output/example_test/${f}" || { echo "Missing output: ${f}"; exit 1; }
done

rows=$(( $(wc -l < "${ROOT}/output/example_test/predictions.csv") - 1 ))
[[ "${rows}" -eq 5394 ]] || { echo "Expected 5394 rows, found ${rows}"; exit 1; }

echo "Quick test PASSED."
