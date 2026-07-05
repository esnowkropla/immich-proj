#!/usr/bin/env bash
set -e

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <IMMICH_API_KEY> <PATH_TO_TAKEOUT_ZIPS_FOLDER>"
    echo "Example: $0 xxxxyyyyzzzz /mnt/external_drive/takeout"
    exit 1
fi

API_KEY="$1"
TAKEOUT_DIR="$(realpath "$2")"

echo "Preparing to import from $TAKEOUT_DIR..."
echo "This will upload all .zip files found in the directory and automatically reconstruct your Google Photos albums."

IMMICH_GO_BIN="$HOME/.local/bin/immich-go"

if [ ! -f "$IMMICH_GO_BIN" ]; then
    echo "Downloading the official immich-go CLI..."
    mkdir -p "$HOME/.local/bin"
    curl -sL https://github.com/simulot/immich-go/releases/latest/download/immich-go_Linux_x86_64.tar.gz | tar xz -C "$HOME/.local/bin" immich-go
    chmod +x "$IMMICH_GO_BIN"
fi

echo "Starting import via native immich-go..."
"$IMMICH_GO_BIN" upload --on-errors continue --server http://localhost:2283 --api-key "$API_KEY" from-google-photos "$TAKEOUT_DIR"/*.zip

echo "✅ Import complete!"
