# Spoolman

Spoolman is a filament inventory tracker that integrates with Klipper and Moonraker. It tracks spool weights, usage, and material info, and can display spool data in HelixScreen's lane widget when BunnyBox is installed.

---

## Prerequisites

- Docker installed on the system where you want to run Spoolman (can be the printer or a separate machine)

---

## Setup

1. Create a directory for Spoolman on your server or printer:
   ```bash
   mkdir -p ~/companion/Spoolman
   cd ~/companion/Spoolman
   ```

2. Download the ready-to-use compose file from this repo: [wiki/assets/docker-compose-spoolman.yml](assets/docker-compose-spoolman.yml)

   Or create `docker-compose.yml` manually with this content:

   ```yaml
   services:
     spoolman:
       image: ghcr.io/donkie/spoolman:latest
       restart: unless-stopped
       volumes:
         - type: bind
           source: ./data
           target: /home/app/.local/share/spoolman
       ports:
         - "7912:8000"
       environment:
         - TZ=Europe/Stockholm
   ```

3. **Set your timezone.** Change `TZ=Europe/Stockholm` to your own timezone string. Find the correct string for your region at [List of tz database time zones](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones).

4. Start the container:
   ```bash
   sudo docker compose up -d
   ```

5. Open Spoolman in your browser at `http://<host-ip>:7912` and bookmark it — you'll use it often.

---

## Notes

- Change the host port if 7912 is already in use: update `"7912:8000"` to any other host port, e.g. `"9000:8000"`
- To move the data directory, replace `source: ./data` with an absolute path
- Spoolman integrates with Moonraker's filament tracking via the Moonraker Spoolman integration — see the [Moonraker docs](https://moonraker.readthedocs.io/en/latest/configuration/#spoolman) after setup

[Spoolman GitHub](https://github.com/Donkie/Spoolman)
