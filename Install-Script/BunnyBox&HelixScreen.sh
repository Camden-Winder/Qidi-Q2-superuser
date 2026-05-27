#!/bin/bash
# =====================================================================
# BunnyBox & HelixScreen installer for Qidi Q2
#
# Installs BunnyBox (Happy Hare MMU), HelixScreen, unified configs,
# and box_drying.cfg (spool rotation during drying). Patches
# mmu_parameters.cfg to enable the Happy Hare Environment Manager.
#
# Detects existing installs and offers interactive menu, or accepts
# CLI flags for headless/scripted use:
#   --uninstall     Uninstall both and exit (no interactive prompt)
#   --clean         Clean reinstall (uninstall first, then install)
#   --reinstall     Reinstall over existing (keeps MMU calibration)
# =====================================================================

set -euo pipefail

# ---------- repo bases (edit these if you fork) ----------------------
REPO_BASE='https://raw.githubusercontent.com/Camden-Winder/Qidi-Q2-superuser/refs/heads/main/Install-Script'
BUNNYBOX_INSTALLER='https://raw.githubusercontent.com/Camden-Winder/Bunny-Box/refs/heads/main/Q2/install-bb-q2.sh'
HELIXSCREEN_INSTALLER='https://raw.githubusercontent.com/prestonbrown/helixscreen/main/scripts/install.sh'

# ---------- paths ----------------------------------------------------
CONFIG_DIR='/home/mks/printer_data/config'
MMU_PARAMS="${CONFIG_DIR}/mmu/base/mmu_parameters.cfg"
BACKUP_ROOT='/home/mks/mudstockbackups'
HELIX_DIR='/home/mks/helixscreen'
HELIX_CONFIG_DIR="${HELIX_DIR}/config"
HAPPY_HARE_DIR="${HOME}/happy_hare"

# ---------- helpers --------------------------------------------------
banner() {
    echo ""
    echo "================================================================="
    echo "  $1"
    echo "================================================================="
}

fetch() {
    local url="$1"
    local dest="$2"
    curl --fail --silent --show-error --location "$url" --output "$dest"
    if [ ! -s "$dest" ]; then
        echo "ERROR: Downloaded file is empty: ${dest}"
        echo "       URL: ${url}"
        exit 1
    fi
}

# ---------- detection ------------------------------------------------
bunnybox_installed() {
    [ -d "${CONFIG_DIR}/mmu" ] && [ -f "${CONFIG_DIR}/mmu/base/mmu_machine.cfg" ]
}

helixscreen_installed() {
    [ -d "$HELIX_DIR" ] || systemctl is-enabled helixscreen &>/dev/null
}

# ---------- pre-flight checks ----------------------------------------
preflight() {
    banner "Pre-flight checks"

    # Verify we can reach GitHub
    if ! curl --fail --silent --head --max-time 10 \
         'https://raw.githubusercontent.com' >/dev/null 2>&1; then
        echo "ERROR: Cannot reach raw.githubusercontent.com"
        echo "Check your network connection and try again."
        exit 1
    fi
    echo "  Network connectivity:  OK"

    # Verify config directory exists
    if [ ! -d "$CONFIG_DIR" ]; then
        echo "ERROR: Config directory not found: ${CONFIG_DIR}"
        echo "Is this a Qidi Q2 running Klipper?"
        exit 1
    fi
    echo "  Config directory:      OK"

    # Verify force_move is enabled (needed for spool rotation)
    if [ -f "${CONFIG_DIR}/printer.cfg" ]; then
        if grep -q 'enable_force_move.*True' "${CONFIG_DIR}/printer.cfg" 2>/dev/null; then
            echo "  force_move enabled:    OK"
        else
            echo "  force_move enabled:    WARN (not found — spool rotation may not work)"
        fi
    fi

    echo "  Pre-flight complete."
}

# ---------- uninstall ------------------------------------------------
uninstall_bunnybox() {
    banner "Uninstalling BunnyBox / Happy Hare"

    if [ -f "${HAPPY_HARE_DIR}/install.sh" ]; then
        echo "Running Happy Hare uninstaller..."
        bash "${HAPPY_HARE_DIR}/install.sh" -u || true
    else
        echo "Happy Hare uninstaller not found, removing manually..."
        rm -rf "${CONFIG_DIR}/mmu"
        rm -rf "${HAPPY_HARE_DIR}"
        for f in mmu.py mmu_machine.py mmu_leds.py; do
            rm -f "${HOME}/klipper/klippy/extras/${f}"
        done
        rm -f "${HOME}/moonraker/moonraker/components/mmu_server.py"
    fi

    rm -f "${CONFIG_DIR}/bunnybox_macros.cfg"
    rm -f "${CONFIG_DIR}/box_drying.cfg"

    echo ""
    echo "BunnyBox / Happy Hare uninstalled."
    echo ""
    echo "  NOTE: printer.cfg still references [include mmu/base/*.cfg]"
    echo "  and [include bunnybox_macros.cfg]. Klipper will error until you"
    echo "  restore stock printer.cfg from backup or reinstall BunnyBox."
    echo "  Backups: ${BACKUP_ROOT}/"
}

