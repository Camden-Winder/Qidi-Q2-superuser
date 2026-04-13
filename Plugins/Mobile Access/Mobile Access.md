Setting up OctoApp is similar to everything else, it is done with Docker. Go into the `Companion` app.
1.Make a folder called `OctoApp`
2. In this folder, create another `docker-compose.yml`
3. Again, open in a text editor and replace `PRINTER_IP=XXX.XXX.XXX.XXX` with your real IP adress
```
version: '2'
services:
  octoapp-plugin:
    image: ghcr.io/crysxd/octoapp-plugin:latest
    environment:
        - COMPANION_MODE=klipper

        #  Required - The IP address of the Klipper/Moonraker/Webserver/Printer
        #- PRINTER_IP=XXX.XXX.XXX.XXX
       
        # Optional Settings For All Modes
        #
        # Set timezone to proper timezone for logs using standard timezones:
        # https://en.wikipedia.org/wiki/List_of_tz_database_time_zones#List
        - TZ=America/New_York

    volumes:
      # This can also be an absolute path, e.g. /var/octoapp/plugin/data or /c/users/name/plugin/data
      - ./data:/data
```
4. Run it with 'sudo docker compose up -d'
5. Restart the printer and the plugin will be installed correctly
