#!/bin/sh

# Exit immediately if any command fails. This prevents the script from
# continuing and overwriting config files if a download or install step errors.
set -e
# pipefail makes the script treat a failure anywhere in a pipe as fatal.
# Without this, `wget ... | bash` would succeed even if wget failed silently.
# Supported in dash (the Q2's /bin/sh) and bash.
set -o pipefail

echo "Backing up current configs..."
# Create backup folder if missing. -p avoids errors if it already exists.
mkdir -p /home/mks/mudstockbackups

# rsync -a preserves structure, permissions, timestamps, and handles nested folders.
rsync -a /home/mks/printer_data/config/ /home/mks/mudstockbackups/
echo "Backup complete."
echo ""

echo "Installing Bunny Box..."
echo ">>> NOTE: The BunnyBox installer is interactive. You will be prompted to:"
echo ">>>   - Confirm you want to install"
echo ">>>   - Confirm or enter your serial port for the Bunny Box"
echo ">>>   - Choose whether to install the AHT10 environment sensor module"
echo ">>> Watch the output and respond to each prompt to continue."
echo ""
# wget -qO - downloads quietly and pipes directly into bash.
# pipefail ensures wget failures are caught even when piped.
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
# BunnyBox modifies gcode_macro.cfg during its install. We overwrite it here
# with our combined BunnyBox + HelixScreen version, which is the intended final state.
# If BunnyBox's required macro structure ever changes, this file must be updated too.
# Verified live: github.com/Camden-Winder/Qidi-Q2-superuser Install-Script/gcode_macro-BunnyBox&HelixScreen.cfg
# Destination:   /home/mks/printer_data/config/gcode_macro.cfg
curl -sSL https://raw.githubusercontent.com/Camden-Winder/Qidi-Q2-superuser/refs/heads/main/Install-Script/gcode_macro-BunnyBox%26HelixScreen.cfg \
  -o /home/mks/printer_data/config/gcode_macro.cfg
echo "gcode_macro.cfg updated."
echo ""

echo "Updating printer.cfg..."
# BunnyBox modifies printer.cfg during its install. We overwrite it here with our
# unified version that includes all required BunnyBox, HelixScreen, and KAMP includes.
# printer.cfg also expects timelapse.cfg, plr.cfg, and MCU_ID.cfg to already exist
# on the machine from stock firmware — these are not installed by this script.
# Verified live: github.com/Camden-Winder/Qidi-Q2-superuser Install-Script/printer-BunnyBox&HelixScreen.cfg
# Destination:   /home/mks/printer_data/config/printer.cfg
curl -sSL https://raw.githubusercontent.com/Camden-Winder/Qidi-Q2-superuser/refs/heads/main/Install-Script/printer-BunnyBox%26HelixScreen.cfg \
  -o /home/mks/printer_data/config/printer.cfg
echo "printer.cfg updated."
echo ""

echo "Applying KAMP settings..."
# Creates the KAMP subdirectory if it doesn't exist, matching the path that
# printer.cfg expects: [include ./KAMP/KAMP_Settings.cfg]
mkdir -p /home/mks/printer_data/config/KAMP
# Filename uses capital S (KAMP_Settings.cfg) to match the [include] directive
# in printer.cfg exactly. Linux is case-sensitive — wrong case = file not found at boot.
# Verified live: github.com/Camden-Winder/Qidi-Q2-superuser Install-Script/KAMP_settings.cfg
# Destination:   /home/mks/printer_data/config/KAMP/KAMP_Settings.cfg
curl -sSL https://raw.githubusercontent.com/Camden-Winder/Qidi-Q2-superuser/refs/heads/main/Install-Script/KAMP_settings.cfg \
  -o /home/mks/printer_data/config/KAMP/KAMP_Settings.cfg
echo "KAMP settings applied."
echo ""

echo "Installing HelixScreen preset..."
# Presets are full settings templates placed in assets/config/presets/.
# The filename (minus .json) is the preset name shown in the HelixScreen UI.
# This preset sets the correct Q2 home screen layout, fan mappings, LED config,
# and macros for a BunnyBox + HelixScreen install.
# The directory is created here explicitly because this script runs before
# HelixScreen's first launch, which is when it would normally create the folder.
# HelixScreen installs to /home/mks/helixscreen on the Q2 because printer_data exists,
# confirmed from live settings.json at /home/mks/helixscreen/config/settings.json.
# Destination: /home/mks/helixscreen/assets/config/presets/Qidi-Q2-BunnyBox.json
mkdir -p /home/mks/helixscreen/assets/config/presets
curl -sSL https://raw.githubusercontent.com/Camden-Winder/Qidi-Q2-superuser/refs/heads/main/Install-Script/Qidi-Q2-BunnyBox.json \
  -o /home/mks/helixscreen/assets/config/presets/Qidi-Q2-BunnyBox.json
echo "HelixScreen preset installed."
echo ""

echo "Install complete."
