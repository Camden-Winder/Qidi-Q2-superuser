#!/bin/bash

# Exit immediately on any error so a failed download doesn't silently
# overwrite config files with nothing or an HTML error page.
set -e
set -o pipefail

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
# Fixed: old URL used Install%20Script/ (space) and wrong filename — folder is now Install-Script/
# and file is gcode_macro(JustFasterPrinter).cfg
echo "Updating gcode_macro.cfg ..."
curl -sSLf https://raw.githubusercontent.com/Camden-Winder/Qidi-Q2-superuser/refs/heads/main/Install-Script/gcode_macro-JustFasterPrinter.cfg \
  -o /home/mks/printer_data/config/gcode_macro.cfg

# Update printer.cfg for the Just Faster setup
# Fixed: old URL used Install%20Script/ and "Just Faster printer.cfg" — file is now JustFasterPrinter.cfg
echo "Updating printer.cfg ..."
curl -sSLf https://raw.githubusercontent.com/Camden-Winder/Qidi-Q2-superuser/refs/heads/main/Install-Script/JustFasterPrinter.cfg \
  -o /home/mks/printer_data/config/printer.cfg

# Apply KAMP settings
# Fixed: old URL used Install%20Script/ — folder is now Install-Script/
# Fixed: KAMP_Settings.cfg must go in a KAMP/ subdirectory to match the
# [include ./KAMP/KAMP_Settings.cfg] directive in JustFasterPrinter.cfg
echo "Applying KAMP settings ..."
mkdir -p /home/mks/printer_data/config/KAMP
curl -sSLf https://raw.githubusercontent.com/Camden-Winder/Qidi-Q2-superuser/refs/heads/main/Install-Script/KAMP_settings.cfg \
  -o /home/mks/printer_data/config/KAMP/KAMP_Settings.cfg

echo ""
echo "Congrats — your Q2 is now running the 'Just Faster' setup."
echo "No Bunny Box, no HelixScreen — just cleaner macros and faster starts."
echo ""
