# Immich Self-Hosted Setup (Podman Quadlets + Tailscale)

This repository contains an "Infrastructure as Code" (IaC) setup for hosting [Immich](https://immich.app/) using rootless Podman Quadlets, securely exposed via Tailscale.

## Prerequisites
1. **Podman** (v4.4 or newer, though v4.9+ is recommended).
2. **Tailscale** installed and logged in on this machine.
3. Your user must be in the `video` and `render` groups to use the AMD ROCm hardware acceleration for machine learning.

---

## 🚀 1. Installation & Startup

1. **Run the Interactive Installer:**
   ```bash
   ./install.sh
   ```
   *This script does not need root/sudo. It will prompt you for your Timezone and Network Drive location, create the necessary data directories, generate a secure database password into Podman Secrets, compile the Quadlets, and start the services.*

2. **Expose securely via Tailscale:**
   By default, Immich is only listening on `127.0.0.1`. To expose it to your Tailnet securely (and get a free HTTPS certificate), run:
   ```bash
   tailscale serve --bg 2283 http://127.0.0.1:2283
   ```

You can now open your web browser to your machine's Tailscale IP or MagicDNS hostname (e.g., `https://my-server.my-tailnet.ts.net:2283`) and create your admin account.

---

## 📦 2. Importing Google Takeout (immich-go)

If you are migrating from Google Photos, we use `immich-go` to perfectly preserve your albums and metadata.

### Preparation:
1. Request a **Google Takeout** of your Google Photos. **Recommendation:** Choose `.zip` file format and set the size to **50GB** (not 2GB!) so that albums and metadata are kept together.
2. If you have multiple family members migrating, download each person's Takeout zips into strictly separate folders (e.g., `/mnt/data/takeout/alice/` and `/mnt/data/takeout/bob/`). **Do not extract the zip files.**
3. Create a user account for each person in the Immich web interface.
4. Log in as each user, go to **Account Settings -> API Keys**, and generate a unique API Key for that person.

### Running the Import (Multi-User):
Run the included wrapper script for each user separately. It will automatically download the `immich-go` container, mount their specific Takeout folder, and upload everything to their account.

```bash
# Import Person A's library into Person A's account
./import-takeout.sh "PERSON_A_API_KEY" "/mnt/data/takeout/alice"

# Import Person B's library into Person B's account
./import-takeout.sh "PERSON_B_API_KEY" "/mnt/data/takeout/bob"
```

*Note: Immich intelligently handles duplicate shared photos! If Person B uploads a photo identical to one Person A already uploaded, Immich stores only one physical copy on your hard drive to save space, but makes it visible in both timelines. After the import, you can set up "Partner Sharing" natively inside Immich.*

---

## 💾 3. Backups
To back up your entire Immich instance, you must save two things:
1. **The Database:** Dump your Postgres database using the running container:
   ```bash
   podman exec -t immich-postgres pg_dumpall -c -U postgres > immich_db_backup.sql
   ```
2. **The Media Library:** Copy or back up the entire network drive folder that you specified during installation.

If you ever need to restore, you recreate the containers and run `cat immich_db_backup.sql | podman exec -i immich-postgres psql -U postgres`.

---

## 🔧 Maintenance & Updates

### Updating Immich
To update to a newer version of Immich, edit the `Image=` lines in the templates inside the `templates/` directory to point to the new version tag (e.g., `v1.107.0`). Then re-run `./install.sh`.

### Viewing Logs
To see what Immich is doing under the hood, you can check the systemd logs:
```bash
journalctl --user -fu immich-server.service
```
