#!/usr/bin/env bash
set -e

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <IMMICH_API_KEY> <PATH_TO_TAKEOUT_ZIPS_FOLDER>"
    echo "Example: $0 xxxxyyyyzzzz /mnt/external_drive/takeout"
    exit 1
fi

API_KEY="$1"
TAKEOUT_DIR="$(realpath "$2")"

echo "Starting immich-go via Podman to import from $TAKEOUT_DIR..."
echo "This will upload all .zip files found in the directory and automatically reconstruct your Google Photos albums."

podman run --rm -it \
  -v "$TAKEOUT_DIR:/takeout:ro" \
  --network host \
  ghcr.io/simulot/immich-go:v0.20.0 \
  -server http://localhost:2283 \
  -key "$API_KEY" \
  upload -create-albums /takeout/*.zip

echo "✅ Import complete!"
