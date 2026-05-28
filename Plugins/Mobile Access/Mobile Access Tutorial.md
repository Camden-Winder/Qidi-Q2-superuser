# Mobile Access with OctoApp

**What this does**  
This sets up the OctoApp plugin using Docker so you can access your Qidi Q2 from your phone.

---

## Setup steps

1. **Open the `Companion` directory** on your printer or server.
2. **Create a new folder** named `OctoApp`.
3. **Inside that folder**, create a file named `docker-compose.yml`.
4. **Edit the file** in any text editor and replace `PRINTER_IP=XXX.XXX.XXX.XXX` with your actual printer’s IP address.

```yaml
services:
  octoapp-plugin:
    image: ghcr.io/crysxd/octoapp-plugin:latest
    environment:
        # Required - The IP address of the Klipper/Moonraker/Webserver/Printer
        #- PRINTER_IP=XXX.XXX.XXX.XXX
       
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

- **Wrong IP** → The plugin won’t connect. Double‑check your printer’s IP in Moonraker.  
- **Wrong folder path** → Make sure the `docker-compose.yml` is inside `Companion/OctoApp/`.  
- **Timezone errors** → Update the `TZ=` value to your actual region.

---

## Notes

- This setup uses Docker just like the rest of the Companion stack.  
- Once running, OctoApp on your phone should automatically detect the plugin.

---