uninstall_helixscreen() {
    banner "Uninstalling HelixScreen"

    sudo systemctl stop helixscreen 2>/dev/null || true
    sudo systemctl disable helixscreen 2>/dev/null || true
    sudo rm -f /etc/systemd/system/helixscreen.service
    sudo systemctl daemon-reload 2>/dev/null || true
    rm -rf "$HELIX_DIR"

    echo "HelixScreen uninstalled."
}

# ---------- backup ---------------------------------------------------
do_backup() {
    banner "Backing up current configs"
    BACKUP_DIR="${BACKUP_ROOT}/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    rsync -a "${CONFIG_DIR}/" "${BACKUP_DIR}/"
    echo "Backup written to ${BACKUP_DIR}"
}

# ---------- interactive menu -----------------------------------------
show_menu() {
    local has_bb has_hs
    has_bb=$(bunnybox_installed && echo true || echo false)
    has_hs=$(helixscreen_installed && echo true || echo false)

    echo ""
    echo "  Existing installation detected:"
    if [ "$has_bb" = true ]; then
        echo "    BunnyBox / Happy Hare : INSTALLED"
    else
        echo "    BunnyBox / Happy Hare : not found"
    fi
    if [ "$has_hs" = true ]; then
        echo "    HelixScreen           : INSTALLED"
    else
        echo "    HelixScreen           : not found"
    fi
    echo ""
    echo "  What would you like to do?"
    echo ""
    echo "    1) Reinstall over existing  (keeps current MMU calibration)"
    echo "    2) Clean reinstall          (uninstall all, then reinstall)"

    if [ "$has_bb" = true ] && [ "$has_hs" = true ]; then
        echo "    3) Uninstall BunnyBox only"
        echo "    4) Uninstall HelixScreen only"
        echo "    5) Uninstall both           (remove all and exit)"
        echo "    6) Cancel"
    elif [ "$has_bb" = true ]; then
        echo "    3) Uninstall BunnyBox only"
        echo "    4) Cancel"
    elif [ "$has_hs" = true ]; then
        echo "    3) Uninstall HelixScreen only"
        echo "    4) Cancel"
    fi

    echo ""
    printf "  Enter choice: "

    local choice
    read -r choice </dev/tty

    if [ "$has_bb" = true ] && [ "$has_hs" = true ]; then
        case "$choice" in
            1) ACTION="reinstall" ;;
            2) ACTION="clean_reinstall" ;;
            3) ACTION="uninstall_bb" ;;
            4) ACTION="uninstall_hs" ;;
            5) ACTION="uninstall_both" ;;
            6) ACTION="cancel" ;;
            *) echo "  Invalid choice '${choice}'."; exit 1 ;;
        esac
    elif [ "$has_bb" = true ]; then
        case "$choice" in
            1) ACTION="reinstall" ;;
            2) ACTION="clean_reinstall" ;;
            3) ACTION="uninstall_bb" ;;
            4) ACTION="cancel" ;;
            *) echo "  Invalid choice '${choice}'."; exit 1 ;;
        esac
    elif [ "$has_hs" = true ]; then
        case "$choice" in
            1) ACTION="reinstall" ;;
            2) ACTION="clean_reinstall" ;;
            3) ACTION="uninstall_hs" ;;
            4) ACTION="cancel" ;;
            *) echo "  Invalid choice '${choice}'."; exit 1 ;;
        esac
    fi
}

