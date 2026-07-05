#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QUADLET_DIR="$HOME/.config/containers/systemd"

echo "=== Immich Interactive Setup ==="
echo ""

# Check for required groups
if ! groups | grep -q '\bvideo\b' || ! groups | grep -q '\brender\b'; then
    echo "⚠️  WARNING: Your user is missing 'video' or 'render' group memberships."
    echo "ROCm hardware acceleration may fail. Consider adding yourself to these groups:"
    echo "  sudo usermod -aG video,render \$USER"
    echo "Press Enter to continue anyway, or Ctrl+C to abort..."
    read -r
fi

# Ask for Timezone
read -rp "Enter your Timezone [Default: America/Halifax]: " INPUT_TZ
TZ=${INPUT_TZ:-America/Halifax}

# Ask for Network Drive
read -rp "Enter the absolute path to your Network Drive for photos [Default: $HOME/nfs_photos]: " INPUT_UPLOAD
UPLOAD_LOCATION=${INPUT_UPLOAD:-$HOME/nfs_photos}

# Ask for a Tailscale auth key (only needed the first time; the sidecar
# persists its identity in a volume afterwards)
TS_AUTHKEY=""
if ! podman secret exists tailscale_authkey 2>/dev/null; then
    echo ""
    echo "The Tailscale sidecar exposes Immich as its own tailnet node (e.g. https://immich.<tailnet>.ts.net)."
    echo "Create an auth key in the Tailscale admin console (Settings -> Keys)."
    read -rp "Enter a Tailscale auth key [leave blank to skip the sidecar]: " TS_AUTHKEY
fi

echo ""
echo "Generating configurations..."

# Create generated quadlets dir
rm -rf "$DIR/quadlets"
mkdir -p "$DIR/quadlets"
cp "$DIR"/templates/* "$DIR/quadlets/"

# Update Timezone in generated quadlets safely
sed -i "s|Environment=TZ=.*|Environment=TZ=${TZ}|g" "$DIR"/quadlets/*.container

# Update Volume mount in immich-server safely
sed -i "s|Volume=.*:/data|Volume=${UPLOAD_LOCATION}:/data|g" "$DIR/quadlets/immich-server.container"

# Point the Tailscale sidecar at the generated serve config
sed -i "s|Volume=.*:/config/serve.json:ro|Volume=${DIR}/quadlets/tailscale-immich-serve.json:/config/serve.json:ro|g" "$DIR/quadlets/tailscale-immich.container"

# Disable the Tailscale sidecar entirely if no auth key was provided (and none exists)
TAILSCALE_ENABLED=true
if [ -z "$TS_AUTHKEY" ] && ! podman secret exists tailscale_authkey 2>/dev/null; then
    TAILSCALE_ENABLED=false
    rm -f "$DIR"/quadlets/tailscale-immich.container "$DIR"/quadlets/tailscale-immich-state.volume "$DIR"/quadlets/tailscale-immich-serve.json
    rm -f "$QUADLET_DIR/tailscale-immich.container" "$QUADLET_DIR/tailscale-immich-state.volume"
fi

echo "Ensuring the network drive directory exists..."
if [ ! -d "$UPLOAD_LOCATION" ]; then
    echo "Directory $UPLOAD_LOCATION does not exist. Creating it now..."
    mkdir -p "$UPLOAD_LOCATION"
fi

echo "Ensuring Podman uses the modern Netavark network backend (required for DNS)..."
mkdir -p "$HOME/.config/containers"
if ! grep -q "network_backend *= *\"netavark\"" "$HOME/.config/containers/containers.conf" 2>/dev/null; then
    echo -e "[network]\nnetwork_backend=\"netavark\"" >>"$HOME/.config/containers/containers.conf"
    echo "Cleaning up legacy CNI networks to force a Netavark rebuild..."
    systemctl --user stop immich-server immich-machine-learning immich-postgres immich-redis immich-network.service 2>/dev/null || true
    podman rm -f immich-server immich-machine-learning immich-postgres immich-redis 2>/dev/null || true
    podman network rm immich 2>/dev/null || true
fi

echo "Setting up Podman secrets..."
if ! podman secret exists immich_db_password; then
    echo "Generating secure database password and storing it in Podman secrets..."
    openssl rand -hex 16 | tr -d '\n' | podman secret create immich_db_password - >/dev/null
else
    echo "Podman secret 'immich_db_password' already exists."
fi

if [ -n "$TS_AUTHKEY" ]; then
    echo "Storing the Tailscale auth key in Podman secrets..."
    printf '%s' "$TS_AUTHKEY" | podman secret create tailscale_authkey - >/dev/null
elif [ "$TAILSCALE_ENABLED" = true ]; then
    echo "Podman secret 'tailscale_authkey' already exists."
fi

echo "Ensuring Quadlet directory exists at $QUADLET_DIR..."
mkdir -p "$QUADLET_DIR"

echo "Symlinking Quadlet files..."
ln -sf "$DIR"/quadlets/*.network "$QUADLET_DIR/"
ln -sf "$DIR"/quadlets/*.volume "$QUADLET_DIR/"
ln -sf "$DIR"/quadlets/*.container "$QUADLET_DIR/"

echo "Reloading systemd daemon..."
systemctl --user daemon-reload

echo "Pre-pulling container images (this might take a few minutes)..."
grep -h "^Image=" "$DIR"/quadlets/*.container | cut -d'=' -f2 | xargs -n1 podman pull

echo "Starting Immich services..."
systemctl --user start immich-server.service
systemctl --user start immich-machine-learning.service
if [ "$TAILSCALE_ENABLED" = true ]; then
    systemctl --user restart tailscale-immich.service
fi

echo ""
echo "✅ Done! Immich should be starting up."
echo ""
echo "You can monitor the startup process by running:"
echo "  journalctl --user -fu immich-server.service"
echo ""
if [ "$TAILSCALE_ENABLED" = true ]; then
    echo "The Tailscale sidecar is exposing Immich as its own tailnet node."
    echo "Find its URL (e.g. https://immich.<tailnet>.ts.net) with:"
    echo "  podman exec tailscale-immich tailscale status"
    echo ""
    echo "⚠️  If you previously exposed Immich via host-level 'tailscale serve', remove it with:"
    echo "  tailscale serve --https=443 off"
else
    echo "⚠️  Tailscale sidecar skipped (no auth key). Expose Immich manually with:"
    echo "  tailscale serve --bg --https=443 http://127.0.0.1:2283"
fi
