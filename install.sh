#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QUADLET_DIR="$HOME/.config/containers/systemd"

echo "=== Immich Interactive Setup ==="
echo ""

# Ask for Timezone
read -p "Enter your Timezone [Default: America/Halifax]: " INPUT_TZ
TZ=${INPUT_TZ:-America/Halifax}

# Ask for Network Drive
read -p "Enter the absolute path to your Network Drive for photos [Default: $HOME/nfs_photos]: " INPUT_UPLOAD
UPLOAD_LOCATION=${INPUT_UPLOAD:-$HOME/nfs_photos}

echo ""
echo "Applying configurations..."

# Update Timezone in all quadlets safely
sed -i "s|Environment=TZ=.*|Environment=TZ=${TZ}|g" "$DIR"/quadlets/*.container

# Update Volume mount in immich-server safely
sed -i "s|Volume=.*:/data|Volume=${UPLOAD_LOCATION}:/data|g" "$DIR/quadlets/immich-server.container"

echo "Ensuring the network drive directory exists..."
if [ ! -d "$UPLOAD_LOCATION" ]; then
    echo "Directory $UPLOAD_LOCATION does not exist. Creating it now..."
    mkdir -p "$UPLOAD_LOCATION"
fi

echo "Setting up Podman secrets..."
if ! podman secret exists immich_db_password; then
    echo "Generating secure database password and storing it in Podman secrets..."
    openssl rand -hex 16 | podman secret create immich_db_password -
else
    echo "Podman secret 'immich_db_password' already exists."
fi

echo "Ensuring Quadlet directory exists at $QUADLET_DIR..."
mkdir -p "$QUADLET_DIR"

echo "Symlinking Quadlet files..."
ln -sf "$DIR"/quadlets/*.network "$QUADLET_DIR/"
ln -sf "$DIR"/quadlets/*.volume "$QUADLET_DIR/"
ln -sf "$DIR"/quadlets/*.container "$QUADLET_DIR/"

echo "Reloading systemd daemon..."
systemctl --user daemon-reload

echo "Starting and enabling Immich services..."
systemctl --user enable --now immich-server.service
systemctl --user enable --now immich-machine-learning.service

echo ""
echo "✅ Done! Immich should be starting up."
echo "Your configuration has been saved directly into the quadlets/ directory."
echo "Feel free to commit them to git as your final IaC!"
echo ""
echo "You can monitor the startup process by running:"
echo "  journalctl --user -fu immich-server.service"
echo ""
echo "⚠️  REMEMBER: Expose Immich to your Tailscale network by running:"
echo "  tailscale serve --bg 2283 http://127.0.0.1:2283"