# ---------- post-install verification --------------------------------
verify_install() {
    banner "Verifying installation"
    local ok=true

    for f in printer.cfg gcode_macro.cfg box_drying.cfg KAMP_Settings.cfg; do
        if [ -s "${CONFIG_DIR}/${f}" ]; then
            echo "  ${f}: OK"
        else
            echo "  ${f}: MISSING"
            ok=false
        fi
    done

    if [ -f "$MMU_PARAMS" ]; then
        if grep -q '^heater_vent_macro: _QIDI_BOX_VENT' "$MMU_PARAMS" && \
           grep -q '^heater_vent_interval: 5' "$MMU_PARAMS"; then
            echo "  mmu_parameters.cfg:   OK (vent macro configured)"
        else
            echo "  mmu_parameters.cfg:   WARN (vent macro not set)"
            ok=false
        fi
    else
        echo "  mmu_parameters.cfg:   MISSING"
        ok=false
    fi

    if [ -s "${HELIX_CONFIG_DIR}/settings.json" ]; then
        echo "  helixscreen settings: OK"
    else
        echo "  helixscreen settings: MISSING"
        ok=false
    fi

    if [ "$ok" = true ]; then
        echo "  All files verified."
    else
        echo ""
        echo "  WARNING: Some files are missing or misconfigured."
        echo "  The install may not work correctly."
    fi
}

# ---------- main flow ------------------------------------------------
banner "BunnyBox & HelixScreen Installer for Qidi Q2"

ACTION="fresh_install"

# Parse CLI flags for headless use
case "${1:-}" in
    --uninstall)  ACTION="uninstall_both" ;;
    --clean)      ACTION="clean_reinstall" ;;
    --reinstall)  ACTION="reinstall" ;;
    --help|-h)
        echo "Usage: $0 [--reinstall|--clean|--uninstall|--help]"
        echo "  (no args)    Interactive menu"
        echo "  --reinstall  Reinstall over existing (keeps MMU calibration)"
        echo "  --clean      Uninstall first, then reinstall"
        echo "  --uninstall  Uninstall both and exit"
        exit 0
        ;;
    "")
        # No flag — use interactive menu if existing install detected
        if bunnybox_installed || helixscreen_installed; then
            show_menu
        else
            echo "  No existing installation detected. Proceeding with fresh install."
        fi
        ;;
    *)
        echo "Unknown option: $1 (try --help)"
        exit 1
        ;;
esac

# -- handle uninstall-only actions ------------------------------------
case "$ACTION" in
    cancel)
        echo "  Cancelled. Nothing changed."
        exit 0
        ;;
    uninstall_bb)
        do_backup
        uninstall_bunnybox
        banner "Done"
        echo "  BunnyBox removed. HelixScreen was not changed."
        echo "  Backup at: ${BACKUP_DIR}"
        exit 0
        ;;
    uninstall_hs)
        do_backup
        uninstall_helixscreen
        banner "Done"
        echo "  HelixScreen removed. BunnyBox was not changed."
        echo "  Backup at: ${BACKUP_DIR}"
        exit 0
        ;;
    uninstall_both)
        do_backup
        if bunnybox_installed; then uninstall_bunnybox; fi
        if helixscreen_installed; then uninstall_helixscreen; fi
        banner "Done (uninstall complete)"
        echo "  Both BunnyBox and HelixScreen removed."
        echo "  Restore stock configs from: ${BACKUP_DIR}"
        exit 0
        ;;
esac

# -- pre-flight -------------------------------------------------------
preflight

# -- backup -----------------------------------------------------------
if [ -z "${BACKUP_DIR:-}" ]; then
    do_backup
fi

# -- start install log ------------------------------------------------
INSTALL_LOG="${BACKUP_ROOT}/install_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$INSTALL_LOG") 2>&1
echo "Install log: ${INSTALL_LOG}"

# -- uninstall first (clean reinstall only) ---------------------------
if [ "$ACTION" = "clean_reinstall" ]; then
    if bunnybox_installed; then uninstall_bunnybox; fi
    if helixscreen_installed; then uninstall_helixscreen; fi
    echo "  Uninstall complete. Proceeding with fresh install..."
fi

# -- BunnyBox ---------------------------------------------------------
# Third-party installers may exit non-zero for warnings (e.g. already
# installed). Temporarily relax errexit so a warning doesn't abort us.
banner "Installing BunnyBox (Happy Hare MMU)"
set +e
wget -qO - "$BUNNYBOX_INSTALLER" | bash
BB_EXIT=$?
set -e
if [ $BB_EXIT -ne 0 ]; then
    echo "WARNING: BunnyBox installer exited with code ${BB_EXIT}."
    echo "This may be normal for reinstalls. Continuing..."
fi
echo "BunnyBox installed."

# -- HelixScreen ------------------------------------------------------
banner "Installing HelixScreen"
set +e
curl --fail --silent --show-error --location "$HELIXSCREEN_INSTALLER" | sh
HS_EXIT=$?
set -e
if [ $HS_EXIT -ne 0 ]; then
    echo "WARNING: HelixScreen installer exited with code ${HS_EXIT}."
    echo "This may be normal for reinstalls. Continuing..."
