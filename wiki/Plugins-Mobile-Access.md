# Mobile Access

OctoApp provides mobile access to your printer from iOS or Android. It communicates directly with Moonraker on your local network.

---

## Prerequisites

- Docker installed on the system where you want to run the plugin (can be the printer or a separate machine)

---

## Setup

1. Create a directory for OctoApp:
   ```bash
   mkdir -p ~/companion/OctoApp
   cd ~/companion/OctoApp
   ```

2. Download the ready-to-use compose file from this repo: [wiki/assets/docker-compose-octoapp.yml](assets/docker-compose-octoapp.yml)

   Or create `docker-compose.yml` manually with this content:

   ```yaml
   services:
     octoapp-plugin:
       image: ghcr.io/crysxd/octoapp-plugin:latest
       environment:
           # Required - The IP address of the Klipper/Moonraker/Webserver/Printer
           - PRINTER_IP=XXX.XXX.XXX.XXX

           # Optional Settings
           - TZ=America/New_York

       volumes:
         - ./data:/data
   ```

3. Replace `XXX.XXX.XXX.XXX` with your printer's actual IP address. The line is uncommented in the assets file — make sure the `#` comment character is removed from the `PRINTER_IP` line, or the plugin will not connect.

4. Start the container:
   ```bash
   sudo docker compose up -d
   ```

5. Restart your printer so the plugin installs and shows up correctly in OctoApp.

---

## Troubleshooting

- **Plugin won't connect** → Double-check the `PRINTER_IP` value and confirm there is no `#` at the start of that line
- **Timezone errors** → Update the `TZ=` value to your region (e.g. `TZ=America/Chicago`)

---

## Alternative: Mobilraker

Mobilraker is an open-source alternative to OctoApp, also available for iOS and Android.

[Mobilraker on GitHub](https://github.com/Clon1998/mobileraker)
