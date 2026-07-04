# Immich Self-Hosted Setup (Podman Quadlets + Tailscale)

This repository contains an "Infrastructure as Code" (IaC) setup for hosting [Immich](https://immich.app/) using rootless Podman Quadlets, securely exposed via Tailscale.

## Prerequisites
1. **Podman** (v4.4 or newer, though v4.9+ is recommended).
2. **Tailscale** installed and logged in on this machine.
3. Your user must be in the `video` and `render` groups to use the AMD ROCm hardware acceleration for machine learning.

---

## 🚀 1. Installation & Startup

1. **Configure Environment variables:**
   ```bash
   cp .env.example .env
   ```
   **CRITICAL:** Open `.env` in a text editor and change `DB_PASSWORD` and `POSTGRES_PASSWORD` to a secure, random string!

2. **Run the Installer:**
   ```bash
   ./install.sh
   ```
   *This script does not need root/sudo. It will create the necessary data directories, symlink the Quadlet configurations to your systemd user folder, and start the services.*

3. **Expose securely via Tailscale:**
   By default, Immich is only listening on `127.0.0.1`. To expose it to your Tailnet securely (and get a free HTTPS certificate), run:
   ```bash
   tailscale serve --bg 2283 http://127.0.0.1:2283
   ```

You can now open your web browser to your machine's Tailscale IP or MagicDNS hostname (e.g., `https://my-server.my-tailnet.ts.net:2283`) and create your admin account.

---

## 📦 2. Importing Google Takeout (immich-go)

If you are migrating from Google Photos, we use `immich-go` to perfectly preserve your albums and metadata.

### Preparation:
1. Request a **Google Takeout** of your Google Photos. **Recommendation:** Set the zip size to 50GB so you have fewer files to download.
2. Download all the `.zip` files to a folder on this server (e.g., `/mnt/data/takeout`).
3. Log into your Immich web interface, go to **Account Settings -> API Keys**, and generate a new API Key.

### Running the Import:
Run the included wrapper script. It will automatically download the `immich-go` container, mount your Takeout folder, and upload everything.

```bash
./import-takeout.sh "YOUR_API_KEY_HERE" "/path/to/your/takeout_folder"
```

*Note: Depending on the size of your library, this could take a few hours. The machine learning container will automatically run in the background to recognize faces and objects as the photos arrive.*

---

## 🔧 Maintenance & Updates

### Updating Immich
To update to a newer version of Immich, simply edit the `Image=` lines in the `.container` files inside the `quadlets/` directory to point to the new version tag (e.g., `v3.1`). Then run:

```bash
systemctl --user daemon-reload
systemctl --user restart immich-server.service immich-machine-learning.service
```

### Viewing Logs
To see what Immich is doing under the hood, you can check the systemd logs:
```bash
journalctl --user -fu immich-server.service
```
