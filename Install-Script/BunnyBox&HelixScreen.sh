#!/bin/sh

# Exit immediately if any command fails. This prevents the script from
# continuing and overwriting config files if a download or install step errors.
set -e

echo "Backing up current configs..."
# Create backup folder if missing. -p avoids errors if it already exists.
mkdir -p /home/mks/mudstockbackups

# rsync -a preserves structure, permissions, timestamps, and handles nested folders.
rsync -a /home/mks/printer_data/config/ /home/mks/mudstockbackups/
echo "Backup complete."
echo ""

echo "Installing Bunny Box..."
# wget -qO - downloads quietly and pipes directly into bash.
wget -qO - https://raw.githubusercontent.com/Camden-Winder/Bunny-Box/refs/heads/main/Q2/install-bb-q2.sh | bash
echo "Bunny Box installed."
echo ""

echo "Installing HelixScreen..."
# curl -sSL:
#   -s  silent (no progress meter)
#   -S  show errors even when silent
#   -L  follow redirects (required for GitHub raw URLs)
curl -sSL https://raw.githubusercontent.com/prestonbrown/helixscreen/main/scripts/install.sh | sh
echo "HelixScreen installed."
echo ""

echo "Updating gcode_macro.cfg..."
# Pulls your combined BunnyBox + HelixScreen macro file.
# -sSL ensures silent mode, error visibility, and redirect handling.
curl -sSL https://raw.githubusercontent.com/Camden-Winder/Qidi-Q2-superuser/refs/heads/main/Install-Script/gcode_macro-BunnyBox%26HelixScreen.cfg \
  -o /home/mks/printer_data/config/gcode_macro.cfg
echo "gcode_macro.cfg updated."
echo ""

echo "Updating printer.cfg..."
# Replaces the printer.cfg with your unified BunnyBox + HelixScreen version.
# This ensures all required includes, macros, and settings are aligned.
curl -sSL https://raw.githubusercontent.com/Camden-Winder/Qidi-Q2-superuser/refs/heads/main/Install-Script/printer-BunnyBox%26HelixScreen.cfg \
  -o /home/mks/printer_data/config/printer.cfg
echo "printer.cfg updated."
echo ""

echo "Applying KAMP settings..."
# Creates the KAMP subdirectory if it doesn't exist, matching the path that
# printer.cfg expects: ./KAMP/KAMP_Settings.cfg
mkdir -p /home/mks/printer_data/config/KAMP
# Installs your tuned KAMP configuration.
# Filename uses capital S (KAMP_Settings.cfg) to match the [include] directive
# in printer.cfg. Linux is case-sensitive — wrong case = file not found at boot.
curl -sSL https://raw.githubusercontent.com/Camden-Winder/Qidi-Q2-superuser/refs/heads/main/Install-Script/KAMP_settings.cfg \
  -o /home/mks/printer_data/config/KAMP/KAMP_Settings.cfg
echo "KAMP settings applied."
echo ""

echo "Installing HelixScreen preset..."
# Presets are full settings templates placed in assets/config/presets/.
# The filename (minus .json) is the preset name shown in the HelixScreen UI.
# This preset sets the correct Q2 home screen layout, fan mappings, LED config,
# and macros for a BunnyBox + HelixScreen install.
# The directory is created here explicitly because the install script runs before
# HelixScreen's first launch, which is when it would normally create the folder.
mkdir -p /home/mks/helixscreen/assets/config/presets
curl -sSL https://raw.githubusercontent.com/Camden-Winder/Qidi-Q2-superuser/refs/heads/main/Install-Script/Qidi-Q2-BunnyBox.json \
  -o /home/mks/helixscreen/assets/config/presets/Qidi-Q2-BunnyBox.json
echo "HelixScreen preset installed."
echo ""

echo "Install complete."
