Time to install Spoolman and it is yet another docker
1. In the `companion` folder, create a subfolder called `Spoolman`
2. Enter the folder and create a `docker-compose.yml
```
version: '3.8'
services:
  spoolman:
    image: ghcr.io/donkie/spoolman:latest # Also available at dockerhub: donkieyo/spoolman:latest
    restart: unless-stopped
    volumes:
      # Mount the host machine's ./data directory into the container's /home/app/.local/share/spoolman directory
      - type: bind
        source: ./data # This is where the data will be stored locally. Could also be set to for example `source: /home/pi/printer_data/spoolman`.
        target: /home/app/.local/share/spoolman # Do NOT modify this line
    ports:
      # Map the host machine's port 7912 to the container's port 8000
      - "7912:8000"
    environment:
      - TZ=Europe/Stockholm # Optional, defaults to UT```
