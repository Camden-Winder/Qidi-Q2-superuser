#!/bin/sh

# Prevent running as root — this breaks permissions on the Q2
if [ "$(id -u)" -eq 0 ]; then
  echo "Do not run this script as root. Run it as the printer user (usually 'mks')."
  exit 1
fi

# Back up current configs
echo "Backing up current configs to /home/mks/mudstockbackups ..."
mkdir -p /home/mks/mudstockbackups
rsync -a /home/mks/printer_data/config/ /home/mks/mudstockbackups/
echo "Backup complete."
echo ""

# Update gcode_macro.cfg (no box, no HelixScreen version)
echo "Updating gcode_macro.cfg ..."
curl -sSL https://raw.githubusercontent.com/Camden-Winder/Qidi-Q2-superuser/refs/heads/main/Install%20Script/gcode_macro%28no.box.no.hs%29.cfg \
  -o /home/mks/printer_data/config/gcode_macro.cfg

# Update printer.cfg for the Just Faster setup
echo "Updating printer.cfg ..."
curl -sSL https://raw.githubusercontent.com/Camden-Winder/Qidi-Q2-superuser/refs/heads/main/Install%20Script/Just%20Faster%20printer.cfg \
  -o /home/mks/printer_data/config/printer.cfg

# Apply KAMP settings
echo "Applying KAMP settings ..."
curl -sSL https://raw.githubusercontent.com/Camden-Winder/Qidi-Q2-superuser/refs/heads/main/Install%20Script/KAMP_settings.cfg \
  -o /home/mks/printer_data/config/KAMP_Settings.cfg

echo ""
echo "Congrats — your Q2 is now running the 'Just Faster' setup."
echo "No Bunny Box, no HelixScreen — just cleaner macros and faster starts."
echo ""
