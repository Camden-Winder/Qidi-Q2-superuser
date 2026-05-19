# Mobile Access with OctoApp

**What this does**
This sets up the OctoApp plugin using Docker so you can access your Qidi Q2 from your phone.

**Prerequisites:** Docker must be installed on the device running this stack. If you haven't installed it yet, follow the [official Docker install guide](https://docs.docker.com/engine/install/).

---

## Setup steps

1. **Open the `Companion` directory** on your printer. This is the directory used by the Companion stack — typically `/home/mks/companion` or wherever your docker-compose services live.
2. **Create a new folder** named `OctoApp` inside it.
3. **Inside that folder**, create a file named `docker-compose.yml`.
4. **Edit the file** in any text editor. Replace `PRINTER_IP=XXX.XXX.XXX.XXX` with your actual printer's IP address.

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
      # You can also use an absolute path, e.g.:
      # /var/octoapp/plugin/data or /c/users/name/plugin/data
      - ./data:/data
```

5. **Start the container**
   ```bash
   sudo docker compose up -d
   ```

6. **Restart your printer** so the plugin installs and shows up correctly in OctoApp.

---

## Troubleshooting

- **Wrong IP** → The plugin won't connect. Double-check your printer's IP in Moonraker. You can find it under System → Network in the Moonraker web UI.
- **Wrong folder path** → Make sure the `docker-compose.yml` is inside the `Companion/OctoApp/` directory, not in the root Companion folder.
- **Timezone errors** → Update the `TZ=` value to your actual region (e.g. `America/Chicago`, `Europe/London`). A full list of valid timezone strings is at [this IANA list](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones).
- **Container exits immediately** → Run `sudo docker compose logs` from the OctoApp directory to see the error output.
- **OctoApp can't find the printer on the phone** → Make sure your phone and printer are on the same local network, or that you have remote access configured.

---

## Notes

- This setup uses Docker just like the rest of the Companion stack.
- Once running, OctoApp on your phone should automatically detect the plugin.

---
