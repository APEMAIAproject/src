#!/usr/bin/env bash
set -euo pipefail
IMAGE="${1:-pms-prediction-intra-urban:local}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Building local image: ${IMAGE}"
docker build -t "${IMAGE}" "${ROOT}"
echo "Build completed: ${IMAGE}"
