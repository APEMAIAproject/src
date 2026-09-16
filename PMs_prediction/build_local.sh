#!/usr/bin/env bash
set -euo pipefail
IMAGE=${1:-pms-prediction:local}
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
echo "Building local image: $IMAGE"
docker build -t "$IMAGE" "$ROOT"
echo "Local image built successfully: $IMAGE"
echo "Run it with: ./run_docker.sh /path/to/input.csv[.gz] $IMAGE"