fi
echo "HelixScreen installed."

# -- unified configs --------------------------------------------------
banner "Installing unified gcode_macro.cfg & printer.cfg"
fetch "${REPO_BASE}/gcode_macro-BunnyBox%26HelixScreen.cfg" \
      "${CONFIG_DIR}/gcode_macro.cfg"
fetch "${REPO_BASE}/printer(BunnyBox%26HelixScreen).cfg" \
      "${CONFIG_DIR}/printer.cfg"

# Safety net: fix KAMP include path if it has the double-nesting bug
if grep -q '\[include \./KAMP/KAMP_Settings\.cfg\]' "${CONFIG_DIR}/printer.cfg" 2>/dev/null; then
    sed -i 's|\[include \./KAMP/KAMP_Settings\.cfg\]|[include KAMP_Settings.cfg]|' \
        "${CONFIG_DIR}/printer.cfg"
    echo "  Fixed KAMP include path."
fi
echo "Unified configs installed."

# -- box_drying.cfg ---------------------------------------------------
banner "Installing box_drying.cfg (spool rotation during drying)"
fetch "${REPO_BASE}/box_drying.cfg" \
      "${CONFIG_DIR}/box_drying.cfg"
echo "box_drying.cfg installed."

# -- patch mmu_parameters.cfg ----------------------------------------
banner "Configuring Happy Hare Environment Manager"
if [ -f "$MMU_PARAMS" ]; then
    CHANGED=0

    # heater_vent_macro → our rotation callback
    if grep -q '^heater_vent_macro:' "$MMU_PARAMS"; then
        if ! grep -q '^heater_vent_macro: _QIDI_BOX_VENT' "$MMU_PARAMS"; then
            sed -i 's/^heater_vent_macro:.*/heater_vent_macro: _QIDI_BOX_VENT/' "$MMU_PARAMS"
            CHANGED=1
        fi
    else
        echo "heater_vent_macro: _QIDI_BOX_VENT" >> "$MMU_PARAMS"
        CHANGED=1
    fi

    # heater_vent_interval → 5 minutes
    if grep -q '^heater_vent_interval:' "$MMU_PARAMS"; then
        if ! grep -q '^heater_vent_interval: 5' "$MMU_PARAMS"; then
            sed -i 's/^heater_vent_interval:.*/heater_vent_interval: 5/' "$MMU_PARAMS"
            CHANGED=1
        fi
    else
        echo "heater_vent_interval: 5" >> "$MMU_PARAMS"
        CHANGED=1
    fi

    if [ $CHANGED -eq 1 ]; then
        echo "  mmu_parameters.cfg patched."
    else
        echo "  mmu_parameters.cfg already correct."
    fi
    echo "  heater_vent_macro:    _QIDI_BOX_VENT"
    echo "  heater_vent_interval: 5 minutes"
else
    echo "WARNING: ${MMU_PARAMS} not found."
    echo "Manually set heater_vent_macro: _QIDI_BOX_VENT"
    echo "and heater_vent_interval: 5 in mmu_parameters.cfg"
fi

# -- KAMP settings ----------------------------------------------------
banner "Applying KAMP settings"
fetch "${REPO_BASE}/KAMP_settings.cfg" \
      "${CONFIG_DIR}/KAMP_settings.cfg"
echo "KAMP settings applied."

# -- HelixScreen settings ---------------------------------------------
banner "Applying HelixScreen settings"
mkdir -p "$HELIX_CONFIG_DIR"
fetch "${REPO_BASE}/helixscreen_settings.json" \
      "${HELIX_CONFIG_DIR}/settings.json"
echo "HelixScreen settings applied."

# -- verify -----------------------------------------------------------
verify_install

# -- done -------------------------------------------------------------
banner "Install complete"
cat <<EOF

Next steps:
  1. FIRMWARE_RESTART (Klipper console or HelixScreen)
  2. Verify:    systemctl status klipper
  3. First-time only — calibrate MMU gear steppers:
        MMU_CALIBRATE_GEAR GATE=0 LENGTH=100
     Mark filament, measure travel, re-run with MEASURED=<mm>
  4. Start drying:
        BOX_DRY TEMP=45 TIME=300
     or auto-select from gate filament types:
        MMU_HEATER DRY=1
  5. Check status:   BOX_DRY_STATUS
  6. Stop drying:    BOX_DRY_STOP

Install log: ${INSTALL_LOG}
Config backup: ${BACKUP_DIR}

EOF
