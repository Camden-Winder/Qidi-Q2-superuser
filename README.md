# What this guide includes
In here I will list everything I am running on/for my printer and alternatives I have heard of. This includes octoapp, octoeverywhere, and spoolman, which are all running remotely so I don't waste printer ram space.
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
# Mobile Access
We will now be setting up OctoApp

Alternatives: Mobilraker

Setting up OctoApp is similar to everything else, it is done with Docker. Go into the `Companion` app.
Make a folder called `OctoApp`
In this folder, create another `docker-compose.yml`
Again, open in a text editor and replace `PRINTER_IP=XXX.XXX.XXX.XXX` with your real IP adress
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
Run it with 'sudo docker compose up -d'
Restart the printer and the plugin will be installed correctly
# Filament tracking
I use Spoolman for this
1. In the `companion folder` create a new folder called `Spoolman`
2. Enter
3. Finishing later
# Printer Configs
Out of the box the printer ships with a really bloated print preparation macro that takes a lot of time. Here is all the documentation I found

[khoroshev-e-i Fast Macros](https://github.com/khoroshev-e-i/Qidi-q2-settings/tree/main)

[Heiko910 Integrating KAMP](https://github.com/Heiko910/Qidi-Q2-with-KAMP-fully-integrated/tree/main)

[ckflyer Quick Start Guide](https://github.com/ckflyer/Qidi-Q2-Printer-Quick-Start-Guide)

[Reddit Conversiation on bloated preparation setup](https://www.reddit.com/r/QidiTech3D/comments/1psz4k1/q2_gcode_is_overly_complex/)

It is always wise to back up any configs before we edit them. As of writing these work with Q2 firmware 1.1.0 and have not been tested with the box. In fact, I believe this version is missing the box commands.
## Adding Adaptive Bed Leveling (KAMP)
This will make it so it still levels the bed, but only in the part you will be printing. This is especially helpful when doing small prints. I recomend follwing along with [Heiko910 Integrating KAMP](https://github.com/Heiko910/Qidi-Q2-with-KAMP-fully-integrated/tree/main) because he has pictures. I will go into detail to help explain it some more though as well.
Access the printer interface from your web browser. Just type your IP address into the search bar.
1. Click on configurations in the left tab bar
2. Make a folder called `store for delete` to store config files you don't need anymore
3. Store `KAMP_settings.cfg` and `Adpative_meshing.cfg` in this folder
4. Enter the `KAMP` folder and open `KAMP_settings.cfg`
5. Delete all text and replace with this (lots of the comments are removed because I don't know how to do this another way)
```  [include ./Adaptive_Meshing.cfg]
  [include ./Line_Purge.cfg]      
  [include ./Voron_Purge.cfg]    
  [include ./Smart_Park.cfg]   
  [gcode_macro _KAMP_Settings]
  description: This macro contains all adjustable settings for KAMP 
  variable_verbose_enable: True       
  variable_mesh_margin: 0    
  variable_fuzz_amount: 0    
  variable_purge_height: 0.8 
  variable_tip_distance: 0   
  variable_purge_margin: 10   
  variable_purge_amount: 30   
  variable_flow_rate: 12   
  variable_smart_park_height: 10  
  gcode:

    {action_respond_info(" Running the KAMP_Settings macro does nothing, it is only used for storing KAMP settings. ")}
```
6. Press save in the top right corner
## Now we change more settings to make sure our changes do stuff
7. Go to printer.cfg file
8. Remove whatever is in the 3rd line and replace it with this `[include ./KAMP/KAMP_Settings.cfg]`
9. Save again
10. Go to gcode_macro.cfg
11. Go to the CLEAR_NOZZLE macro (line 57)
12. From "gcode" to wherever the next macro begins (SHAKE_OOZE) replace it with this
```gcode:
    {% set hotendtemp = params.HOTEND|default(250)|int %}
    MOVE_TO_TRASH
    M400
    M109 S{hotendtemp}
    TEMPERATURE_WAIT SENSOR=extruder MINIMUM={hotendtemp-20}
    G92 E0
    G1 E5 F80   # Old is G1 E5 F80
    G92 E0
    G1 E80 F300 #old is G1 E80 F300
    G92 E0
    G1 E-2 F200 # Old is G1 E-2 F200
    M400
    M106 S255
    # G4 P1000
    M104 S{hotendtemp-40}
    M118 "Hotendtemp-40"
    TEMPERATURE_WAIT SENSOR=extruder MAXIMUM={hotendtemp-30}
    M118 Temp Wait

    M204 S5000
        G1 X103 F5000
        G1 X90 F5000
        G1 X103 F5000
        G1 X90 F5000
        G1 X103 F5000
        G1 X90 F5000
        G1 X103 F5000
        G1 X90 F5000
        G1 X103 F5000
        G1 X90 F5000

        G1 X114 F5000
        G1 X100 F5000
        G1 X114 F5000
        G1 X100 F5000
        G1 X114 F5000
        G1 X100 F5000
        G1 X114 F5000
        G1 X100 F5000
        G1 X114 F5000
        G1 X100 F5000
        G1 X114 F5000
        G1 X100 F5000
        G1 X114 F5000
        G1 X100 F5000

        G1 X103 F5000
        G1 X90 F5000
        G1 X103 F5000
        G1 X90 F5000
        G1 X103 F5000
        G1 X90 F5000
        G1 X103 F5000
        G1 X90 F5000
        G1 X103 F5000
        G1 X90 F5000

    
    G1 X125 F15000
    M118 "M204 command"
    
    G1 X130 Y280 F6000
    G1 Z-0.2 F600
    M104 S150
    M118 Set Temp 150
    TEMPERATURE_WAIT SENSOR=extruder MAXIMUM=150
    M118 Temp Wait
    M106 S255
    G2 I0.5 J0.5 F600
    G2 I0.5 J0.5 F600
    G2 I0.5 J0.5 F600
    G1 X140 F200
    G1 Y281 F200
    G1 X130 F200
    G1 Y283 F200
    G1 X140 F200

    G2 I0.5 J0.5 F600
    G2 I0.5 J0.5 F600
    G2 I0.5 J0.5 F600

    G1 Z0.2
    G1 X180 F12000
    G1 Z-1.5
    G1 X164 F12000
    G1 X180 F12000
    G1 X164 F12000
    G1 X180 F12000
    G1 X164 F12000
    G1 X180 F12000
    G1 X164 F12000
    M400
    M118 Nozzle cleared
    G1 Z30 F900
    G1 Y10 F18000
    G1 X260 F18000
    M106 S0
```
13. Make your way to the "PRINT_START" macro (line 218)
14. From "gcode" to the next macro "ENABLE_ALL_SENSORS" replace it with this (DOES NOT WORK WITH BOX)
```
  gcode:
    {% set bedtemp = params.get('BED') | int %}
    {% set hotendtemp = params.get('HOTEND') | int %}
    {% set chambertemp = params.get('CHAMBER', 0) | int %}
    {% set extruder = params.EXTRUDER|default(0)|int %}
    {% set Polar_cooler = printer.save_variables.variables.enable_polar_cooler|default(0) %}
    
    # Temperature validation
    {% if bedtemp < 0 or bedtemp > 150 %}
        {action_respond_error("ERROR: Invalid bed temperature: " ~ bedtemp)}
    {% endif %}
    {% if hotendtemp < 0 or hotendtemp > 350 %}
        {action_respond_error("ERROR: Invalid hotend temperature: " ~ hotendtemp)}
    {% endif %}
    {% if chambertemp < 0 or chambertemp > 100 %}
        {action_respond_error("ERROR: Invalid chamber temperature: " ~ chambertemp)}
    {% endif %} 
    
    M140 S{bedtemp}      # Start bed heating (non-blocking) - IMMEDIATELY!
    M141 S{chambertemp}  # Start chamber heating (non-blocking) - IMMEDIATELY!
    #M104 S{hotendtemp}   ## Why do we wait to start the hotend?
	SAVE_VARIABLE VARIABLE=qdc_ai_error_code VALUE='""' ## Disables AI detection, at least to my knowledge
    AUTOTUNE_SHAPERS
    DISABLE_ALL_SENSOR
    CLEAR_PAUSE
	
	# PREPARATION: HOTEND OFF AND FANS
	M104 S140  # Turn off hotend for safety ##Set hotend to 140, why are we turning it off?
	M118 Set Hotend to 140
    # Chamber fan control
    {% if chambertemp == 0 %}
        M106 P3 S255  # Turn on chamber fan if chamber is not used
    {% else %}
        M106 P3 S0    # Turn off fan if chamber is used
    {% endif %}

    # Homing, Nozzle clean, and home again
    G28  # Home all axes
    M118 Homing
    SET_GCODE_OFFSET Z=0 MOVE=0  # Reset Z offset
    CLEAR_NOZZLE HOTEND={hotendtemp}
    M118 Clear Nozzle is done
    CUT_FILAMENT_1
    M118 Cut filament is done
    
    # Pre-heat hotend to 140°C for cutting
    # (140°C is sufficient for most materials for safe cutting)
    M104 S140
    M118 Set Temp to 140
    G4 P15000  # Optimized: ##7.5 (instead of 15) seconds instead of 30 (material already partially heated)
    M118 "Waiting"
    M400       # Wait for all commands to complete
    G28  # Home after cutting (important for positioning accuracy)
    Z_TILT_ADJUST  # Bed tilt calibration

    # Wait
    # Parallel waiting for bed and chamber (saves time)
    M190 S{bedtemp}      # Wait for bed temperature (blocking)
    M191 S{chambertemp}  # Wait for chamber temperature (blocking)
    M400                 # Ensure all commands are executed
    
    # Short pause for temperature stabilization (optimized)
    G4 P5000  # 5 seconds instead of 60 - sufficient for stabilization
    M118 End Pause

    BED_MESH_CALIBRATE  ## This is leftover from other calibrations and uses smart calibration instead of the whole thing
    M118 Smart Calibrate ends
    Smart_Park          ## Move to where the print starts to minimize travel
    M118 Smart Park
    # Make sure its heated
    M109 S{hotendtemp}  # Heat and wait for hotend working temperature
    M118 Hotend heated

    set_zoffset
    M118 Set Z
    ENABLE_ALL_SENSOR
    M118 enable sensors
    save_last_file
    VORON_purge
    M118 Voron Purge

    # Ready notification
    {action_respond_info("PRINT_START: Printer ready for printing")}
```
# You're done
Congragulations, you've finished. If you can help format this better it would be greatly appreciated. Thanks. Let me know if you have anything you think should be added.
