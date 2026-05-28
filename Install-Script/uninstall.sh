#!/bin/sh

echo "Starting uninstall and restore process..."
echo ""

echo "Backing up current configs..."
mkdir -p /home/mks/mudinstallbackups
rsync -a /home/mks/printer_data/config/ /home/mks/mudinstallbackups/
echo "Backup complete."
echo ""

echo "Checking for HelixScreen installation..."
if [ -d "/home/mks/helixscreen" ]; then
    echo "HelixScreen detected. Uninstalling..."
    curl -sSL https://releases.helixscreen.org/install.sh | sudo sh -s -- --remove
    echo "HelixScreen uninstall complete."
    echo ""

    echo "Re-enabling stock Qidi screen services..."
    sudo systemctl stop helixscreen
    sudo systemctl disable helixscreen
    sudo systemctl mask helixscreen

    sudo systemctl enable lightdm
    sudo systemctl restart lightdm

    sudo systemctl enable makerbase-client
    sudo systemctl restart makerbase-client
    echo "Stock screen restored."
else
    echo "HelixScreen not detected. Skipping."
fi
echo ""

echo "Checking for Bunny Box installation..."
if [ -d "/home/mks/Happy-Hare" ]; then
    echo "Bunny Box detected. Attempting uninstall..."

    if [ -f "/home/mks/Happy-Hare/install.sh" ]; then
        sudo bash /home/mks/Happy-Hare/install.sh -d
        echo "Bunny Box uninstall complete."
    else
        echo "install.sh not found inside Happy-Hare. Cannot uninstall."
    fi
else
    echo "Bunny Box not detected. Skipping."
fi
echo ""

echo "Restoring configs from mudstockbackups..."
if [ -d "/home/mks/mudstockbackups" ]; then
    rsync -a --no-owner --no-group /home/mks/mudstockbackups/ /home/mks/printer_data/config/
    echo "Config restore complete."
else
    echo "No mudstockbackups folder found. Skipping restore."
fi
echo ""

echo "Uninstall and restore process complete."
