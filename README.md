# Immich Self-Hosted Setup (Podman Quadlets + Tailscale)

An infrastructure-as-code setup for hosting [Immich](https://immich.app/) with rootless Podman Quadlets, exposed to your Tailnet through a Tailscale sidecar container.

## Prerequisites
1. Podman v4.4 or newer (v4.9+ recommended).
2. Tailscale installed and logged in on this machine.
3. Your user must be in the `video` and `render` groups to use AMD ROCm hardware acceleration for machine learning.

---

## 1. Installation & Startup

1. (Optional) Create a Tailscale auth key. Immich is exposed to your Tailnet by a Tailscale sidecar container that joins as its own node named `immich`. Create an auth key in the [Tailscale admin console](https://login.tailscale.com/admin/settings/keys) and have it ready for the installer. You only need this on first install; afterwards the sidecar's identity persists in a Podman volume.

2. Run the interactive installer:
   ```bash
   ./install.sh
   ```
   No root/sudo required. The script prompts for your timezone, network drive location, and Tailscale auth key, then creates the data directories, generates a database password into Podman Secrets, compiles the Quadlets, and starts the services, including the sidecar.

Open `https://immich.<your-tailnet>.ts.net` in your browser (the HTTPS certificate is provisioned automatically) and create your admin account. To confirm the exact URL, run:
```bash
podman exec tailscale-immich tailscale status
```

Because the sidecar gives Immich its own hostname on your Tailnet, separate from the host machine, you can host other apps on this machine the same way and each gets its own `https://<app>.<tailnet>.ts.net` URL. If you skip the auth key at install time, the sidecar is left out and you can fall back to host-level `tailscale serve --bg --https=443 http://127.0.0.1:2283`.

---

## 2. Importing Google Takeout (immich-go)

If you are migrating from Google Photos, use `immich-go` to preserve your albums and metadata.

### Preparation
1. Request a Google Takeout of your Google Photos. Choose `.zip` file format and set the size to 50GB rather than 2GB, so that albums and metadata stay together.
2. If several family members are migrating, download each person's Takeout zips into separate folders (e.g., `/mnt/data/takeout/alice/` and `/mnt/data/takeout/bob/`). Do not extract the zip files.
3. Create a user account for each person in the Immich web interface.
4. Log in as each user, go to Account Settings -> API Keys, and generate an API key for that person.

### Running the Import (Multi-User)
Run the included wrapper script once per user. It downloads the `immich-go` CLI if needed, then uploads that person's zips to their account.

```bash
# Import Person A's library into Person A's account
./import-takeout.sh "PERSON_A_API_KEY" "/mnt/data/takeout/alice"

# Import Person B's library into Person B's account
./import-takeout.sh "PERSON_B_API_KEY" "/mnt/data/takeout/bob"
```

If Person B uploads a photo identical to one Person A already uploaded, Immich stores a single physical copy on disk and shows it in both timelines. After the import, you can set up Partner Sharing inside Immich.

---

## 3. Backups

A full backup consists of two parts:

1. The database. Dump Postgres from the running container:
   ```bash
   podman exec -t immich-postgres pg_dumpall -c -U postgres > immich_db_backup.sql
   ```
2. The media library. Back up the network drive folder you specified during installation.

To restore, recreate the containers and run `cat immich_db_backup.sql | podman exec -i immich-postgres psql -U postgres`.

---

## Maintenance & Updates

### Updating Immich
Edit the `Image=` lines in the `templates/` directory to point at the new version tag, then re-run `./install.sh`.

### Viewing Logs
Immich activity is logged through systemd:
```bash
journalctl --user -fu immich-server.service
```
