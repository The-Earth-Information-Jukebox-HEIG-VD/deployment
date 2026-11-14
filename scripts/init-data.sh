#!/bin/bash
# Initialize data volume from the datasets container
# Usage: ./scripts/init-data.sh [version]
#   version defaults to DATASETS_VERSION from .env (then DATA_TAG, then latest)
#
# This script manually triggers data initialization, useful for:
# - Pre-populating volumes before starting services
# - Updating data to a new version

set -e

cd "$(dirname "$0")/.."
if [ -f .env ]; then set -a; . ./.env; set +a; fi
TAG="${1:-${DATASETS_VERSION:-${DATA_TAG:-latest}}}"
REGISTRY="ghcr.io/the-earth-information-jukebox-heig-vd"

echo "=== Earth Information Jukebox: Data Initialization ==="
echo "Using datasets image: ${REGISTRY}/datasets:${TAG}"
echo

# Pull the latest datasets image
echo "Pulling datasets image..."
docker pull "${REGISTRY}/datasets:${TAG}"

# Create volume if it doesn't exist
docker volume create jukebox-data 2>/dev/null || true

# Run the init container
echo "Copying data to volume..."
docker run --rm \
    -v jukebox-data:/data \
    "${REGISTRY}/datasets:${TAG}" \
    sh -c "cp -r /datasets/. /data/ && touch /data/.initialized"

echo
echo "Data initialization complete!"
echo "Volume contents:"
docker run --rm -v jukebox-data:/data alpine ls -la /data
