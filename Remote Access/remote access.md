# Remote Access
I like checking on my printer and hate giving my information to china, that is why I chose octoeverywhere

Alternatives: Obico
## Installation
The link to full guide is [here](https://blog.octoeverywhere.com/klipper-companion-docker-docker-compose-setup-guide/?source=getstarted_klipper_docker). If you are using windows, use this [guide](https://blog.octoeverywhere.com/octoeverywhere-plugin-manager-for-windows/?source=blog-klipper-companion-docker-compose-button). I will be running this on a spare laptop I have running Lubuntu so make sure to read if you're doing something different
1. Make a folder to put all of the docker .yml in. Spoolman, Octoeverywhere, and Octoapp all need one so it is best to be organized. In my case I will just call it `Companion`
Edit this text with your own IP address
`- PRINTER_IP=XXX.XXX.XXX.XXX` with your IP adress. So if my IP address was 123.234.345.163 then I would have ` - Printer_IP=123.234.345.163`
Now, put that IP address into this text
```
version: '2'
services:
  octoeverywhere-klipper-companion:
    image: octoeverywhere/octoeverywhere:latest
    environment:
        # Required to set the Docker container in Klipper Companion mode.
      - COMPANION_MODE=klipper
      - PRINTER_IP=XXX.XXX.XXX.XXX

    volumes:
      # This can also be an absolute path as well.
      - ./data:/data
```
I create a folder called OctoEverywhere to stay organized and then cd into the folder
Create a file called `docker-compose.yml` in your folder.
Open `docker-compose.yml` in a text editor and paste the text you just put your IP adress into
Now, go back into your terminal and run the command 'sudo docker compose up -d'
There should be a link in the text after you run the command, click on the link to finish setting up OctoEverywhere.
