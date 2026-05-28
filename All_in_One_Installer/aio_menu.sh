#!/bin/bash
# =====================================================================
# Qidi Q2 Superuser - All-in-One (AIO) Installer / Manager
#
# A single entry point for the Camden-Winder/Qidi-Q2-superuser
# toolkit. Drives every supported install path and uninstall path from
# one ANSI-colored menu:
#
#   * Install BunnyBox & HelixScreen   (Q2 with Qidi Box)
#   * Install Just Faster Printer      (Q2 without Box, stock screen)
#   * Revert to Backup                 (uninstall both + restore stock)
#   * About
#
# Target: Qidi Q2, ARM Linux, user 'mks', running Klipper. Do NOT run
# as root - this script will refuse to.
# =====================================================================

set -uo pipefail

# ---------- version --------------------------------------------------
AIO_VERSION='RC2.14'

# ---------- repo / installer URLs ------------------------------------
REPO_REF="${AIO_REPO_REF:-main}"
REPO_BASE="https://raw.githubusercontent.com/Camden-Winder/Qidi-Q2-superuser/refs/heads/${REPO_REF}/Install-Script"
BUNNYBOX_INSTALLER='https://raw.githubusercontent.com/Camden-Winder/Bunny-Box/refs/heads/main/Q2/install-bb-q2.sh'
# Pinned to the minimum required release (>= v0.99.66 for Qidi Box support).
# Update HELIXSCREEN_PIN when a newer stable release ships.
# Both the installer script AND the binary are pinned to the same tag so
# upstream installer changes (e.g. generalization for other printers) don't
# silently regress Q2 behavior.
HELIXSCREEN_PIN='v0.99.70'
HELIXSCREEN_INSTALLER="https://raw.githubusercontent.com/prestonbrown/helixscreen/${HELIXSCREEN_PIN}/scripts/install.sh"
HELIXSCREEN_RELEASE_ZIP="https://raw.githubusercontent.com/ChanceVegas/Qidi-Q2-superuser_helpinghands/refs/heads/${REPO_REF}/Happier_Hare/install_happier_hare.sh"
HAPPIER_HARE_INSTALLER="https://raw.githubusercontent.com/Camden-Winder/Qidi-Q2-superuser/refs/heads/${REPO_REF}/Happier_Hare/install_happier_hare.sh"
HAPPIER_HARE_RELEASE_TAG="${HAPPIER_HARE_RELEASE_TAG:-happier-hare-rc2.12}"
HAPPIER_HARE_RELEASE_ZIP="https://github.com/ChanceVegas/Qidi-Q2-superuser_helpinghands/releases/download/${HAPPIER_HARE_RELEASE_TAG}/helixscreen-pi.zip"
HAPPIER_HARE_ZIP_URL="${HAPPIER_HARE_ZIP_URL:-}"
HAPPIER_HARE_LOCAL_ZIP="${HAPPIER_HARE_LOCAL_ZIP:-/home/mks/helixscreen-pi-happier-hare.zip}"
HELIX_UNINSTALLER='https://releases.helixscreen.org/install.sh'
# KAMP sub-files. KAMP_Settings.cfg is fetched from REPO_BASE (our custom settings);
# the actual macro files come from upstream KAMP and are installed alongside it.
KAMP_BASE='https://raw.githubusercontent.com/kyleisah/Klipper-Adaptive-Meshing-Purging/refs/heads/main/Configuration'
# Mainsail is delegated to Camden-Winder's standalone installer, which
# installs to /home/mks/mainsail on port 100 (Qidi's stock lighttpd owns
# port 80) and patches moonraker.conf for CORS.
MAINSAIL_INSTALLER='https://raw.githubusercontent.com/Camden-Winder/Qidi-Q2-superuser/refs/heads/main/Install-Script/install-mainsail.sh'

# ---------- paths ----------------------------------------------------
CONFIG_DIR='/home/mks/printer_data/config'
BACKUP_ROOT='/home/mks/mudstockbackups'
HELIX_DIR='/home/mks/helixscreen'
HELIX_PRINT_DIR='/home/mks/helix_print'
HELIX_CONFIG_DIR="${HELIX_DIR}/config"
HAPPY_HARE_DIR='/home/mks/Happy-Hare'
KIAUH_DIR='/home/mks/kiauh'
KIAUH_BACKUPS_DIR='/home/mks/kiauh-backups'
KIAUH_UPPER_DIR='/home/mks/KIAUH'
KIAUH_UPPER_BACKUPS_DIR='/home/mks/KIAUH-backups'
MAINSAIL_DIR='/home/mks/mainsail'
MAINSAIL_NGINX_SITE_AVAIL='/etc/nginx/sites-available/mainsail'
MAINSAIL_NGINX_SITE_ENABLED='/etc/nginx/sites-enabled/mainsail'
MAINSAIL_PORT=100
# Marker written when AIO installs nginx (it wasn't present before). Tells
# uninstall_mainsail() whether to remove the package or leave it alone.
MAINSAIL_NGINX_MARKER="${BACKUP_ROOT}/.aio_nginx_installed"
USTREAMER_SERVICE='ustreamer-camera'
USTREAMER_UNIT="/etc/systemd/system/ustreamer-camera.service"
USTREAMER_PORT=8080
USTREAMER_DEVICE='/dev/video0'
CAMERA_MARKER="${BACKUP_ROOT}/.aio_camera_installed"
USTREAMER_PACKAGE_MARKER="${BACKUP_ROOT}/.aio_ustreamer_installed"
MOONRAKER_PORT=7125
KLIPPERSCREEN_REPO_URL='https://github.com/moggieuk/KlipperScreen-Happy-Hare-Edition.git'
KLIPPERSCREEN_DIR='/home/mks/KlipperScreen'
KLIPPERSCREEN_VENV='/home/mks/.KlipperScreen-env'
KLIPPERSCREEN_SERVICE='KlipperScreen'

# Returns the installed HelixScreen version string (e.g. "0.99.66") or
# empty if it can't be determined. Tries the binary, then a VERSION file.
helixscreen_version() {
    local v=""
    if [ -x "${HELIX_DIR}/helixscreen" ]; then
        v=$("${HELIX_DIR}/helixscreen" --version 2>/dev/null | head -n 1 | \
            grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
    fi
    if [ -z "$v" ] && [ -x "${HELIX_DIR}/bin/helix-screen" ]; then
        v=$("${HELIX_DIR}/bin/helix-screen" --version 2>/dev/null | head -n 1 | \
            grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
    fi
    if [ -z "$v" ] && [ -f "${HELIX_DIR}/VERSION" ]; then
        v=$(head -n 1 "${HELIX_DIR}/VERSION" 2>/dev/null | \
            grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
    fi
    if [ -z "$v" ] && [ -x "${HELIX_DIR}/bin/helix-screen" ]; then
        v="${HELIXSCREEN_PIN#v}"
    fi
    echo "$v"
}

# Compare two semver-ish strings. Returns 0 if $1 >= $2.
helixscreen_version_ge() {
    [ -z "$1" ] && return 1
    local IFS=.
    local -a have want
    read -r -a have <<< "$1"
    read -r -a want <<< "$2"
    for i in 0 1 2; do
        local h=${have[$i]:-0} w=${want[$i]:-0}
        if [ "$h" -gt "$w" ]; then return 0; fi
        if [ "$h" -lt "$w" ]; then return 1; fi
    done
    return 0
}

moonraker_get() {
    local path="$1"
    curl --fail --silent --show-error --max-time 3 \
        "http://127.0.0.1:${MOONRAKER_PORT}${path}" 2>/dev/null
}

helixscreen_binary_candidates() {
    [ -d "${HELIX_DIR}/bin" ] || return 0
    find "${HELIX_DIR}/bin" -maxdepth 1 -type f -name 'helix-screen*' \
        -print 2>/dev/null
}

verify_systemd_service_health() {
    local service="$1"
    local label="$2"
    local required="${3:-true}"

    if ! systemctl cat "$service" >/dev/null 2>&1; then
        if [ "$required" = true ]; then
            err "${label}: systemd unit ${service} not found"
        else
            info "${label}: systemd unit ${service} not installed"
        fi
        return 0
    fi

    local active enabled result restarts
    active=$(systemctl is-active "$service" 2>/dev/null || true)
    enabled=$(systemctl is-enabled "$service" 2>/dev/null || true)
    result=$(systemctl show "$service" -p Result --value 2>/dev/null || true)
    restarts=$(systemctl show "$service" -p NRestarts --value 2>/dev/null || true)
    case "$restarts" in
        ''|*[!0-9]*) restarts=0 ;;
    esac

    case "$active" in
        active)
            ok "${label}: active (${service}, enabled=${enabled:-unknown})"
            ;;
        activating|reloading)
            warn "${label}: ${active} (${service})"
            ;;
        *)
            if [ "$required" = true ]; then
                err "${label}: ${active:-unknown} (${service})"
            else
                info "${label}: ${active:-unknown} (${service})"
            fi
            ;;
    esac

    if [ "$result" != "" ] && [ "$result" != "success" ]; then
        warn "${label}: last systemd result=${result}"
    fi
    if [ "$restarts" -gt 0 ]; then
        warn "${label}: systemd restart count=${restarts}"
    fi
}

show_systemd_journal_tail() {
    local service="$1"
    local label="$2"
    local lines

    lines=$(journalctl -u "$service" -n 12 --no-pager 2>/dev/null || true)
    if [ -n "$lines" ]; then
        warn "${label}: recent journal lines:"
        printf '%s\n' "$lines" | while IFS= read -r line; do
            warn "  $line"
        done
    else
        warn "${label}: no recent journal lines available"
    fi
}

verify_klipper_runtime_health() {
    banner "Klipper / Moonraker runtime health"

    verify_systemd_service_health klipper "Klipper" true
    verify_systemd_service_health moonraker "Moonraker" true

    local response state state_msg
    if response=$(moonraker_get "/printer/info"); then
        state=$(printf '%s' "$response" | python3 -c \
            'import json,sys; print(json.load(sys.stdin).get("result",{}).get("state","unknown"))' \
            2>/dev/null || printf 'unknown')
        state_msg=$(printf '%s' "$response" | python3 -c \
            'import json,sys; print(json.load(sys.stdin).get("result",{}).get("state_message",""))' \
            2>/dev/null || true)
        if [ "$state" = "ready" ]; then
            ok "Moonraker reports Klipper state: ready"
        else
            warn "Moonraker reports Klipper state: ${state}"
            [ -n "$state_msg" ] && warn "Klipper state message: ${state_msg}"
        fi
    else
        warn "Moonraker /printer/info did not respond on 127.0.0.1:${MOONRAKER_PORT}"
    fi

    local recent
    recent=$(journalctl -u klipper --since '-15 min' --no-pager 2>/dev/null | \
        grep -Ei 'traceback|exception|shutdown|crash|error|unable|failed|restart' | \
        tail -n 8 || true)
    if [ -n "$recent" ]; then
        warn "Recent Klipper journal lines worth checking:"
        printf '%s\n' "$recent" | while IFS= read -r line; do
            warn "  $line"
        done
    else
        ok "No obvious Klipper crash/error lines in the last 15 minutes"
    fi
}

verify_helixscreen_runtime_health() {
    banner "HelixScreen runtime health"

    if helixscreen_installed; then
        verify_systemd_service_health helixscreen "HelixScreen" true
        local v
        v=$(helixscreen_version)
        if [ -n "$v" ]; then
            ok "HelixScreen version: ${v}"
        else
            warn "Could not determine HelixScreen version"
        fi
        verify_qidi_box_helixscreen
    else
        info "HelixScreen not installed"
    fi
}

verify_stock_display_runtime_health() {
    banner "Qidi stock display runtime health"

    verify_systemd_service_health lightdm "LightDM" true
    verify_systemd_service_health makerbase-client "Makerbase stock UI" true

    if ! systemctl is-active --quiet lightdm 2>/dev/null; then
        show_systemd_journal_tail lightdm "LightDM"
    fi
    if ! systemctl is-active --quiet makerbase-client 2>/dev/null; then
        show_systemd_journal_tail makerbase-client "Makerbase stock UI"
    fi
}

verify_happy_hare_runtime_health() {
    banner "BunnyBox / Happy Hare / MMU runtime health"

    if bunnybox_installed; then
        ok "BunnyBox config detected"
    else
        info "BunnyBox config not detected"
        return 0
    fi

    if [ -d "${HOME}/klipper/klippy/extras/mmu" ]; then
        ok "Happy Hare Klipper extras package linked"
    else
        warn "Happy Hare Klipper extras package missing: ${HOME}/klipper/klippy/extras/mmu"
    fi

    if [ -f "${HOME}/moonraker/moonraker/components/mmu_server.py" ]; then
        ok "Happy Hare Moonraker component linked"
    else
        warn "Happy Hare Moonraker component missing: ${HOME}/moonraker/moonraker/components/mmu_server.py"
    fi

    if grep -q '^\[mmu_server\]' "${CONFIG_DIR}/moonraker.conf" 2>/dev/null; then
        ok "moonraker.conf has [mmu_server]"
    else
        warn "moonraker.conf missing [mmu_server]"
    fi

    local response has_mmu summary
    if response=$(moonraker_get "/printer/objects/list"); then
        has_mmu=$(printf '%s' "$response" | python3 -c \
            'import json,sys; objs=json.load(sys.stdin).get("result",{}).get("objects",[]); print("yes" if "mmu" in objs else "no")' \
            2>/dev/null || printf 'unknown')
        if [ "$has_mmu" = "yes" ]; then
            ok "Moonraker exposes the Happy Hare mmu object"
        else
            warn "Moonraker objects list does not expose mmu"
        fi
    else
        warn "Could not query Moonraker objects list"
    fi

    if response=$(moonraker_get "/printer/objects/query?mmu"); then
        summary=$(printf '%s' "$response" | python3 -c '
import json, sys
data = json.load(sys.stdin)
mmu = data.get("result", {}).get("status", {}).get("mmu")
if not isinstance(mmu, dict):
    sys.exit(2)
keys = [
    "enabled", "is_enabled", "action", "print_state", "tool", "gate",
    "filament", "filament_pos", "selector_pos", "sync_drive"
]
parts = [f"{k}={mmu[k]}" for k in keys if k in mmu]
print(", ".join(parts) if parts else "mmu object reachable")
' 2>/dev/null || true)
        if [ -n "$summary" ]; then
            ok "MMU status: ${summary}"
        else
            warn "MMU object query returned, but status could not be parsed"
        fi
    else
        warn "Could not query Moonraker mmu object"
    fi
}

verify_runtime_health() {
    verify_klipper_runtime_health
    verify_happy_hare_runtime_health
    verify_helixscreen_runtime_health
    if ! helixscreen_installed && ! klipperscreen_installed; then
        verify_stock_display_runtime_health
    fi
}

# Post-install sanity check for the Qidi Box read-path on HelixScreen.
# Warns on missing pieces, never fails - the install is already done.
verify_qidi_box_helixscreen() {
    banner "Verifying Qidi Box read-path (HelixScreen >= v0.99.66)"

    local pcfg="${CONFIG_DIR}/printer.cfg"
    local boxcfg="${CONFIG_DIR}/box.cfg"
    local fila_list="${CONFIG_DIR}/officiall_filas_list.cfg"

    if bunnybox_installed; then
        ok "Happy Hare backend active for Qidi Box control (BunnyBox installed)"
    elif [ ! -f "$boxcfg" ]; then
        warn "box.cfg missing - HelixScreen cannot detect the stock Qidi Box"
    elif ! grep -q '\[box_stepper' "$boxcfg" 2>/dev/null; then
        warn "box.cfg present but no [box_stepper slot<N>] sections found"
    else
        ok "box.cfg includes [box_stepper] sections"
    fi

    # With BunnyBox installed, [include box.cfg] MUST be inactive — loading
    # box_extras.so alongside Happy Hare's mmu package crashes Klipper
    # (both register CLEAR_TOOLCHANGE_STATE). Revert to Backup brings the
    # include back when BunnyBox is removed.
    if bunnybox_installed; then
        if [ -f "$pcfg" ] && grep -q '^\[include box\.cfg\]' "$pcfg" 2>/dev/null; then
            warn "printer.cfg has [include box.cfg] active — this WILL crash Klipper while BunnyBox is installed"
            warn "  → re-run option 1 (Install BunnyBox & HelixScreen) to disable it, or edit printer.cfg by hand"
        elif [ -f "$pcfg" ]; then
            ok "printer.cfg [include box.cfg] is disabled (correct under BunnyBox)"
        fi
    fi

    if [ ! -f "$fila_list" ]; then
        warn "officiall_filas_list.cfg missing - filament temperature lookups will not work"
        warn "(this is a Qidi stock file - restore it from a factory backup if absent)"
    else
        ok "officiall_filas_list.cfg present"
    fi

    local v
    v=$(helixscreen_version)
    if [ -z "$v" ]; then
        warn "Could not determine HelixScreen version - Qidi Box requires >= v0.99.66"
    elif helixscreen_version_ge "$v" "0.99.66"; then
        ok "HelixScreen version ${v} supports Qidi Box AMS backend"
    else
        warn "HelixScreen version ${v} is older than v0.99.66 - Qidi Box AMS may not be detected"
    fi

    local timer_patched=0 stop_patched=0 env_sensor_patch=0 seen_binary=0
    local target
    while IFS= read -r target; do
        [ -f "$target" ] || continue
        seen_binary=1
        if LC_ALL=C grep -aFq 'MMU_HEATER DRY=1 TEMP={:.0f} TIMER={}' "$target"; then
            timer_patched=1
        elif LC_ALL=C grep -aFq 'MMU_HEATER DRY=1 TEMP={:.0f} DURATION={}' "$target"; then
            warn "$(basename "$target") still uses DURATION= for Happy Hare drying - native dryer button duration may be ignored"
        fi
        if LC_ALL=C grep -aFq 'MMU_HEATER STOP=1' "$target"; then
            stop_patched=1
        elif LC_ALL=C grep -aFq 'MMU_HEATER DRY=0' "$target"; then
            warn "$(basename "$target") still uses DRY=0 for Happy Hare dryer stop - native stop may be ignored"
        fi
        if LC_ALL=C grep -aFq 'temperature_sensor box' "$target" || \
           LC_ALL=C grep -aFq 'aht20_f heater_box' "$target"; then
            env_sensor_patch=1
        fi
    done < <(helixscreen_binary_candidates)
    if [ "$seen_binary" -eq 0 ]; then
        warn "No helix-screen* binaries found under ${HELIX_DIR}/bin"
    fi
    if [ "$timer_patched" -eq 1 ]; then
        ok "HelixScreen Happy Hare dryer start command uses TIMER="
    fi
    if [ "$stop_patched" -eq 1 ]; then
        ok "HelixScreen Happy Hare dryer stop command uses STOP=1"
    fi
    if [ "$env_sensor_patch" -eq 1 ]; then
        ok "HelixScreen binary has Happier Hare Qidi Box environment sensor support"
    elif bunnybox_installed; then
        warn "HelixScreen binary does not show Happier Hare Qidi Box sensor support"
        warn "Native Box temperature/humidity may stay blank; rebuild/reinstall the patched zip."
    fi
}

patch_helixscreen_happy_hare_dryer_command() {
    banner "Patching HelixScreen Happy Hare dryer command strings"
    local target seen=0 patched=0 already=0 failed=0
    for target in "${HELIX_DIR}/bin/helix-screen" "${HELIX_DIR}/bin/helix-screen-fbdev"; do
        [ -f "$target" ] || continue
        seen=1
        python3 - "$target" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
old = b"MMU_HEATER DRY=1 TEMP={:.0f} DURATION={}"
new_cmd = b"MMU_HEATER DRY=1 TEMP={:.0f} TIMER={}"
new = new_cmd + b"\0" * (len(old) - len(new_cmd))
data = path.read_bytes()

if new_cmd in data:
    sys.exit(2)
if old not in data:
    sys.exit(3)

path.write_bytes(data.replace(old, new, 1))
sys.exit(0)
PY
        case $? in
            0)
                ok "$(basename "$target"): patched DURATION= to TIMER="
                patched=1
                ;;
            2)
                ok "$(basename "$target"): already uses TIMER="
                already=1
                ;;
            3)
                warn "$(basename "$target"): known Happy Hare dryer command not found"
                failed=1
                ;;
            *)
                warn "$(basename "$target"): patch failed"
                failed=1
                ;;
        esac

        python3 - "$target" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
old = b"MMU_HEATER DRY=0"
new_cmd = b"MMU_HEATER STOP=1"
data = path.read_bytes()

if new_cmd in data:
    sys.exit(2)

# STOP=1 is one byte longer than DRY=0, so only patch when the original
# string has two NUL bytes available. That preserves C-string termination
# and avoids corrupting the following read-only data.
pattern = old + b"\0\0"
replacement = new_cmd + b"\0"
if pattern in data:
    path.write_bytes(data.replace(pattern, replacement, 1))
    sys.exit(0)

if old in data:
    sys.exit(4)
sys.exit(3)
PY
        case $? in
            0)
                ok "$(basename "$target"): patched DRY=0 to STOP=1"
                patched=1
                ;;
            2)
                ok "$(basename "$target"): already uses STOP=1"
                already=1
                ;;
            3)
                warn "$(basename "$target"): known Happy Hare dryer stop command not found"
                ;;
            4)
                warn "$(basename "$target"): DRY=0 found, but no safe padding for in-place STOP=1 patch"
                ;;
            *)
                warn "$(basename "$target"): stop command patch failed"
                ;;
        esac
    done

    if [ "$seen" -eq 0 ]; then
        warn "No HelixScreen binary found under ${HELIX_DIR}/bin"
        return 1
    fi
    if [ "$failed" -ne 0 ] && [ "$patched" -eq 0 ] && [ "$already" -eq 0 ]; then
        warn "Native HelixScreen dryer command could not be verified"
        return 1
    fi
    return 0
}

QIDI_BOX_WRITE_DROPIN='/etc/systemd/system/helixscreen.service.d/qidi-box-write.conf'

qidi_box_write_enabled() {
    [ -f "$QIDI_BOX_WRITE_DROPIN" ] && \
    grep -q 'HELIX_QIDI_BOX_WRITE=1' "$QIDI_BOX_WRITE_DROPIN" 2>/dev/null
}

# Enable HelixScreen's experimental Qidi Box WRITE ops (load_filament,
# unload_filament, change_tool, set_tool_mapping). Upstream flags this
# as field-testing; a confirm prompt (5s default yes) gates the install.
install_qidi_box_write() {
    banner "Enabling HELIX_QIDI_BOX_WRITE (Qidi Box interactive control)"
    warn "Upstream marks this as field-testing. Read/write Qidi Box ops"
    warn "will run from HelixScreen; misbehavior could send a bad command"
    warn "to the Box hardware. Disable via Revert to Backup or by removing"
    warn "${QIDI_BOX_WRITE_DROPIN}"

    local ans=""
    printf '%sEnable HELIX_QIDI_BOX_WRITE? [Y/n, 5s default yes]: %s' "$C_YELLOW" "$C_RESET"
    if read -t 5 -r ans </dev/tty 2>/dev/null; then
        case "$ans" in
            n|N|no|NO)
                echo
                info "HELIX_QIDI_BOX_WRITE skipped — re-run or remove ${QIDI_BOX_WRITE_DROPIN} to change"
                return 0
                ;;
        esac
    else
        echo
        info "No response — enabling HELIX_QIDI_BOX_WRITE by default"
    fi

    sudo mkdir -p "$(dirname "$QIDI_BOX_WRITE_DROPIN")"
    sudo tee "$QIDI_BOX_WRITE_DROPIN" >/dev/null <<'EOF'
# Written by Qidi Q2 Superuser AIO.
# Enables HelixScreen's experimental Qidi Box write ops
# (load_filament T<N>, unload_filament, change_tool, set_tool_mapping).
[Service]
Environment="HELIX_QIDI_BOX_WRITE=1"
EOF
    sudo systemctl daemon-reload 2>/dev/null || true
    sudo systemctl restart helixscreen 2>/dev/null || true
    ok "HELIX_QIDI_BOX_WRITE=1 set; helixscreen restarted"
}

uninstall_qidi_box_write() {
    if [ ! -f "$QIDI_BOX_WRITE_DROPIN" ]; then
        return 0
    fi
    info "Removing HELIX_QIDI_BOX_WRITE drop-in..."
    sudo rm -f "$QIDI_BOX_WRITE_DROPIN"
    # Tidy the dir if empty
    sudo rmdir "$(dirname "$QIDI_BOX_WRITE_DROPIN")" 2>/dev/null || true
    sudo systemctl daemon-reload 2>/dev/null || true
    sudo systemctl restart helixscreen 2>/dev/null || true
    ok "HELIX_QIDI_BOX_WRITE disabled"
}

idle_fan_shutdown_installed() {
    [ -f "${CONFIG_DIR}/idle_fan_shutdown.cfg" ] && \
    grep -q '^\[include idle_fan_shutdown\.cfg\]' "${CONFIG_DIR}/printer.cfg" 2>/dev/null
}

uninstall_idle_fan_shutdown() {
    banner "Removing idle_fan_shutdown addon"
    local pcfg="${CONFIG_DIR}/printer.cfg"
    if [ -f "$pcfg" ]; then
        if grep -q '^\[include idle_fan_shutdown\.cfg\]' "$pcfg"; then
            sed -i '/^\[include idle_fan_shutdown\.cfg\]/d' "$pcfg"
            ok "Removed [include idle_fan_shutdown.cfg] from printer.cfg"
        fi
        # Re-enable any [idle_timeout] section we previously disabled.
        if grep -q '^#\[idle_timeout\] # disabled by AIO' "$pcfg"; then
            sed -i 's|^#\[idle_timeout\] # disabled by AIO - see idle_fan_shutdown.cfg|[idle_timeout]|' "$pcfg"
            ok "Re-enabled previously-disabled [idle_timeout] in printer.cfg"
        fi
    fi
    rm -f "${CONFIG_DIR}/idle_fan_shutdown.cfg"
    ok "idle_fan_shutdown addon removed"
}

# Menu wrapper - present an install/uninstall/cancel choice depending
# on current state.
menu_idle_fan_shutdown() {
    banner "Idle Fan Shutdown addon"
    if idle_fan_shutdown_installed; then
        info "Status: INSTALLED"
        info "After 10 minutes idle, fans + heaters power down unless"
        info "any temperature sensor reports an unsafe value."
        if confirm "Uninstall Idle Fan Shutdown addon?"; then
            uninstall_idle_fan_shutdown
        fi
    else
        info "Status: not installed"
        info "Powers down all fans + heaters after 10 minutes idle,"
        info "unless extruder/bed/chamber temps are still hot."
        info "Re-checks every 60s while temps remain unsafe."
        if confirm "Install Idle Fan Shutdown addon now?"; then
            preflight || { press_enter; return 1; }
            do_backup || { press_enter; return 1; }
            install_idle_fan_shutdown || warn "Setup had problems (see above)"
            info "Run FIRMWARE_RESTART, then sudo reboot to activate."
        fi
    fi
    press_enter
}

# Drop idle_fan_shutdown.cfg into CONFIG_DIR and patch printer.cfg so
# it's included. Idempotent - safe to re-run. Comments out any
# pre-existing [idle_timeout] section in printer.cfg first because
# Klipper errors on duplicate sections.
install_idle_fan_shutdown() {
    banner "Installing idle_fan_shutdown.cfg (10m idle → fans off, temp-gated)"
    fetch "${REPO_BASE}/idle_fan_shutdown.cfg" \
          "${CONFIG_DIR}/idle_fan_shutdown.cfg" || return 1

    local pcfg="${CONFIG_DIR}/printer.cfg"
    if [ -f "$pcfg" ]; then
        # Neutralise any existing [idle_timeout] - our include owns it.
        if grep -q '^\[idle_timeout\]' "$pcfg"; then
            sed -i 's/^\[idle_timeout\]/#[idle_timeout] # disabled by AIO - see idle_fan_shutdown.cfg/' "$pcfg"
            ok "Disabled pre-existing [idle_timeout] in printer.cfg"
        fi
        if ! grep -q '^\[include idle_fan_shutdown\.cfg\]' "$pcfg"; then
            # Insert near the other [include ...] lines at the top.
            sed -i '0,/^\[include /{ /^\[include / i\
[include idle_fan_shutdown.cfg]  # 10m idle fan/heater shutdown (AIO)
}' "$pcfg"
            ok "Added [include idle_fan_shutdown.cfg] to printer.cfg"
        else
            ok "[include idle_fan_shutdown.cfg] already present"
        fi
    else
        warn "printer.cfg not found - idle_fan_shutdown.cfg installed but not included"
    fi
}

# ---------- Mainsail (delegated to Camden-Winder's installer) --------
# Mainsail is a standalone web UI; Camden's installer handles nginx,
# moonraker CORS, and the port-100 mapping (Qidi's stock UI keeps port
# 80). AIO just runs the installer and provides detection + uninstall.

mainsail_installed() {
    [ -f "${MAINSAIL_DIR}/index.html" ] && \
    [ -f "$MAINSAIL_NGINX_SITE_AVAIL" ]
}

install_mainsail() {
    banner "Installing Mainsail (Camden-Winder's installer)"
    info "Mainsail will be available on http://<printer-ip>:${MAINSAIL_PORT}"
    info "Qidi's stock web UI on port 80 is left untouched."

    # Record pre-install nginx state. Camden's installer may run apt-get to
    # install nginx; we only remove the package on uninstall if WE installed it.
    local nginx_pre_installed=false
    if dpkg -l nginx 2>/dev/null | grep -q '^ii'; then
        nginx_pre_installed=true
        info "nginx already installed — will not be removed on Mainsail uninstall"
    fi

    run_remote_script "$MAINSAIL_INSTALLER"
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        err "Mainsail installer exited ${exit_code}"
        return 1
    fi

    if [ "$nginx_pre_installed" = false ]; then
        touch "$MAINSAIL_NGINX_MARKER"
        info "nginx was not pre-installed; it will be removed on Mainsail uninstall"
    fi

    if mainsail_installed; then
        ok "Mainsail installed at ${MAINSAIL_DIR}"
    else
        warn "Installer finished but Mainsail files not detected — check ${MAINSAIL_DIR}"
    fi

    install_camera || warn "Camera setup had problems — re-run option 6 to retry"
}

uninstall_mainsail() {
    uninstall_camera
    banner "Removing Mainsail"
    if [ -L "$MAINSAIL_NGINX_SITE_ENABLED" ] || [ -f "$MAINSAIL_NGINX_SITE_ENABLED" ]; then
        sudo rm -f "$MAINSAIL_NGINX_SITE_ENABLED" && \
            ok "Removed nginx symlink ${MAINSAIL_NGINX_SITE_ENABLED}"
    fi
    if [ -f "$MAINSAIL_NGINX_SITE_AVAIL" ]; then
        sudo rm -f "$MAINSAIL_NGINX_SITE_AVAIL" && \
            ok "Removed nginx site config ${MAINSAIL_NGINX_SITE_AVAIL}"
    fi
    if [ -d "$MAINSAIL_DIR" ]; then
        rm -rf "$MAINSAIL_DIR" 2>/dev/null || sudo rm -rf "$MAINSAIL_DIR"
        ok "Removed ${MAINSAIL_DIR}"
    fi
    # Remove nginx only if AIO installed it (marker written at install time).
    # If nginx was already on the system before Mainsail, leave it alone.
    if [ -f "$MAINSAIL_NGINX_MARKER" ]; then
        info "Removing nginx (installed by AIO for Mainsail)..."
        sudo apt-get remove --purge -y nginx nginx-common 2>/dev/null || true
        sudo apt-get autoremove -y 2>/dev/null || true
        rm -f "$MAINSAIL_NGINX_MARKER"
        ok "nginx removed"
    else
        info "nginx was pre-installed — leaving it in place"
        if command -v nginx >/dev/null 2>&1; then
            if sudo nginx -t >/dev/null 2>&1; then
                sudo systemctl reload nginx 2>/dev/null || true
                ok "nginx reloaded"
            else
                warn "nginx config test failed — check 'sudo nginx -t'"
            fi
        fi
    fi
    ok "Mainsail removed"
}

verify_mainsail() {
    if ! mainsail_installed; then
        return 0
    fi
    if curl --fail --silent --max-time 3 "http://127.0.0.1:${MAINSAIL_PORT}/" \
        -o /dev/null 2>&1; then
        ok "Mainsail reachable on http://127.0.0.1:${MAINSAIL_PORT}"
    else
        warn "Mainsail files installed but port ${MAINSAIL_PORT} not responding"
        warn "  → try: sudo systemctl restart nginx"
    fi
}

# ---------- Camera streaming (ustreamer, bundled with Mainsail) ------
# ustreamer streams the Q2's built-in USB camera as MJPEG on port 8080.
# Installed automatically alongside Mainsail; removed when Mainsail is
# removed. Moonraker's [webcam] section registers the stream URL so
# Mainsail's camera panel works out of the box.

camera_installed() {
    systemctl is-enabled --quiet "$USTREAMER_SERVICE" 2>/dev/null
}

# Returns 0 if the existing camera config matches the RC13 design (ustreamer
# bound to 127.0.0.1, Mainsail nginx /webcam/ proxy present, moonraker.conf
# stream_url uses the nginx proxy path). Used by install_camera() to decide
# whether to short-circuit or migrate from RC12.
camera_config_is_current() {
    [ -f "$USTREAMER_UNIT" ] || return 1
    grep -q 'host=127.0.0.1' "$USTREAMER_UNIT" || return 1
    [ -f "$MAINSAIL_NGINX_SITE_AVAIL" ] || return 1
    grep -q 'location /webcam/' "$MAINSAIL_NGINX_SITE_AVAIL" || return 1
    grep -q '/webcam/stream' "${CONFIG_DIR}/moonraker.conf" 2>/dev/null || return 1
    return 0
}

# Insert a /webcam/ proxy location block before the last `}` of the Mainsail
# nginx server config. Idempotent. Returns 0 if added or already present.
add_webcam_to_mainsail_nginx() {
    local conf="$MAINSAIL_NGINX_SITE_AVAIL"
    [ -f "$conf" ] || return 1
    if grep -q 'location /webcam/' "$conf" 2>/dev/null; then
        return 0
    fi
    local tmp
    tmp=$(mktemp) || return 1
    awk -v port="$USTREAMER_PORT" '
        /^}$/ { last_brace = NR }
        { lines[NR] = $0 }
        END {
            for (i = 1; i <= NR; i++) {
                if (i == last_brace) {
                    print "    location /webcam/ {"
                    print "        postpone_output 0;"
                    print "        proxy_buffering off;"
                    print "        proxy_ignore_headers X-Accel-Buffering;"
                    print "        access_log off;"
                    print "        error_log off;"
                    print "        proxy_pass http://127.0.0.1:" port "/;"
                    print "    }"
                }
                print lines[i]
            }
        }
    ' "$conf" > "$tmp" && sudo cp "$tmp" "$conf"
    local rc=$?
    rm -f "$tmp"
    return $rc
}

# Remove the /webcam/ location block from the Mainsail nginx config.
remove_webcam_from_mainsail_nginx() {
    local conf="$MAINSAIL_NGINX_SITE_AVAIL"
    [ -f "$conf" ] || return 0
    grep -q 'location /webcam/' "$conf" 2>/dev/null || return 0
    local tmp
    tmp=$(mktemp) || return 1
    awk '
        /^[[:space:]]*location \/webcam\/ \{/ { in_block = 1; depth = 1; next }
        in_block {
            for (i = 1; i <= length($0); i++) {
                c = substr($0, i, 1)
                if (c == "{") depth++
                else if (c == "}") depth--
            }
            if (depth <= 0) { in_block = 0 }
            next
        }
        { print }
    ' "$conf" > "$tmp" && sudo cp "$tmp" "$conf"
    local rc=$?
    rm -f "$tmp"
    return $rc
}

# Query Moonraker's webcam API and offer to delete any UI-added (database-source)
# webcam entries.  Called from install_camera() after moonraker restart so only
# one [webcam printer] entry exists in Mainsail.
purge_mainsail_ui_webcams() {
    local api="http://127.0.0.1:${MOONRAKER_PORT}"
    local response
    response=$(curl -sf --max-time 5 "${api}/server/webcams/list" 2>/dev/null) || {
        warn "Could not reach Moonraker API — skipping duplicate-webcam check"
        return 0
    }
    local ui_cams
    ui_cams=$(echo "$response" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for c in data.get('result', {}).get('webcams', []):
    if c.get('source') == 'database':
        print(c['uid'] + '|' + c.get('name', 'unknown'))
" 2>/dev/null)
    [ -z "$ui_cams" ] && return 0

    while IFS= read -r line; do
        local uid name
        uid="${line%%|*}"
        name="${line##*|}"
        if confirm "Delete UI-added webcam '${name}' (duplicate of [webcam printer])?"; then
            curl -sf -X DELETE --max-time 5 \
                "${api}/server/webcams/item?uid=${uid}" > /dev/null 2>&1 && \
                ok "Deleted UI webcam '${name}'" || \
                warn "Failed to delete webcam '${name}' — remove it manually in Mainsail Settings → Webcams"
        fi
    done <<< "$ui_cams"
}

install_camera() {
    banner "Setting up printer camera (ustreamer + nginx proxy)"

    if camera_installed && camera_config_is_current; then
        ok "Camera streaming already configured (current format) — skipping"
        return 0
    fi
    if camera_installed; then
        info "Existing camera config detected — rewriting to current format"
    fi

    local ustreamer_pre_installed=false
    if dpkg -l ustreamer 2>/dev/null | grep -q '^ii'; then
        ustreamer_pre_installed=true
        info "ustreamer already installed — package will be left in place on uninstall"
    fi

    info "Installing ustreamer..."
    if ! sudo apt-get install -y ustreamer 2>/dev/null; then
        warn "ustreamer not available via apt — camera not configured"
        warn "  → Install manually: sudo apt-get install ustreamer"
        return 1
    fi
    if [ "$ustreamer_pre_installed" = false ]; then
        touch "$USTREAMER_PACKAGE_MARKER"
        info "ustreamer was installed by AIO and will be removed with Mainsail"
    fi

    local ustreamer_bin
    ustreamer_bin=$(command -v ustreamer 2>/dev/null)
    if [ -z "$ustreamer_bin" ]; then
        warn "ustreamer binary not found after install — camera not configured"
        return 1
    fi

    # Auto-detect first available /dev/video* device
    local cam_device="$USTREAMER_DEVICE"
    local dev
    for dev in /dev/video0 /dev/video1 /dev/video2; do
        if [ -e "$dev" ]; then
            cam_device="$dev"
            ok "Found camera device: ${cam_device}"
            break
        fi
    done

    info "Writing ustreamer systemd service..."
    # Bind to 127.0.0.1 only — external access goes through nginx /webcam/ proxy
    # on the Mainsail port. ustreamer's native paths are /stream and /snapshot
    # (NOT the mjpg-streamer-style /?action=stream).
    sudo tee "$USTREAMER_UNIT" > /dev/null <<EOF
[Unit]
Description=ustreamer - Printer Camera
After=network.target

[Service]
User=mks
ExecStart=${ustreamer_bin} --device=${cam_device} --host=127.0.0.1 --port=${USTREAMER_PORT} --resolution=640x480 --desired-fps=15
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable "$USTREAMER_SERVICE"
    sudo systemctl restart "$USTREAMER_SERVICE" 2>/dev/null || \
        warn "ustreamer may not start until a camera is connected — check after reboot"
    ok "ustreamer service enabled (bound to 127.0.0.1:${USTREAMER_PORT})"

    # Add /webcam/ proxy to Mainsail nginx so browsers reach the stream via
    # port ${MAINSAIL_PORT} (same origin as Mainsail itself — no firewall or
    # CORS issues, and ustreamer stays localhost-only).
    if [ -f "$MAINSAIL_NGINX_SITE_AVAIL" ]; then
        if add_webcam_to_mainsail_nginx; then
            if sudo nginx -t >/dev/null 2>&1; then
                sudo systemctl reload nginx
                ok "nginx /webcam/ proxy added and reloaded"
            else
                warn "nginx config test failed after adding /webcam/ — check 'sudo nginx -t'"
            fi
        else
            warn "Failed to add /webcam/ proxy to Mainsail nginx config"
        fi
    else
        warn "Mainsail nginx config not found at ${MAINSAIL_NGINX_SITE_AVAIL}"
        warn "  → Install Mainsail first (option 6), then re-run camera setup"
    fi

    # Write/rewrite the [webcam printer] section in moonraker.conf using the
    # nginx proxy URL with ustreamer's native /stream and /snapshot paths.
    local moon_conf="${CONFIG_DIR}/moonraker.conf"
    if [ -f "$moon_conf" ]; then
        local printer_ip
        printer_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
        [ -z "$printer_ip" ] && printer_ip="<printer-ip>"
        # Strip any existing [webcam ...] sections (e.g. broken RC12 config)
        if grep -q '^\[webcam' "$moon_conf"; then
            awk '/^\[webcam/{skip=1;next} skip && /^\[/{skip=0} !skip{print}' \
                "$moon_conf" > "${moon_conf}.tmp" && mv "${moon_conf}.tmp" "$moon_conf"
        fi
        tee -a "$moon_conf" > /dev/null <<EOF

[webcam printer]
location: printer
service: mjpegstreamer-adaptive
enabled: True
target_fps: 15
target_fps_idle: 5
stream_url: http://${printer_ip}:${MAINSAIL_PORT}/webcam/stream
snapshot_url: http://${printer_ip}:${MAINSAIL_PORT}/webcam/snapshot
flip_horizontal: False
flip_vertical: False
rotation: 0
aspect_ratio: 4:3
EOF
        ok "Wrote [webcam printer] to moonraker.conf (http://${printer_ip}:${MAINSAIL_PORT}/webcam/)"
        if [ "$printer_ip" = "<printer-ip>" ]; then
            warn "Could not detect printer IP — update stream_url/snapshot_url in moonraker.conf"
        else
            info "If the printer IP changes, update stream_url/snapshot_url in moonraker.conf"
        fi
        sudo systemctl restart moonraker 2>/dev/null || \
            warn "Could not restart moonraker — restart manually for camera to register"
        purge_mainsail_ui_webcams
    else
        warn "moonraker.conf not found at ${moon_conf} — webcam not registered"
    fi

    touch "$CAMERA_MARKER"
    ok "Camera configured — hard-refresh Mainsail (Cmd/Ctrl+Shift+R) and check the camera panel"
}

uninstall_camera() {
    banner "Removing camera streaming"

    # Remove the nginx /webcam/ proxy first so nginx doesn't forward to a
    # service that's about to disappear.
    if [ -f "$MAINSAIL_NGINX_SITE_AVAIL" ] && \
       grep -q 'location /webcam/' "$MAINSAIL_NGINX_SITE_AVAIL" 2>/dev/null; then
        if remove_webcam_from_mainsail_nginx; then
            if sudo nginx -t >/dev/null 2>&1; then
                sudo systemctl reload nginx
                ok "Removed /webcam/ proxy from Mainsail nginx"
            else
                warn "nginx config test failed after removing /webcam/ — check 'sudo nginx -t'"
            fi
        fi
    fi

    sudo systemctl disable --now "$USTREAMER_SERVICE" 2>/dev/null || true
    if [ -f "$USTREAMER_UNIT" ]; then
        sudo rm -f "$USTREAMER_UNIT"
        sudo systemctl daemon-reload
        ok "Removed ${USTREAMER_UNIT}"
    fi
    if [ -f "$USTREAMER_PACKAGE_MARKER" ]; then
        info "Removing ustreamer package (installed by AIO for camera streaming)..."
        sudo apt-get remove --purge -y ustreamer 2>/dev/null || true
        sudo apt-get autoremove -y 2>/dev/null || true
        rm -f "$USTREAMER_PACKAGE_MARKER"
        ok "ustreamer package removed"
    else
        info "ustreamer package was pre-installed or not tracked — leaving it in place"
    fi

    # Remove [webcam ...] section from moonraker.conf
    local moon_conf="${CONFIG_DIR}/moonraker.conf"
    if [ -f "$moon_conf" ] && grep -q '^\[webcam' "$moon_conf"; then
        awk '/^\[webcam/{skip=1;next} skip && /^\[/{skip=0} !skip{print}' \
            "$moon_conf" > "${moon_conf}.tmp" && mv "${moon_conf}.tmp" "$moon_conf"
        ok "Removed [webcam] section from moonraker.conf"
        sudo systemctl restart moonraker 2>/dev/null || true
    fi

    rm -f "$CAMERA_MARKER"
    ok "Camera streaming removed"
}

verify_camera() {
    if ! camera_installed; then
        return 0
    fi
    if ! systemctl is-active --quiet "$USTREAMER_SERVICE"; then
        warn "${USTREAMER_SERVICE} not active — camera not streaming"
        warn "  → try: sudo systemctl start ${USTREAMER_SERVICE}"
        return 0
    fi
    # ustreamer is bound to 127.0.0.1 — check it serves a snapshot natively.
    if curl --fail --silent --max-time 3 \
        "http://127.0.0.1:${USTREAMER_PORT}/snapshot" -o /dev/null 2>&1; then
        ok "ustreamer serving on 127.0.0.1:${USTREAMER_PORT}"
    else
        warn "ustreamer running but /snapshot not responding"
        warn "  → check: sudo journalctl -u ${USTREAMER_SERVICE} -n 20"
        return 0
    fi
    # Check the nginx /webcam/ proxy reaches it.
    if curl --fail --silent --max-time 3 \
        "http://127.0.0.1:${MAINSAIL_PORT}/webcam/snapshot" -o /dev/null 2>&1; then
        ok "nginx /webcam/ proxy reachable on port ${MAINSAIL_PORT}"
    else
        warn "nginx /webcam/ proxy not responding on port ${MAINSAIL_PORT}"
        warn "  → check 'location /webcam/' exists in ${MAINSAIL_NGINX_SITE_AVAIL}"
    fi
}

menu_mainsail() {
    banner "Mainsail addon"
    if mainsail_installed; then
        info "Status: INSTALLED on port ${MAINSAIL_PORT}"
        info "Access via http://<printer-ip>:${MAINSAIL_PORT}"
        # Offer camera setup/migration before falling through to uninstall
        if camera_installed && ! camera_config_is_current; then
            warn "Camera config is from an older AIO release (broken — wrong URL paths,"
            warn "no nginx /webcam/ proxy). Mainsail's camera panel won't connect."
            if confirm "Migrate camera to RC13 format now?"; then
                preflight || { press_enter; return 1; }
                do_backup || { press_enter; return 1; }
                if install_camera; then
                    info "Run FIRMWARE_RESTART, then sudo reboot to finish applying changes."
                else
                    warn "Camera migration had problems (see above)"
                fi
                press_enter
                return
            fi
        elif ! camera_installed; then
            if confirm "Camera streaming not configured. Set it up now?"; then
                preflight || { press_enter; return 1; }
                do_backup || { press_enter; return 1; }
                if install_camera; then
                    info "Run FIRMWARE_RESTART, then sudo reboot to finish applying changes."
                else
                    warn "Camera setup had problems (see above)"
                fi
                press_enter
                return
            fi
        fi
        if confirm "Uninstall Mainsail?"; then
            uninstall_mainsail
        fi
    else
        info "Status: not installed"
        info "Mainsail is a web UI for Klipper/Moonraker. Installs to"
        info "${MAINSAIL_DIR} and listens on port ${MAINSAIL_PORT}."
        info "Qidi's stock UI on port 80 is not affected."
        if confirm "Install Mainsail now?"; then
            preflight || { press_enter; return 1; }
            do_backup || { press_enter; return 1; }
            if install_mainsail; then
                info "Run FIRMWARE_RESTART, then sudo reboot to finish applying changes."
            else
                warn "Setup had problems (see above)"
            fi
        fi
    fi
    press_enter
}

# Locate mmu_parameters.cfg at runtime - Happy Hare puts it directly
# under ${CONFIG_DIR}/mmu/ in current versions, but older installs and
# the original handoff doc reference ${CONFIG_DIR}/mmu/base/. Check both.
find_mmu_params() {
    for p in "${CONFIG_DIR}/mmu/mmu_parameters.cfg" \
             "${CONFIG_DIR}/mmu/base/mmu_parameters.cfg"; do
        if [ -f "$p" ]; then
            echo "$p"
            return 0
        fi
    done
    return 1
}

# Reverse the ## AIO_DISABLED: comments that fix_known_klipper_conflicts()
# applied to Qidi stock files (box1.cfg, gcode_macro.cfg) when BunnyBox was
# installed. Called during uninstall so Qidi's native T0-T3/UNLOAD_T0-T3 and
# EXTRUSION_AND_FLUSH macros are active again once Happy Hare is removed.
restore_aio_disabled_macros() {
    local changed=0
    for cfg in "${CONFIG_DIR}/box1.cfg" "${CONFIG_DIR}/gcode_macro.cfg"; do
        if [ -f "$cfg" ] && grep -q '^## AIO_DISABLED: ' "$cfg" 2>/dev/null; then
            sed -i 's/^## AIO_DISABLED: //' "$cfg"
            ok "Restored AIO_DISABLED macros in $(basename "$cfg")"
            changed=1
        fi
    done
    [ "$changed" -eq 0 ] && info "No AIO_DISABLED macros to restore"
}

# Exhaustively remove every Happy Hare / BunnyBox footprint we know
# about, regardless of whether the upstream uninstallers ran. Called
# from revert_to_backup() and uninstall_bunnybox().
purge_happy_hare_all() {
    banner "Purging all Happy Hare / BunnyBox artifacts"

    # Run upstream uninstallers if they're present. Don't trust their
    # exit codes - we'll force-clean afterwards regardless.
    if [ -f "${HAPPY_HARE_DIR}/install.sh" ]; then
        info "Running Happy Hare uninstaller (-d)..."
        sudo bash "${HAPPY_HARE_DIR}/install.sh" -d 2>/dev/null || true
    fi

    # Happy Hare source tree + config dirs (incl. its own dated backups)
    info "Removing Happy Hare source tree: ${HAPPY_HARE_DIR}"
    sudo rm -rf "$HAPPY_HARE_DIR"
    if [ -d "$HAPPY_HARE_DIR" ]; then
        err "Failed to remove ${HAPPY_HARE_DIR} — trying alternate approach"
        sudo find "$HAPPY_HARE_DIR" -delete 2>/dev/null || true
    fi

    info "Removing MMU config: ${CONFIG_DIR}/mmu"
    sudo rm -rf "${CONFIG_DIR}/mmu"
    sudo rm -rf "${CONFIG_DIR}"/mmu-* 2>/dev/null || true
    sudo rm -rf "${CONFIG_DIR}"/mmu_* 2>/dev/null || true
    sudo rm -rf "${CONFIG_DIR}"/mmu[0-9]* 2>/dev/null || true

    # Timestamped backup directories Happy Hare and BunnyBox drop into the
    # config root (backup_hh_<ts>, backup_revert_<ts>). These pile up across
    # repeated installs and are not restored by any uninstall flow.
    find "$CONFIG_DIR" -maxdepth 1 -type d \
        \( -name 'backup_hh_*' -o -name 'backup_revert_*' -o -name 'backup_mmu_*' \
           -o -name 'backup_bunnybox_*' \) \
        -exec sudo rm -rf {} + 2>/dev/null || true

    # BunnyBox's KAMP/ subdirectory. We install KAMP files at the config
    # root (PR #8); BunnyBox's KAMP/ copy is no longer referenced.
    sudo rm -rf "${CONFIG_DIR}/KAMP"

    # Config files Happy Hare / BunnyBox may have written at config root
    rm -f "${CONFIG_DIR}/bunnybox_macros.cfg"
    rm -f "${CONFIG_DIR}/box_drying.cfg"
    rm -f "${CONFIG_DIR}/mmu_parameters.cfg"
    rm -f "${CONFIG_DIR}/mmu_macro_vars.cfg"
    rm -f "${CONFIG_DIR}/mmu_hardware.cfg"
    rm -f "${CONFIG_DIR}/mmu.cfg"
    find "$CONFIG_DIR" -maxdepth 1 -name 'mmu*.cfg' -type f -delete 2>/dev/null || true

    # Klipper + Moonraker extras.
    # Happy Hare v2 placed individual files at the extras root; v3 installs a
    # package directory (extras/mmu/) and adds helper symlinks alongside it
    # (mmu_espooler.py, mmu_servo.py, mmu_led_effect.py). Both sets are
    # removed here. Leaving them causes the mmu package to load at Klipper
    # startup and register gcode commands (CLEAR_TOOLCHANGE_STATE, etc.) that
    # box_extras.so also registers → "already registered" crash.
    info "Removing Klipper extras: ${HOME}/klipper/klippy/extras/mmu"
    sudo rm -rf "${HOME}/klipper/klippy/extras/mmu"
    for f in mmu.py mmu_machine.py mmu_leds.py mmu_sensors.py mmu_encoder.py; do
        sudo rm -f "${HOME}/klipper/klippy/extras/${f}"
    done
    sudo find "${HOME}/klipper/klippy/extras" -maxdepth 1 \
        \( -name 'mmu_*.py' -o -name 'mmu_*.pyc' \) \
        -delete 2>/dev/null || true
    sudo find "${HOME}/klipper/klippy/extras" -path '*/__pycache__/mmu*' \
        -delete 2>/dev/null || true

    info "Removing Moonraker component: mmu_server.py"
    sudo rm -f "${HOME}/moonraker/moonraker/components/mmu_server.py"

    # KAMP subdir installed by the AIO BunnyBox / JustFasterPrinter flows.
    # Removing it lets fix_printer_cfg_after_uninstall() comment out the
    # [include KAMP/KAMP_Settings.cfg] line so Klipper can start cleanly.
    rm -rf "${CONFIG_DIR}/KAMP"

    # Moonraker update_manager / mmu sections - delete the section and
    # its body up to the next section header or EOF.
    local moon_conf="${CONFIG_DIR}/moonraker.conf"
    if [ -f "$moon_conf" ] && grep -qE '^\[(update_manager (mmu|happy_hare|bunnybox|happyhare)|mmu_server)\]' "$moon_conf" 2>/dev/null; then
        cp "$moon_conf" "${moon_conf}.aio-bak"
        sed -i '/^\[\(update_manager \(mmu\|happy_hare\|bunnybox\|happyhare\)\|mmu_server\)\]/,/^\[/{/^\[/!d;}' "$moon_conf"
        sed -i '/^\[update_manager \(mmu\|happy_hare\|bunnybox\|happyhare\)\]$/d' "$moon_conf"
        sed -i '/^\[mmu_server\]$/d' "$moon_conf"
        ok "Cleaned Happy Hare sections from moonraker.conf"
    fi

    restore_aio_disabled_macros

    # Final verification — if anything critical survived, report it
    local residue=0
    [ -d "$HAPPY_HARE_DIR" ]                          && { warn "RESIDUE: ${HAPPY_HARE_DIR} still exists"; residue=1; }
    [ -d "${HOME}/klipper/klippy/extras/mmu" ]        && { warn "RESIDUE: extras/mmu/ still exists"; residue=1; }
    [ -d "${CONFIG_DIR}/mmu" ]                        && { warn "RESIDUE: config/mmu/ still exists"; residue=1; }
    if [ $residue -eq 1 ]; then
        warn "Some Happy Hare artifacts survived purge — check output above"
    else
        ok "Happy Hare / BunnyBox purge verified clean"
    fi
}

# Comment out [include ...] lines in printer.cfg whose target files no longer
# exist so Klipper can start cleanly after uninstall.
fix_printer_cfg_after_uninstall() {
    local pcfg="${CONFIG_DIR}/printer.cfg"
    [ -f "$pcfg" ] || return 0

    banner "Fixing printer.cfg broken includes"
    local changed=0

    for f in bunnybox_macros.cfg box_drying.cfg idle_fan_shutdown.cfg; do
        if [ ! -f "${CONFIG_DIR}/${f}" ] && \
           grep -q "^\[include ${f}\]" "$pcfg" 2>/dev/null; then
            sed -i "s/^\[include ${f}\]/# AIO: file missing  [include ${f}]/" "$pcfg"
            ok "Commented out missing include: ${f}"
            changed=1
        fi
    done
    # KAMP lives in the KAMP/ subdir — check for the subdir-prefixed include form.
    for f in KAMP/KAMP_Settings.cfg KAMP/Adaptive_Meshing.cfg KAMP/Line_Purge.cfg KAMP/Smart_Park.cfg; do
        if [ ! -f "${CONFIG_DIR}/${f}" ] && \
           grep -q "^\[include ${f}\]" "$pcfg" 2>/dev/null; then
            sed -i "s/^\[include ${f}\]/# AIO: file missing  [include ${f}]/" "$pcfg"
            ok "Commented out missing include: ${f}"
            changed=1
        fi
    done

    # mmu/ wildcard — comment out if the mmu/ dir is gone
    if [ ! -d "${CONFIG_DIR}/mmu" ] && \
       grep -q '^\[include mmu/' "$pcfg" 2>/dev/null; then
        sed -i 's/^\[include mmu\/[^]]*\]/# AIO: file missing  &/' "$pcfg"
        ok "Commented out missing include: mmu/*.cfg"
        changed=1
    fi

    if [ "$changed" -eq 1 ]; then
        ok "printer.cfg patched — Klipper can now start without the removed files"
    else
        info "printer.cfg: no dangling includes found"
    fi
}

# ---------- ANSI colors ----------------------------------------------
if [ -t 1 ]; then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_RED=$'\033[31m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_CYAN=$'\033[36m'
    C_MAGENTA=$'\033[35m'
else
    C_RESET=''; C_BOLD=''; C_RED=''; C_GREEN=''; C_YELLOW=''; C_CYAN=''; C_MAGENTA=''
fi

ok()    { printf '%s[OK]%s   %s\n'    "$C_GREEN"  "$C_RESET" "$*"; }
info()  { printf '%s[INFO]%s %s\n'    "$C_CYAN"   "$C_RESET" "$*"; }
warn()  { printf '%s[WARN]%s %s\n'    "$C_YELLOW" "$C_RESET" "$*"; }
err()   { printf '%s[ERR]%s  %s\n'    "$C_RED"    "$C_RESET" "$*" >&2; }

banner() {
    echo ""
    printf '%s=================================================================%s\n' "$C_BOLD" "$C_RESET"
    printf '%s  %s%s\n' "$C_BOLD" "$1" "$C_RESET"
    printf '%s=================================================================%s\n' "$C_BOLD" "$C_RESET"
}

press_enter() {
    echo ""
    printf '%sPress Enter to return to the menu...%s' "$C_CYAN" "$C_RESET"
    read -r _ </dev/tty || true
}

run_remote_script() {
    local url="$1"
    shift
    local tmp
    tmp=$(mktemp /tmp/aio_remote_script.XXXXXX) || { err "mktemp failed"; return 1; }
    fetch "$url" "$tmp" || { rm -f "$tmp"; return 1; }
    chmod +x "$tmp"
    "$tmp" "$@"
    local rc=$?
    rm -f "$tmp"
    return $rc
}

run_remote_script_as_root() {
    local url="$1"
    shift
    local tmp
    tmp=$(mktemp /tmp/aio_remote_script.XXXXXX) || { err "mktemp failed"; return 1; }
    fetch "$url" "$tmp" || { rm -f "$tmp"; return 1; }
    sudo sh "$tmp" "$@"
    local rc=$?
    rm -f "$tmp"
    return $rc
}

url_exists() {
    local url="$1"
    curl --fail --silent --location --head --max-time 10 "$url" >/dev/null 2>&1
}

happier_hare_zip_url() {
    if [ -n "${HAPPIER_HARE_ZIP_URL:-}" ]; then
        printf '%s\n' "$HAPPIER_HARE_ZIP_URL"
        return 0
    fi
    if [ -f "$HAPPIER_HARE_LOCAL_ZIP" ]; then
        printf '%s\n' "$HAPPIER_HARE_LOCAL_ZIP"
        return 0
    fi
    if url_exists "$HAPPIER_HARE_RELEASE_ZIP"; then
        printf '%s\n' "$HAPPIER_HARE_RELEASE_ZIP"
        return 0
    fi
    return 1
}

# ---------- safety: refuse root --------------------------------------
if [ "$(id -u)" -eq 0 ]; then
    err "Do not run this script as root."
    err "Run as the printer user (usually 'mks'). It will sudo only where needed."
    exit 1
fi

# ---------- helpers --------------------------------------------------
fetch() {
    local url="$1"
    local dest="$2"
    local dest_dir
    dest_dir=$(dirname "$dest")

    # Ensure parent directory exists (try user first, then sudo).
    if [ ! -d "$dest_dir" ]; then
        mkdir -p "$dest_dir" 2>/dev/null || sudo mkdir -p "$dest_dir" 2>/dev/null
    fi

    # Download to /tmp first so the network step is isolated from the
    # write step. Lets us retry the install with sudo when the destination
    # is owned by root from a previous install (e.g. BunnyBox creates
    # KAMP_Settings.cfg as root, then curl --output to it gets EACCES).
    local tmp
    tmp=$(mktemp /tmp/aio_fetch.XXXXXX) || { err "mktemp failed"; return 1; }
    if ! curl --fail --silent --show-error --location "$url" --output "$tmp"; then
        rm -f "$tmp"
        err "Download failed: $url"
        return 1
    fi
    if [ ! -s "$tmp" ]; then
        rm -f "$tmp"
        err "Downloaded file is empty (URL: $url)"
        return 1
    fi

    # Try installing as the current user; fall back to sudo if the
    # destination is root-owned. `install` handles mode + atomic replace.
    if install -m 0644 "$tmp" "$dest" 2>/dev/null || \
       sudo install -m 0644 "$tmp" "$dest" 2>/dev/null; then
        rm -f "$tmp"
        return 0
    fi

    rm -f "$tmp"
    err "Failed to write $dest (tried as user and via sudo)"
    return 1
}

bunnybox_installed() {
    # Look for mmu_parameters.cfg anywhere under ${CONFIG_DIR}/mmu/ so
    # we work with both flat (current) and base/ (legacy) layouts.
    [ -d "${CONFIG_DIR}/mmu" ] && \
    [ -n "$(find "${CONFIG_DIR}/mmu" -maxdepth 3 -name 'mmu_parameters.cfg' \
            -print -quit 2>/dev/null)" ]
}

# Scan every path the BunnyBox installer's own detection logic looks at,
# plus a few extras. Returns 0 if any artifact is present (and prints
# what was found), 1 if the slate is truly clean.
detect_bunnybox_artifacts() {
    local found=0
    local paths=(
        "$HAPPY_HARE_DIR"
        "${CONFIG_DIR}/mmu"
        "${CONFIG_DIR}/bunnybox_macros.cfg"
        "${CONFIG_DIR}/box_drying.cfg"
        "${HOME}/klipper/klippy/extras/mmu.py"
        "${HOME}/klipper/klippy/extras/mmu_machine.py"
        "${HOME}/klipper/klippy/extras/mmu_leds.py"
        "${HOME}/moonraker/moonraker/components/mmu_server.py"
    )
    for p in "${paths[@]}"; do
        if [ -e "$p" ]; then
            warn "Stale artifact present: $p"
            found=1
        fi
    done
    return $((1 - found))
}

helixscreen_installed() {
    [ -d "$HELIX_DIR" ] || systemctl is-enabled helixscreen &>/dev/null
}

klipperscreen_installed() {
    systemctl is-enabled --quiet "$KLIPPERSCREEN_SERVICE" 2>/dev/null || \
    [ -d "$KLIPPERSCREEN_DIR" ] || \
    [ -d "$KLIPPERSCREEN_VENV" ] || \
    [ -f /etc/systemd/system/KlipperScreen.service ] || \
    [ -d /etc/systemd/system/KlipperScreen.service.d ]
}

# Mask the stock Qidi display services so KlipperScreen can own the screen.
# The upstream KlipperScreen-install.sh handles X server setup (xinit),
# service creation, and display configuration — we just clear the way.
prepare_display_for_klipperscreen() {
    banner "Preparing display for KlipperScreen"
    sudo systemctl stop    makerbase-client       2>/dev/null || true
    sudo systemctl disable makerbase-client       2>/dev/null || true
    sudo systemctl mask    makerbase-client       2>/dev/null || true
    sudo systemctl stop    helixscreen            2>/dev/null || true
    sudo systemctl disable helixscreen            2>/dev/null || true
    sudo systemctl mask    helixscreen            2>/dev/null || true
    ok "Stock display services masked — KlipperScreen owns the screen"
}

uninstall_klipperscreen() {
    banner "Uninstalling KlipperScreen"
    sudo systemctl disable --now "$KLIPPERSCREEN_SERVICE" 2>/dev/null || true
    sudo systemctl mask    "$KLIPPERSCREEN_SERVICE" 2>/dev/null || true
    sudo rm -f /etc/systemd/system/KlipperScreen.service
    sudo rm -rf /etc/systemd/system/KlipperScreen.service.d
    sudo systemctl daemon-reload 2>/dev/null || true
    rm -rf "$KLIPPERSCREEN_DIR" 2>/dev/null || true
    rm -rf "$KLIPPERSCREEN_VENV" 2>/dev/null || true
    if restore_stock_display_services; then
        ok "KlipperScreen uninstalled, stock display services re-enabled"
    else
        warn "KlipperScreen uninstalled, but stock display services need attention"
    fi
}

verify_klipperscreen() {
    klipperscreen_installed || return 0
    if systemctl is-active --quiet "$KLIPPERSCREEN_SERVICE"; then
        ok "KlipperScreen.service is active"
    else
        warn "KlipperScreen.service is not active"
        warn "  → check: sudo journalctl -u ${KLIPPERSCREEN_SERVICE} -n 50"
    fi
}

preflight() {
    banner "Pre-flight checks"

    if ! curl --fail --silent --head --max-time 10 \
         'https://raw.githubusercontent.com' >/dev/null 2>&1; then
        err "Cannot reach raw.githubusercontent.com"
        err "Check your network connection and try again."
        return 1
    fi
    ok "Network connectivity"

    if [ ! -d "$CONFIG_DIR" ]; then
        err "Config directory not found: $CONFIG_DIR"
        err "Is this a Qidi Q2 running Klipper?"
        return 1
    fi
    ok "Config directory present"

    if [ -f "${CONFIG_DIR}/printer.cfg" ]; then
        if grep -q 'enable_force_move.*True' "${CONFIG_DIR}/printer.cfg" 2>/dev/null; then
            ok "force_move enabled in printer.cfg"
        else
            warn "force_move not found in printer.cfg (spool rotation may not work)"
        fi
    fi

    ok "Pre-flight complete"
    return 0
}

aio_state_dir() {
    printf '%s\n' "${BACKUP_ROOT}/_AIO_STATE"
}

aio_preexisting_paths_file() {
    printf '%s\n' "$(aio_state_dir)/preexisting_paths"
}

capture_first_run_state() {
    local state_dir preexisting path
    state_dir=$(aio_state_dir)
    preexisting=$(aio_preexisting_paths_file)
    if [ -f "$preexisting" ]; then
        return 0
    fi

    mkdir -p "$state_dir" || {
        warn "Could not create AIO state manifest directory"
        return 0
    }
    : > "$preexisting" || {
        warn "Could not write AIO state manifest"
        return 0
    }

    for path in \
        "$HAPPY_HARE_DIR" \
        "$HELIX_DIR" \
        "$HELIX_PRINT_DIR" \
        "$KLIPPERSCREEN_DIR" \
        "$KLIPPERSCREEN_VENV" \
        "$KIAUH_DIR" \
        "$KIAUH_BACKUPS_DIR" \
        "$KIAUH_UPPER_DIR" \
        "$KIAUH_UPPER_BACKUPS_DIR" \
        "$MAINSAIL_DIR" \
        /opt/helixscreen \
        /var/lib/helixscreen \
        /var/log/helixscreen \
        "${HOME}/.helixscreen" \
        /root/.helixscreen; do
        if [ -e "$path" ]; then
            printf '%s\n' "$path" >> "$preexisting"
        fi
    done
    ok "First-run runtime state manifest saved to ${state_dir}"
}

path_was_preexisting() {
    local path="$1"
    local preexisting
    preexisting=$(aio_preexisting_paths_file)
    [ -f "$preexisting" ] && grep -Fxq "$path" "$preexisting"
}

should_remove_aio_path() {
    local path="$1"
    [ -e "$path" ] || return 1
    if path_was_preexisting "$path"; then
        info "Keeping pre-existing path: $path"
        return 1
    fi
    return 0
}

do_backup() {
    banner "Backing up current configs"
    BACKUP_DIR="${BACKUP_ROOT}/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    if ! rsync -a "${CONFIG_DIR}/" "${BACKUP_DIR}/"; then
        err "Backup failed"
        return 1
    fi
    ok "Backup written to ${BACKUP_DIR}"

    # One-time permanent snapshot of the very first observed state. This
    # is what "Revert to Backup" should restore - assuming the user ran
    # the AIO before tinkering, it's their true stock. Once written, it
    # is never overwritten.
    if [ ! -d "${BACKUP_ROOT}/_FIRST_STOCK" ]; then
        capture_first_run_state
        mkdir -p "${BACKUP_ROOT}/_FIRST_STOCK"
        if rsync -a "${CONFIG_DIR}/" "${BACKUP_ROOT}/_FIRST_STOCK/"; then
            ok "First-run stock snapshot saved to ${BACKUP_ROOT}/_FIRST_STOCK"
        else
            warn "Could not write _FIRST_STOCK snapshot (revert will fall back to oldest timestamped backup)"
        fi
    fi
    return 0
}

ensure_repair_backup() {
    if [ "${AIO_REPAIR_BACKUP_DONE:-false}" = true ]; then
        return 0
    fi
    info "Verifier repairs can edit Klipper configs; creating a safety backup first."
    do_backup || return 1
    AIO_REPAIR_BACKUP_DONE=true
    return 0
}

# ---------- uninstall primitives -------------------------------------
uninstall_bunnybox() {
    banner "Uninstalling BunnyBox / Happy Hare"
    purge_happy_hare_all
    fix_printer_cfg_after_uninstall
    ok "BunnyBox / Happy Hare uninstalled"
    info "Backups: ${BACKUP_ROOT}/"
}

cleanup_aio_runtime_artifacts() {
    banner "Cleaning AIO runtime artifacts"

    uninstall_qidi_box_write

    for d in \
        "$HAPPY_HARE_DIR" \
        "$HELIX_DIR" \
        "$HELIX_PRINT_DIR" \
        "$KLIPPERSCREEN_DIR" \
        "$KLIPPERSCREEN_VENV" \
        "$KIAUH_DIR" \
        "$KIAUH_BACKUPS_DIR" \
        "$KIAUH_UPPER_DIR" \
        "$KIAUH_UPPER_BACKUPS_DIR" \
        /opt/helixscreen \
        /var/lib/helixscreen \
        /var/log/helixscreen \
        "${HOME}/.helixscreen" \
        /root/.helixscreen; do
        if should_remove_aio_path "$d"; then
            sudo rm -rf "$d" && ok "Removed $d" || warn "Could not remove $d"
        fi
    done

    sudo rm -f /etc/systemd/system/KlipperScreen.service
    sudo rm -rf /etc/systemd/system/KlipperScreen.service.d
    sudo rm -f /etc/systemd/system/helixscreen.service
    sudo rm -f /etc/systemd/system/helixscreen-update.path
    sudo rm -f /etc/systemd/system/helixscreen-update.service
    sudo rm -f /etc/udev/rules.d/99-helixscreen-backlight.rules
    sudo rm -f /etc/polkit-1/localauthority/50-local.d/helixscreen-network.pkla
    sudo rm -f /etc/polkit-1/rules.d/49-helixscreen-network.rules
    sudo rm -f /etc/polkit-1/rules.d/50-helixscreen-network.rules
    sudo systemctl daemon-reload 2>/dev/null || true
}

cleanup_aio_config_artifacts() {
    banner "Cleaning AIO config artifacts"

    uninstall_idle_fan_shutdown
    cleanup_aio_config_residue
    fix_printer_cfg_after_uninstall
}

cleanup_aio_config_residue() {
    banner "Cleaning AIO config residue"

    for f in \
        bunnybox_macros.cfg \
        box_drying.cfg \
        idle_fan_shutdown.cfg \
        KlipperScreen.conf \
        KAMP_Settings.cfg \
        KAMP_settings.cfg \
        Adaptive_Meshing.cfg \
        Adaptive_Mesh.cfg \
        Line_Purge.cfg \
        Smart_Park.cfg \
        mmu_cut_tip.cfg \
        mmu_form_tip.cfg \
        mmu_heater_vent.cfg \
        mmu_leds.cfg \
        mmu_purge.cfg \
        mmu_sequence.cfg \
        mmu_software.cfg \
        mmu_state.cfg \
        mmu_parameters.cfg \
        mmu_macro_vars.cfg \
        mmu_hardware.cfg \
        mmu_vars.cfg \
        mmu.cfg; do
        if [ -e "${CONFIG_DIR}/${f}" ]; then
            rm -f "${CONFIG_DIR}/${f}"
            ok "Removed ${CONFIG_DIR}/${f}"
        fi
    done

    while IFS= read -r -d '' f; do
        rm -f "$f" && ok "Removed $f"
    done < <(
        find "$CONFIG_DIR" -maxdepth 1 -type f \
            \( -name 'mmu*.cfg' -o -name 'mmu_klipperscreen.*' \
               -o -name 'moonraker.conf.aio-bak' \
               -o -name 'moonraker.conf.bak.helixscreen*' \) \
            -print0 2>/dev/null
    )

    while IFS= read -r -d '' d; do
        sudo rm -rf "$d" && ok "Removed $d" || warn "Could not remove $d"
    done < <(
        find "$CONFIG_DIR" -maxdepth 1 -type d \
            \( -name 'mmu' -o -name 'mmu-*' -o -name 'mmu_*' -o -name 'mmu[0-9]*' \
               -o -name 'backup_hh_*' -o -name 'backup_revert_*' -o -name 'backup_mmu_*' \
               -o -name 'backup_bunnybox_*' \) \
            -print0 2>/dev/null
    )

    for d in "${CONFIG_DIR}/KAMP" "${CONFIG_DIR}/helixscreen"; do
        if [ -e "$d" ]; then
            sudo rm -rf "$d" && ok "Removed $d" || warn "Could not remove $d"
        fi
    done
}

cleanup_aio_install_artifacts() {
    cleanup_aio_runtime_artifacts
    cleanup_aio_config_artifacts
}

restore_stock_display_services() {
    info "Re-enabling Qidi stock display services..."

    # HelixScreen owns the framebuffer directly, so installs mask the stock
    # display stack. Revert must undo both service masking and the boot target.
    sudo systemctl daemon-reload                     2>/dev/null || true
    sudo systemctl set-default graphical.target      2>/dev/null || true
    sudo systemctl reset-failed lightdm makerbase-client display-manager.service \
                                                   2>/dev/null || true

    sudo systemctl unmask  lightdm                   2>/dev/null || true
    sudo systemctl unmask  display-manager.service   2>/dev/null || true
    sudo systemctl unmask  makerbase-client          2>/dev/null || true
    sudo systemctl enable  lightdm                   2>/dev/null || true
    sudo systemctl enable  makerbase-client          2>/dev/null || true

    sudo systemctl stop helixscreen KlipperScreen    2>/dev/null || true
    sudo systemctl start lightdm                     2>/dev/null || true
    if ! systemctl is-active --quiet lightdm 2>/dev/null; then
        sudo systemctl start display-manager.service 2>/dev/null || true
    fi
    sleep 2
    sudo systemctl start makerbase-client            2>/dev/null || true

    if systemctl is-active --quiet lightdm 2>/dev/null && \
       systemctl is-active --quiet makerbase-client 2>/dev/null; then
        ok "Qidi stock display services are active"
    else
        warn "Qidi stock display services were requested but one is not active"
        warn "Run Option 8 or check: systemctl status lightdm makerbase-client"
        if ! systemctl is-active --quiet lightdm 2>/dev/null; then
            show_systemd_journal_tail lightdm "LightDM"
        fi
        if ! systemctl is-active --quiet makerbase-client 2>/dev/null; then
            show_systemd_journal_tail makerbase-client "Makerbase stock UI"
        fi
        return 1
    fi
}

remove_backup_root_after_revert() {
    [ -e "$BACKUP_ROOT" ] || { ok "${BACKUP_ROOT}/ already absent"; return 0; }

    banner "Removing AIO backup root"
    local moved
    moved="${BACKUP_ROOT}.revert-delete.$(date +%Y%m%d_%H%M%S)"

    if sudo mv "$BACKUP_ROOT" "$moved" 2>/dev/null; then
        sudo rm -rf "$moved"
    else
        warn "Could not move ${BACKUP_ROOT}; trying direct removal"
        sudo rm -rf "$BACKUP_ROOT"
    fi

    if [ -e "$BACKUP_ROOT" ]; then
        warn "Could not remove ${BACKUP_ROOT}/"
        return 1
    fi
    ok "Removed ${BACKUP_ROOT}/ after successful stock restore"
}

# Switch the Q2's active display from the stock Qidi services
# (lightdm + makerbase-client) to HelixScreen. Inverse of the
# unmask/enable/restart block in uninstall_helixscreen().
#
# Why this exists: HelixScreen's upstream installer was written for the
# Artillery M1 Pro and doesn't know about Qidi-specific display services.
# Without this swap, lightdm + makerbase-client keep the stock UI on the
# physical screen and HelixScreen never appears, even though the package
# was installed correctly.
switch_display_to_helixscreen() {
    banner "Switching active display: stock Qidi → HelixScreen"
    if [ ! -f /etc/systemd/system/helixscreen.service ]; then
        warn "helixscreen.service not installed — display swap skipped"
        warn "HelixScreen package may not have installed correctly. Check output above."
        return 1
    fi
    sudo systemctl stop    makerbase-client  2>/dev/null || true
    sudo systemctl disable makerbase-client  2>/dev/null || true
    sudo systemctl mask    makerbase-client  2>/dev/null || true
    sudo systemctl stop    lightdm           2>/dev/null || true
    sudo systemctl disable lightdm           2>/dev/null || true
    sudo systemctl mask    lightdm           2>/dev/null || true
    sudo systemctl daemon-reload             2>/dev/null || true
    sudo systemctl unmask  helixscreen       2>/dev/null || true
    sudo systemctl enable  helixscreen       2>/dev/null || true
    sudo systemctl restart helixscreen       2>/dev/null || true
    if systemctl is-active --quiet helixscreen; then
        ok "HelixScreen is active on the display"
    else
        warn "helixscreen.service is enabled but not active"
        warn "  → check: systemctl status helixscreen"
    fi
}

uninstall_helixscreen() {
    banner "Uninstalling HelixScreen"

    # Remove our Qidi Box write env override before touching the service.
    uninstall_qidi_box_write

    # Try HelixScreen's own remove path first so its installer can do
    # whatever cleanup it expects. The installer flag is --uninstall
    # (not --remove). Fall back to manual systemd teardown if that fails.
    if curl --fail --silent --head --max-time 5 "$HELIX_UNINSTALLER" >/dev/null 2>&1; then
        info "Running official HelixScreen uninstaller..."
        run_remote_script_as_root "$HELIX_UNINSTALLER" --uninstall || \
            warn "HelixScreen uninstaller returned non-zero"
    fi

    sudo systemctl stop helixscreen     2>/dev/null || true
    sudo systemctl disable helixscreen  2>/dev/null || true
    sudo systemctl mask helixscreen     2>/dev/null || true
    sudo rm -f /etc/systemd/system/helixscreen.service
    sudo systemctl daemon-reload        2>/dev/null || true
    sudo rm -rf "$HELIX_DIR"

    # HelixScreen also drops a config-root state dir and a moonraker.conf
    # backup. Clean both — they pile up across reinstalls and confuse
    # post-uninstall diffs.
    sudo rm -rf "${CONFIG_DIR}/helixscreen"
    rm -f "${CONFIG_DIR}/moonraker.conf.bak.helixscreen"

    # Re-enable the Qidi stock display services. Without this, removing
    # HelixScreen leaves the printer with NO running display - the user
    # is forced to recover by hand. Done unconditionally even if the
    # service files look healthy; unmask+enable+restart is idempotent.
    if restore_stock_display_services; then
        ok "HelixScreen uninstalled, stock display services re-enabled"
    else
        warn "HelixScreen uninstalled, but stock display services need attention"
    fi
}

# Full upstream-style revert: re-enables lightdm + makerbase-client and
# restores from /home/mks/mudstockbackups via rsync (mirrors Camden-Winder
# uninstall.sh).
revert_to_backup() {
    banner "Revert to Backup (full stock restore)"

    # Delegate to the dedicated uninstall functions so revert picks up every
    # cleanup step they do (qidi-box-write systemd drop-in, helixscreen state
    # dir, moonraker bak, restore_aio_disabled_macros, fix_printer_cfg_after_uninstall,
    # etc.) without duplicating logic here.
    if klipperscreen_installed; then
        uninstall_klipperscreen
    else
        info "KlipperScreen not present, skipping"
    fi

    if helixscreen_installed; then
        uninstall_helixscreen
    else
        info "HelixScreen not present, skipping"
    fi

    if [ -d "$HAPPY_HARE_DIR" ] || bunnybox_installed; then
        uninstall_bunnybox
    else
        info "BunnyBox / Happy Hare not present, skipping"
    fi

    cleanup_aio_install_artifacts

    info "Restoring configs from ${BACKUP_ROOT}..."
    local restore_ok=false
    local restore_can_delete=false
    if [ -d "$BACKUP_ROOT" ]; then
        # Prefer the one-time _FIRST_STOCK snapshot (closest to factory).
        # Fall back to the OLDEST timestamped backup - the first one
        # written is closer to stock than the newest, which captured
        # whatever broken state was on disk right before the last action.
        local src=""
        if [ -d "${BACKUP_ROOT}/_FIRST_STOCK" ] && \
            [ -n "$(ls -A "${BACKUP_ROOT}/_FIRST_STOCK" 2>/dev/null)" ]; then
            src="${BACKUP_ROOT}/_FIRST_STOCK"
            restore_can_delete=true
            info "Using first-run stock snapshot: $src"
        else
            local oldest
            oldest=$(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d \
                     -not -name '_FIRST_STOCK' 2>/dev/null | sort | head -n 1)
            if [ -n "$oldest" ]; then
                src="$oldest"
                restore_can_delete=true
                warn "_FIRST_STOCK missing - falling back to OLDEST timestamped backup"
                info "Restoring from: $src"
            else
                src="$BACKUP_ROOT"
                warn "No timestamped backups found - restoring from flat ${BACKUP_ROOT}/"
            fi
        fi
        local rsync_args=(-a --no-owner --no-group)
        if [ "$restore_can_delete" = true ]; then
            rsync_args+=(--delete)
        fi
        if rsync "${rsync_args[@]}" "${src}/" "${CONFIG_DIR}/"; then
            ok "Config restore complete"
            restore_ok=true
        else
            err "Restore failed"
        fi
    else
        warn "No ${BACKUP_ROOT} folder found - nothing to restore"
    fi

    # Post-rsync cleanup: even an old "stock" snapshot may have been taken
    # after a partial AIO/Happy Hare install, so always scrub known config
    # residue. Only run the printer.cfg repair path for imprecise fallback
    # restores, where orphan include cleanup may be required.
    if [ "$restore_ok" = true ]; then
        cleanup_aio_runtime_artifacts
        if [ "$restore_can_delete" = true ]; then
            cleanup_aio_config_residue
        else
            cleanup_aio_config_artifacts
        fi
        if [ "$restore_can_delete" != true ]; then
            # Re-clean moonraker.conf Happy Hare sections
            local moon_conf="${CONFIG_DIR}/moonraker.conf"
            if [ -f "$moon_conf" ] && grep -qE '^\[(update_manager (mmu|happy_hare|bunnybox|happyhare)|mmu_server)\]' "$moon_conf" 2>/dev/null; then
                sed -i '/^\[\(update_manager \(mmu\|happy_hare\|bunnybox\|happyhare\)\|mmu_server\)\]/,/^\[/{/^\[/!d;}' "$moon_conf"
                sed -i '/^\[update_manager \(mmu\|happy_hare\|bunnybox\|happyhare\)\]$/d' "$moon_conf"
                sed -i '/^\[mmu_server\]$/d' "$moon_conf"
                ok "Post-rsync: cleaned Happy Hare sections from moonraker.conf"
            fi
            # Re-clean printer.cfg MMU includes
            local pcfg="${CONFIG_DIR}/printer.cfg"
            if [ -f "$pcfg" ] && grep -q '^\[include mmu/' "$pcfg" 2>/dev/null; then
                sed -i 's|^\[include mmu/[^]]*\]|# AIO: file missing  &|' "$pcfg"
                ok "Post-rsync: commented out mmu/ includes in printer.cfg"
            fi
            # Remove any restored BunnyBox / Happy Hare config files
            for f in bunnybox_macros.cfg box_drying.cfg; do
                if [ -f "${CONFIG_DIR}/${f}" ]; then
                    rm -f "${CONFIG_DIR}/${f}"
                    ok "Post-rsync: removed restored ${f}"
                fi
            done
        fi
    fi

    # Final cleanup: remove optional runtime addons and, after a successful
    # restore, remove the backup root too so Revert leaves no AIO remnants
    # behind.
    if [ "$restore_ok" = true ] || [ ! -d "$BACKUP_ROOT" ]; then
        # Optional addons that might be installed outside Happy Hare
        if [ -f "${CONFIG_DIR}/idle_fan_shutdown.cfg" ] || \
           grep -q '^\[include idle_fan_shutdown\.cfg\]' "${CONFIG_DIR}/printer.cfg" 2>/dev/null; then
            uninstall_idle_fan_shutdown
        fi
        if [ -d "$MAINSAIL_DIR" ] || [ -f "$MAINSAIL_NGINX_SITE_AVAIL" ] || [ -L "$MAINSAIL_NGINX_SITE_ENABLED" ]; then
            if path_was_preexisting "$MAINSAIL_DIR"; then
                info "Keeping pre-existing Mainsail install: ${MAINSAIL_DIR}"
            else
                uninstall_mainsail
            fi
        fi
        if qidi_box_write_enabled; then
            uninstall_qidi_box_write
        fi

        cleanup_aio_runtime_artifacts
    else
        warn "Restore failed - leaving backup directories in place for recovery."
        info "Inspect: ${BACKUP_ROOT}/"
    fi

    # Make stock display restoration and backup-root deletion the final
    # successful-revert actions so no later cleanup can recreate backup markers.
    if [ "$restore_ok" = true ]; then
        if restore_stock_display_services; then
            remove_backup_root_after_revert || true
        else
            warn "Keeping ${BACKUP_ROOT}/ because stock display services did not verify"
            warn "Fix LightDM/makerbase-client, then rerun Revert to Backup to remove AIO backups."
        fi
    fi

    banner "Revert complete"
    info "Run FIRMWARE_RESTART from Klipper/Moonraker, then sudo reboot."
    info "After reboot, confirm stock display startup with systemctl status lightdm makerbase-client."
}

# ---------- post-install verification --------------------------------
verify_bunnybox_install() {
    banner "Verifying installation"
    local all_ok=true

    for f in printer.cfg gcode_macro.cfg box_drying.cfg KAMP_Settings.cfg \
              Adaptive_Meshing.cfg Line_Purge.cfg Smart_Park.cfg; do
        if [ -s "${CONFIG_DIR}/${f}" ]; then
            ok "${f}"
        else
            err "${f} missing"
            all_ok=false
        fi
    done

    local mmu_params
    mmu_params="$(find_mmu_params)" || mmu_params=""
    if [ -n "$mmu_params" ] && [ -f "$mmu_params" ]; then
        ok "mmu_parameters.cfg present at $mmu_params"
    else
        err "mmu_parameters.cfg missing under ${CONFIG_DIR}/mmu/"
        all_ok=false
    fi

    if ! klipperscreen_installed; then
        if [ -s "${HELIX_CONFIG_DIR}/settings.json" ]; then
            ok "helixscreen settings.json"
        else
            err "helixscreen settings.json missing"
            all_ok=false
        fi
    fi

    if [ "$all_ok" = true ]; then
        ok "All files verified"
    else
        warn "Some files are missing or misconfigured - install may not work correctly."
    fi
}

verify_jfp_install() {
    banner "Verifying installation"
    local all_ok=true
    for f in printer.cfg gcode_macro.cfg KAMP/KAMP_Settings.cfg; do
        if [ -s "${CONFIG_DIR}/${f}" ]; then
            ok "${f}"
        else
            err "${f} missing"
            all_ok=false
        fi
    done
    if [ "$all_ok" = true ]; then
        ok "All files verified"
    else
        warn "Some files are missing - install may not work correctly."
    fi
}

# Catch known Klipper config errors that prevent boot — currently the
# `timeout: <n>` line that some Qidi stock printer.cfg versions misplace
# inside [bed_mesh] (it belongs in [idle_timeout]). Prompts before fixing.
check_invalid_klipper_options() {
    banner "Checking for invalid Klipper config options"
    local pcfg="${CONFIG_DIR}/printer.cfg"
    if [ ! -f "$pcfg" ]; then
        info "printer.cfg not found — skipping"
        return 0
    fi

    # 1. timeout inside [bed_mesh] — Klipper rejects with "Option 'timeout'
    #    is not valid in section 'bed_mesh'". Belongs in [idle_timeout].
    if awk '/^\[bed_mesh\]/{flag=1; next} /^\[/{flag=0} flag && /^[[:space:]]*timeout[[:space:]]*:/{found=1} END{exit !found}' "$pcfg"; then
        warn "Found 'timeout:' inside [bed_mesh] in printer.cfg (invalid — Klipper will refuse to boot)"
        if confirm "Remove the bad 'timeout:' line from [bed_mesh]?"; then
            awk '
                /^\[bed_mesh\]/{flag=1; print; next}
                /^\[/{flag=0; print; next}
                flag && /^[[:space:]]*timeout[[:space:]]*:/{next}
                {print}
            ' "$pcfg" > "${pcfg}.tmp" && mv "${pcfg}.tmp" "$pcfg"
            ok "Removed stale 'timeout:' from [bed_mesh]"
        else
            warn "Left as-is — Klipper boot will fail until removed manually"
        fi
    else
        ok "[bed_mesh] check 1/2: no invalid 'timeout:' found"
    fi

    # 2. gcode: inside [bed_mesh] — same class of error as timeout. Some Qidi
    #    stock printer.cfg versions place the entire [idle_timeout] gcode block
    #    inside [bed_mesh] without a section header. Remove the gcode: key and
    #    all indented lines that follow it within the [bed_mesh] section.
    if awk '/^\[bed_mesh\]/{flag=1; next} /^\[/{flag=0} flag && /^[[:space:]]*gcode[[:space:]]*:/{found=1} END{exit !found}' "$pcfg"; then
        warn "Found 'gcode:' inside [bed_mesh] in printer.cfg (invalid — Klipper will refuse to boot)"
        if confirm "Remove the 'gcode:' block from [bed_mesh]?"; then
            awk '
                /^\[bed_mesh\]/{in_bm=1; in_gc=0; print; next}
                /^\[/{in_bm=0; in_gc=0}
                in_bm && /^[[:space:]]*gcode[[:space:]]*:/{in_gc=1; next}
                in_gc && /^[[:space:]]/{next}
                in_gc && !/^[[:space:]]/{in_gc=0}
                {print}
            ' "$pcfg" > "${pcfg}.tmp" && mv "${pcfg}.tmp" "$pcfg"
            ok "Removed 'gcode:' block from [bed_mesh]"
        else
            warn "Left as-is — Klipper boot will fail until removed manually"
        fi
    else
        ok "[bed_mesh] check 2/2: no invalid 'gcode:' found"
    fi
}

# Find [include X] lines whose target file doesn't exist on disk. Klipper
# halts with "Unable to open config file" if any include is broken.
check_orphan_includes() {
    banner "Checking for orphan [include] lines"
    local pcfg="${CONFIG_DIR}/printer.cfg"
    if [ ! -f "$pcfg" ]; then
        info "printer.cfg not found — skipping"
        return 0
    fi
    local orphans=""
    while IFS= read -r line; do
        local target
        target=$(echo "$line" | sed -n 's/^\[include[[:space:]]\+\([^]]*\)\].*/\1/p' | tr -d ' ')
        [ -z "$target" ] && continue
        # Resolve relative to CONFIG_DIR (Klipper's behavior)
        local resolved="${CONFIG_DIR}/${target#./}"
        if [[ "$resolved" == *[\*\?\[]* ]]; then
            # Klipper supports glob includes. Treat the include as valid when
            # the pattern expands to at least one file; otherwise it is a real
            # orphan and Klipper will complain.
            if ! compgen -G "$resolved" >/dev/null; then
                orphans="${orphans}${line}|${target}"$'\n'
            fi
        elif [ ! -f "$resolved" ]; then
            orphans="${orphans}${line}|${target}"$'\n'
        fi
    done < <(grep -E '^\[include ' "$pcfg" 2>/dev/null || true)

    if [ -z "$orphans" ]; then
        ok "All [include] targets exist"
        return 0
    fi

    warn "Orphan [include] lines reference missing files:"
    echo "$orphans" | while IFS='|' read -r line target; do
        [ -z "$target" ] && continue
        warn "  ${line}   (missing: ${target})"
    done
    if confirm "Comment out all orphan [include] lines in printer.cfg?"; then
        echo "$orphans" | while IFS='|' read -r line target; do
            [ -z "$target" ] && continue
            # Escape regex metacharacters in the include line
            local escaped
            escaped=$(printf '%s' "$line" | sed 's|[][\\.*^$/]|\\&|g')
            sed -i "s|^${escaped}\$|# ${line}  # AIO: missing target ${target}|" "$pcfg"
        done
        ok "Orphan includes commented out"
    else
        warn "Left as-is — Klipper boot will fail until fixed manually"
    fi
}

# Detect Happy Hare / MMU artifacts that survived an uninstall. The Klipper
# extras dir is the main risk — if mmu_*.py or extras/mmu/ are still there
# after revert, Klipper will try to re-register MMU gcode commands and crash.
check_leftover_mmu_artifacts() {
    banner "Checking for leftover MMU / Happy Hare artifacts"
    local extras="${HOME}/klipper/klippy/extras"
    local found=0

    # extras/mmu/ package (Happy Hare v3)
    if [ -d "${extras}/mmu" ]; then
        warn "Found leftover Happy Hare v3 package: ${extras}/mmu/"
        found=1
        if confirm "Remove ${extras}/mmu/?"; then
            sudo rm -rf "${extras}/mmu" && ok "Removed ${extras}/mmu/"
        else
            warn "Left in place — Klipper will load Happy Hare on next restart"
        fi
    fi

    # mmu_*.py symlinks (espooler, servo, led_effect)
    local stragglers
    stragglers=$(find "$extras" -maxdepth 1 -name 'mmu_*.py' 2>/dev/null || true)
    if [ -n "$stragglers" ]; then
        warn "Found leftover Happy Hare symlinks:"
        echo "$stragglers" | while read -r f; do warn "  $f"; done
        found=1
        if confirm "Remove these symlinks?"; then
            echo "$stragglers" | while read -r f; do
                sudo rm -f "$f" && ok "Removed $f"
            done
        else
            warn "Left in place — Klipper will load MMU plugins on next restart"
        fi
    fi

    # [mmu*] sections still active in printer.cfg
    if grep -qE '^\[mmu' "${CONFIG_DIR}/printer.cfg" 2>/dev/null; then
        warn "Found active [mmu*] sections in printer.cfg:"
        grep -nE '^\[mmu' "${CONFIG_DIR}/printer.cfg" | while read -r l; do warn "  $l"; done
        found=1
        if confirm "Comment out [mmu*] sections in printer.cfg?"; then
            sed -i 's|^\(\[mmu.*\]\)|# \1  # AIO: disabled (MMU artifacts cleanup)|' \
                "${CONFIG_DIR}/printer.cfg"
            ok "Commented out [mmu*] sections"
        else
            warn "Left in place — Klipper will fail to start without MMU hardware config"
        fi
    fi

    if [ $found -eq 0 ]; then
        ok "No leftover MMU artifacts found"
    fi
}

# Core verifier sequence. Runs from both menu option 8 and the tail of
# revert_to_backup(). Does NOT call press_enter — that's the caller's job.
_run_verifiers_core() {
    verify_runtime_health

    if bunnybox_installed; then
        verify_bunnybox_install
    else
        info "BunnyBox not installed — skipping MMU + Qidi Box checks"
    fi
    if idle_fan_shutdown_installed; then
        ok "idle_fan_shutdown.cfg installed and included in printer.cfg"
    else
        info "Idle Fan Shutdown not installed"
    fi
    if klipperscreen_installed; then
        verify_klipperscreen
    else
        info "KlipperScreen not installed"
    fi
    if mainsail_installed; then
        verify_mainsail
        verify_camera
    else
        info "Mainsail not installed"
    fi
    if qidi_box_write_enabled; then
        if bunnybox_installed; then
            warn "HELIX_QIDI_BOX_WRITE drop-in present while BunnyBox is installed"
            warn "  → HelixScreen and Happy Hare will both try to drive the Box."
            warn "  → Remove with: sudo rm ${QIDI_BOX_WRITE_DROPIN} && sudo systemctl daemon-reload && sudo systemctl restart helixscreen"
        else
            ok "HELIX_QIDI_BOX_WRITE drop-in present"
        fi
    else
        if bunnybox_installed; then
            ok "HELIX_QIDI_BOX_WRITE drop-in absent (BunnyBox owns the Box write path)"
        else
            info "HELIX_QIDI_BOX_WRITE not enabled"
        fi
    fi
    fix_known_klipper_conflicts
    find_duplicate_macros
    check_invalid_klipper_options
    check_orphan_includes
    if bunnybox_installed; then
        info "BunnyBox installed — skipping leftover MMU artifact cleanup"
    else
        check_leftover_mmu_artifacts
    fi
}

run_all_verifiers() {
    banner "Health Check / Run Verifiers"
    ensure_repair_backup || {
        warn "Backup failed; skipping verifier repairs to preserve current state"
        press_enter
        return 1
    }
    _run_verifiers_core
    press_enter
}

# Scan every .cfg under CONFIG_DIR for duplicate [gcode_macro NAME] decls.
# Klipper refuses to start with "gcode command X already registered" if any
# macro name is defined twice across included files. This pinpoints exactly
# which file pair is the conflict so the user can comment one out.
find_duplicate_macros() {
    banner "Scanning for duplicate gcode_macro declarations"

    if [ ! -d "$CONFIG_DIR" ]; then
        warn "Config directory not found - skipping scan"
        return 0
    fi

    local tmp
    tmp=$(mktemp /tmp/aio_macros.XXXXXX) || return 0

    # Skip backup files/dirs Klipper does not load. Happy Hare and the AIO
    # leave timestamped printer-*.cfg / gcode_macro-*.cfg snapshots directly
    # in CONFIG_DIR, and scanning them creates false duplicate warnings.
    find "$CONFIG_DIR" -maxdepth 4 -type f -name '*.cfg' \
        -not -path '*/backup_*/*' \
        -not -path '*/mmu-2*/*' \
        -not -path '*/_FIRST_STOCK/*' \
        -not -name 'printer-*.cfg' \
        -not -name 'gcode_macro-*.cfg' \
        -not -name '*.bak' \
        -not -name '*.bak.*' \
        -print0 2>/dev/null | \
    xargs -0 grep -Hn -E '^\[gcode_macro [^]]+\]' 2>/dev/null > "$tmp" || true

    if [ ! -s "$tmp" ]; then
        info "No gcode_macro declarations found under ${CONFIG_DIR}"
        rm -f "$tmp"
        return 0
    fi

    local dup_names
    dup_names=$(awk -F'[][]' '{print $2}' "$tmp" | sed 's/^gcode_macro //' | \
                sort | uniq -d)

    if [ -z "$dup_names" ]; then
        ok "No duplicate gcode_macro declarations"
        rm -f "$tmp"
        return 0
    fi

    warn "Duplicate gcode_macro declarations detected — Klipper will refuse to load:"
    while IFS= read -r name; do
        warn "  [gcode_macro ${name}]:"
        grep -F "[gcode_macro ${name}]" "$tmp" | while IFS=: read -r path line _; do
            warn "    ${path}:${line}"
        done
    done <<< "$dup_names"
    warn "Comment out one of each duplicate, then FIRMWARE_RESTART."

    rm -f "$tmp"
    return 1
}

# Remove or neutralise config files known to cause "gcode command X already
# registered" errors when BunnyBox + HelixScreen is installed alongside the
# Qidi stock config files. Idempotent — safe to run multiple times.
fix_known_klipper_conflicts() {
    banner "Resolving known Klipper macro conflicts"

    # 1. KAMP case-sensitivity: Linux treats KAMP_settings.cfg (lowercase-s)
    #    and KAMP_Settings.cfg (uppercase-S) as different files. Both define
    #    [gcode_macro _KAMP_Settings], causing a duplicate error. We install
    #    to uppercase-S; delete the stale lowercase copy.
    if [ -f "${CONFIG_DIR}/KAMP/KAMP_settings.cfg" ] && \
       [ -f "${CONFIG_DIR}/KAMP/KAMP_Settings.cfg" ]; then
        rm -f "${CONFIG_DIR}/KAMP/KAMP_settings.cfg"
        ok "Removed stale KAMP/KAMP_settings.cfg (case-duplicate of KAMP/KAMP_Settings.cfg)"
    fi

    # 2. Adaptive_Mesh.cfg is the old KAMP override that redefined
    #    [gcode_macro BED_MESH_CALIBRATE]. KAMP_Settings.cfg is the current
    #    replacement — delete the old file.
    if [ -f "${CONFIG_DIR}/Adaptive_Mesh.cfg" ]; then
        rm -f "${CONFIG_DIR}/Adaptive_Mesh.cfg"
        ok "Removed stale Adaptive_Mesh.cfg (superseded by KAMP_Settings.cfg)"
    fi

    # 3. box1.cfg — Qidi stock file (included via box.cfg) that defines T0-T3
    #    and UNLOAD_T0-T3. Happy Hare owns these tool-change macros while
    #    BunnyBox is active; the box1.cfg definitions cause "already registered"
    #    errors. Comment out only the conflicting sections; the ## AIO_DISABLED:
    #    prefix makes them easy to restore by hand if BunnyBox is ever removed.
    local box1="${CONFIG_DIR}/box1.cfg"
    if [ -f "$box1" ]; then
        local box1_changed=0
        for macro in T0 T1 T2 T3 UNLOAD_T0 UNLOAD_T1 UNLOAD_T2 UNLOAD_T3; do
            if grep -q "^\[gcode_macro ${macro}\]" "$box1" 2>/dev/null; then
                awk -v target="[gcode_macro ${macro}]" '
                    /^\[/ { in_section = ($0 == target) }
                    { if (in_section) print "## AIO_DISABLED: " $0; else print $0 }
                ' "$box1" > "${box1}.tmp" && mv "${box1}.tmp" "$box1"
                box1_changed=1
            fi
        done
        if [ $box1_changed -eq 1 ]; then
            ok "Commented out conflicting tool-change macros in box1.cfg"
            info "(Happy Hare owns T0-T3 and UNLOAD_T0-T3 while BunnyBox is active)"
        else
            ok "box1.cfg: no conflicting tool-change macros found"
        fi
    fi

    # 4. EXTRUSION_AND_FLUSH: defined in both our gcode_macro.cfg and
    #    bunnybox_macros.cfg. BunnyBox's definition is canonical; comment out
    #    ours so only one definition is active.
    local gcfg="${CONFIG_DIR}/gcode_macro.cfg"
    if [ -f "$gcfg" ] && [ -f "${CONFIG_DIR}/bunnybox_macros.cfg" ] && \
       grep -q '^\[gcode_macro EXTRUSION_AND_FLUSH\]' "$gcfg" 2>/dev/null && \
       grep -q '^\[gcode_macro EXTRUSION_AND_FLUSH\]' "${CONFIG_DIR}/bunnybox_macros.cfg" 2>/dev/null; then
        awk -v target="[gcode_macro EXTRUSION_AND_FLUSH]" '
            /^\[/ { in_section = ($0 == target) }
            { if (in_section) print "## AIO_DISABLED: " $0; else print $0 }
        ' "$gcfg" > "${gcfg}.tmp" && mv "${gcfg}.tmp" "$gcfg"
        ok "Disabled duplicate EXTRUSION_AND_FLUSH in gcode_macro.cfg (bunnybox_macros.cfg owns it)"
    fi

    # 5. TOOL_CHANGE_START / TOOL_CHANGE_END: Qidi's box_extras.py Python
    #    plugin programmatically registers these gcode commands at startup when
    #    [box_extras] is present. bunnybox_macros.cfg also defines them as
    #    [gcode_macro] blocks → "already registered" crash on every boot.
    #    BunnyBox itself labels them "Not currently used, kept for reference".
    #    Comment them out so box_extras.py's implementation is used.
    local bbmacros="${CONFIG_DIR}/bunnybox_macros.cfg"
    if [ -f "$bbmacros" ] && \
       { [ -f "${HOME}/klipper/klippy/extras/box_extras.py" ] || \
         [ -f "${HOME}/klipper/klippy/extras/box_extras.so" ]; }; then
        local bb_changed=0
        for macro in TOOL_CHANGE_START TOOL_CHANGE_END; do
            if grep -q "^\[gcode_macro ${macro}\]" "$bbmacros" 2>/dev/null; then
                awk -v target="[gcode_macro ${macro}]" '
                    /^\[/ { in_section = ($0 == target) }
                    { if (in_section) print "## AIO_DISABLED: " $0; else print $0 }
                ' "$bbmacros" > "${bbmacros}.tmp" && mv "${bbmacros}.tmp" "$bbmacros"
                bb_changed=1
            fi
        done
        if [ $bb_changed -eq 1 ]; then
            ok "Commented out TOOL_CHANGE_START/END in bunnybox_macros.cfg (box_extras.py owns them)"
        fi
    fi

    # 6. BED_MESH_CALIBRATE duplicate: Adaptive_Meshing.cfg is the canonical
    #    owner of [gcode_macro BED_MESH_CALIBRATE]. Scan all .cfg files in the
    #    config root for additional definitions; comment them out in any file
    #    that is NOT Adaptive_Meshing.cfg.  Also re-fetch our clean
    #    KAMP_Settings.cfg if it contains an inline definition (older versions).
    local bmc_files
    bmc_files=$(grep -rl '^\[gcode_macro BED_MESH_CALIBRATE\]' "${CONFIG_DIR}"/*.cfg 2>/dev/null || true)
    if [ -n "$bmc_files" ]; then
        local bmc_count
        bmc_count=$(echo "$bmc_files" | wc -l)
        if [ "$bmc_count" -gt 1 ] || \
           ( [ "$bmc_count" -eq 1 ] && ! echo "$bmc_files" | grep -q 'Adaptive_Meshing\.cfg' ); then
            warn "BED_MESH_CALIBRATE defined in multiple files — will comment out non-canonical copies"
            echo "$bmc_files" | while IFS= read -r f; do
                [ "$(basename "$f")" = "Adaptive_Meshing.cfg" ] && continue
                awk -v target="[gcode_macro BED_MESH_CALIBRATE]" '
                    /^\[/ { in_section = ($0 == target) }
                    { if (in_section) print "## AIO_DISABLED: " $0; else print $0 }
                ' "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
                ok "Commented out duplicate BED_MESH_CALIBRATE in $(basename "$f")"
            done
        else
            ok "BED_MESH_CALIBRATE: single canonical definition in Adaptive_Meshing.cfg"
        fi
    fi
    # Legacy: re-fetch KAMP/KAMP_Settings.cfg if it still carries an inline definition.
    if grep -q '^\[gcode_macro BED_MESH_CALIBRATE\]' "${CONFIG_DIR}/KAMP/KAMP_Settings.cfg" 2>/dev/null; then
        fetch "${REPO_BASE}/KAMP/KAMP_settings.cfg" "${CONFIG_DIR}/KAMP/KAMP_Settings.cfg" \
            && ok "Re-fetched KAMP/KAMP_Settings.cfg (removed stale inline BED_MESH_CALIBRATE)" \
            || warn "Could not re-fetch KAMP/KAMP_Settings.cfg — comment out [gcode_macro BED_MESH_CALIBRATE] in it manually"
    fi

    ok "Conflict resolution complete — FIRMWARE_RESTART to apply"
}

# ---------- install: BunnyBox (shared core + display choice) ---------
_install_bunnybox() {
    banner "Install: BunnyBox & HelixScreen (Q2 with Qidi Box)"

    preflight || { press_enter; return 1; }
    do_backup || { press_enter; return 1; }

    # Preserve the stock Qidi box.cfg in BACKUP_DIR so Revert to Backup has
    # a copy if _FIRST_STOCK is ever missing. The include line in printer.cfg
    # stays commented out (the BunnyBox template ships it that way) — see
    # the note below in the printer.cfg fetch block.
    local BOX_CFG_PRESERVED=""
    if [ -f "${CONFIG_DIR}/box.cfg" ]; then
        BOX_CFG_PRESERVED="${BACKUP_DIR}/box.cfg.preserved"
        cp "${CONFIG_DIR}/box.cfg" "$BOX_CFG_PRESERVED"
        ok "Preserved stock box.cfg → ${BOX_CFG_PRESERVED}"
    fi

    local INSTALL_LOG
    INSTALL_LOG="${BACKUP_ROOT}/install_$(date +%Y%m%d_%H%M%S).log"
    info "Install log: ${INSTALL_LOG}"

    {
        banner "Pre-install: checking for existing Happy Hare install"
        if bunnybox_installed; then
            warn "An existing Happy Hare / BunnyBox install was found."
            warn "${CONFIG_DIR}/mmu/ is present with mmu_parameters.cfg."
            echo ""
            printf '  %s1)%s Upgrade       — keep hardware configs, update firmware macros\n' "$C_CYAN" "$C_RESET"
            printf '  %s2)%s Fresh install — erase all MMU files and start completely clean\n' "$C_CYAN" "$C_RESET"
            printf '  %s0)%s Cancel\n' "$C_CYAN" "$C_RESET"
            echo ""
            local hh_choice=""
            printf '%sSelection: %s' "$C_BOLD" "$C_RESET"
            read -r hh_choice </dev/tty || hh_choice="0"
            case "$hh_choice" in
                1)
                    info "Upgrade selected — BunnyBox will update macros and keep your hardware config"
                    ;;
                2)
                    warn "Fresh install selected — purging all Happy Hare / BunnyBox files..."
                    purge_happy_hare_all
                    ok "MMU files cleared — BunnyBox will install fresh"
                    ;;
                *)
                    info "Cancelled. Returning to the main menu."
                    exit 99
                    ;;
            esac
        elif detect_bunnybox_artifacts; then
            warn "Partial/stale BunnyBox artifacts found (listed above)."
            warn "Their presence may cause BunnyBox to behave unexpectedly."
            if confirm "Remove stale artifacts for a clean install?"; then
                rm -rf "${CONFIG_DIR}/mmu"
                sudo rm -rf "$HAPPY_HARE_DIR"
                rm -f "${CONFIG_DIR}/bunnybox_macros.cfg"
                for f in mmu.py mmu_machine.py mmu_leds.py; do
                    rm -f "${HOME}/klipper/klippy/extras/${f}"
                done
                rm -f "${HOME}/moonraker/moonraker/components/mmu_server.py"
                ok "Stale artifacts removed — BunnyBox will install fresh"
            else
                info "Leaving artifacts — BunnyBox will offer its own Reinstall/Revert menu"
            fi
        else
            ok "No existing install found — clean slate"
        fi

        banner "Installing BunnyBox (Happy Hare MMU)"
        run_remote_script "$BUNNYBOX_INSTALLER"
        local bb_exit=$?
        if [ $bb_exit -ne 0 ]; then
            warn "BunnyBox installer exited ${bb_exit} (may be normal for reinstalls)"
        fi

        # Detect cancellation: BunnyBox exits 0 if the user picks
        # "Cancel" or "Revert to stock" from its sub-menu, so an
        # exit-code check alone would silently continue. Confirm by
        # file detection - and if BunnyBox didn't land, bail straight
        # back to the AIO main menu (no follow-up prompt).
        if ! bunnybox_installed; then
            warn "BunnyBox did not finish installing - no mmu/base/mmu_machine.cfg on disk."
            warn "Detected as user cancellation from BunnyBox's menu."
            info "Aborting install. Returning to the AIO main menu."
            exit 99  # caught after the tee pipeline below
        fi
        ok "BunnyBox install step complete"

        banner "Installing HelixScreen"
        local helix_tmp helix_zip
        helix_tmp=$(mktemp /tmp/helixscreen-pi.XXXXXX) || return 1
        helix_zip="${helix_tmp}.zip"
        mv "$helix_tmp" "$helix_zip" || { rm -f "$helix_tmp" "$helix_zip"; return 1; }
        fetch "$HELIXSCREEN_RELEASE_ZIP" "$helix_zip" || { rm -f "$helix_zip"; return 1; }
        info "Using HelixScreen release archive: ${HELIXSCREEN_RELEASE_ZIP}"
        run_remote_script "$HELIXSCREEN_INSTALLER" --local "$helix_zip"
        local hs_exit=$?
        rm -f "$helix_zip"
        if [ $hs_exit -ne 0 ]; then
            err "HelixScreen installer failed with exit ${hs_exit}"
            return 1
        fi
        ok "HelixScreen install step complete"
        patch_helixscreen_happy_hare_dryer_command || return 1

        banner "Happier Hare dryer integration"
        local happier_zip_url
        if happier_zip_url=$(happier_hare_zip_url); then
            info "Installing rebuilt Happier Hare HelixScreen archive"
            info "Using Happier Hare archive: ${happier_zip_url}"
            HAPPIER_HARE_REPO_REF="$REPO_REF" \
                run_remote_script "$HAPPIER_HARE_INSTALLER" --install-zip "$happier_zip_url"
        else
            info "No rebuilt Happier Hare archive found - keeping macro fallback for drying"
            info "Checked local archive: ${HAPPIER_HARE_LOCAL_ZIP}"
            info "Checked release asset: ${HAPPIER_HARE_RELEASE_ZIP}"
            info "Command strings were patched locally, but native Box humidity/dryer UI"
            info "requires a rebuilt HelixScreen binary with the source-level patch"
        fi

        banner "Installing unified gcode_macro.cfg & printer.cfg"
        fetch "${REPO_BASE}/gcode_macro-BunnyBox%26HelixScreen.cfg" \
              "${CONFIG_DIR}/gcode_macro.cfg" || return 1
        fetch "${REPO_BASE}/printer(BunnyBox%26HelixScreen).cfg" \
              "${CONFIG_DIR}/printer.cfg" || return 1

        # Restore box.cfg on disk (in case BunnyBox's installer removed it)
        # so Revert to Backup can recover from BACKUP_DIR if _FIRST_STOCK is
        # missing. Leave [include box.cfg] in printer.cfg commented out: the
        # Qidi box_extras.so plugin registers CLEAR_TOOLCHANGE_STATE, which
        # Happy Hare's mmu package also registers — loading both crashes
        # Klipper on startup. Happy Hare owns the box hardware via its own
        # [mmu] steppers while BunnyBox is installed, so the Qidi UI's
        # "Control Box" panel will not be available until BunnyBox is removed
        # via Revert to Backup (which restores stock printer.cfg with the
        # include active).
        if [ -n "$BOX_CFG_PRESERVED" ] && [ -f "$BOX_CFG_PRESERVED" ] && \
           [ ! -f "${CONFIG_DIR}/box.cfg" ]; then
            cp "$BOX_CFG_PRESERVED" "${CONFIG_DIR}/box.cfg"
            ok "Restored box.cfg on disk (include left disabled — conflicts with Happy Hare)"
        fi
        # Defensive: if a previous AIO version (RC1-RC4) left [include box.cfg]
        # active in printer.cfg, comment it back out. The shipped template has
        # it disabled, so a clean fetch already handles this — but the user's
        # printer.cfg may have been edited.
        if grep -q '^\[include box\.cfg\]' "${CONFIG_DIR}/printer.cfg" 2>/dev/null; then
            sed -i 's|^\[include box\.cfg\].*|# [include box.cfg]  # AIO: disabled, conflicts with Happy Hare box_extras.so|' \
                "${CONFIG_DIR}/printer.cfg"
            ok "Disabled stale [include box.cfg] in printer.cfg (conflicts with Happy Hare)"
        fi
        ok "Unified configs installed"

        banner "Installing box_drying.cfg"
        fetch "${REPO_BASE}/box_drying.cfg" "${CONFIG_DIR}/box_drying.cfg" || return 1
        ok "box_drying.cfg installed"

        banner "Wiring spool rotation into Happy Hare drying"
        local mmu_params
        mmu_params="$(find_mmu_params)" || true
        if [ -n "$mmu_params" ]; then
            # heater_vent_macro is a general periodic callback fired by
            # MMU_HEATER every heater_vent_interval minutes during drying.
            # Point it at _QIDI_BOX_VENT so the gear steppers rotate spools
            # throughout each drying cycle. Direction alternates each call
            # so net filament travel stays near zero.
            sed -i 's|^heater_vent_macro:.*|heater_vent_macro: _QIDI_BOX_VENT|' "$mmu_params"
            sed -i 's|^heater_vent_interval:.*|heater_vent_interval: 5|' "$mmu_params"
            ok "mmu_parameters.cfg: heater_vent_macro → _QIDI_BOX_VENT, interval → 5 min"
        else
            warn "mmu_parameters.cfg not found — spool rotation not wired; re-run option 1 or 2 after BunnyBox installs"
        fi

        banner "Applying KAMP settings"
        mkdir -p "${CONFIG_DIR}/KAMP"
        fetch "${REPO_BASE}/KAMP/KAMP_settings.cfg"    "${CONFIG_DIR}/KAMP/KAMP_Settings.cfg"    || return 1
        fetch "${REPO_BASE}/KAMP/Adaptive_Meshing.cfg" "${CONFIG_DIR}/KAMP/Adaptive_Meshing.cfg" || return 1
        fetch "${REPO_BASE}/KAMP/Line_Purge.cfg"       "${CONFIG_DIR}/KAMP/Line_Purge.cfg"       || return 1
        fetch "${KAMP_BASE}/Smart_Park.cfg"            "${CONFIG_DIR}/KAMP/Smart_Park.cfg"       || return 1
        ok "KAMP settings and sub-files applied"

        banner "Applying HelixScreen settings"
        mkdir -p "$HELIX_CONFIG_DIR"
        fetch "${REPO_BASE}/helixscreen_settings.json" \
              "${HELIX_CONFIG_DIR}/settings.json" || return 1
        ok "HelixScreen settings applied"
        switch_display_to_helixscreen

        fix_known_klipper_conflicts

        if qidi_box_write_enabled; then
            info "Removing HELIX_QIDI_BOX_WRITE drop-in (BunnyBox owns the Box write path)..."
            uninstall_qidi_box_write
        fi

        verify_qidi_box_helixscreen

        verify_bunnybox_install

        verify_runtime_health
    } 2>&1 | tee -a "$INSTALL_LOG"

    # Check the exit code of the install block (left side of the tee pipe).
    # Exit 99 = user cancelled from BunnyBox's sub-menu.
    # Any other non-zero = a required step failed (fetch, permission, etc.).
    # Both cases must abort so we never print "Install complete" for a
    # partial install that would leave Klipper with broken configs.
    local _pipe_exit="${PIPESTATUS[0]}"
    if [ "$_pipe_exit" = "99" ]; then
        press_enter
        return 1
    elif [ "$_pipe_exit" != "0" ]; then
        err "Install aborted — a required step failed (see log above)"
        err "Log saved to: ${INSTALL_LOG}"
        press_enter
        return 1
    fi

    banner "Install complete"
    cat <<EOF
${C_BOLD}Next steps:${C_RESET}
  1. FIRMWARE_RESTART (Klipper console or HelixScreen)
  2. sudo reboot
  3. Verify:    systemctl status klipper
  4. First-time only - calibrate MMU gear steppers:
        ${C_CYAN}MMU_CALIBRATE_GEAR GATE=0 LENGTH=100${C_RESET}
     Mark filament, measure travel, re-run with MEASURED=<mm>
  5. Start drying (use HelixScreen AMS environment UI when the patched
     Happier Hare zip is installed; otherwise use macro buttons or console):
        ${C_CYAN}DRY_PLA${C_RESET}  ${C_CYAN}DRY_PETG${C_RESET}  ${C_CYAN}DRY_ABS${C_RESET}  ${C_CYAN}DRY_TPU${C_RESET}  ${C_CYAN}DRY_PA${C_RESET}
  6. Check status:   ${C_CYAN}BOX_DRY_STATUS${C_RESET}
  7. Stop drying:    ${C_CYAN}BOX_DRY_STOP${C_RESET}

Install log:    ${INSTALL_LOG}
Config backup:  ${BACKUP_DIR}
EOF

    press_enter
}

install_bunnybox_helixscreen() { _install_bunnybox; }

# ---------- install: KlipperScreen Happy Hare Edition (standalone) ------
install_klipperscreen() {
    banner "Install: KlipperScreen Happy Hare Edition"
    warn "KlipperScreen install is disabled in ${AIO_VERSION}."
    warn "The current xinit/Xorg path fails on the Q2 because the kernel has no VT subsystem."
    warn "Leaving the preserved installer body below for the next display-backend fix."
    press_enter
    return 1

    preflight || { press_enter; return 1; }
    do_backup || { press_enter; return 1; }

    local INSTALL_LOG
    INSTALL_LOG="${BACKUP_ROOT}/install_$(date +%Y%m%d_%H%M%S).log"
    info "Install log: ${INSTALL_LOG}"

    {
        banner "Installing KlipperScreen Happy Hare Edition"
        local ks_install_dir="$KLIPPERSCREEN_DIR"
        local ks_script="$ks_install_dir/scripts/KlipperScreen-install.sh"
        if [ -d "$ks_install_dir/.git" ]; then
            local existing_remote
            existing_remote=$(git -C "$ks_install_dir" remote get-url origin 2>/dev/null || true)
            if [ "$existing_remote" = "$KLIPPERSCREEN_REPO_URL" ]; then
                info "KlipperScreen HH Edition repo exists — updating"
                git -C "$ks_install_dir" pull --ff-only 2>/dev/null || true
            else
                warn "Existing KlipperScreen clone is from wrong repo (${existing_remote})"
                info "Removing old clone and re-cloning Happy Hare Edition"
                rm -rf "$ks_install_dir"
                if ! git clone "$KLIPPERSCREEN_REPO_URL" "$ks_install_dir"; then
                    err "Failed to clone KlipperScreen Happy Hare Edition repository"
                    return 1
                fi
            fi
        else
            [ -d "$ks_install_dir" ] && rm -rf "$ks_install_dir"
            info "Cloning KlipperScreen Happy Hare Edition to ${ks_install_dir}"
            if ! git clone "$KLIPPERSCREEN_REPO_URL" "$ks_install_dir"; then
                err "Failed to clone KlipperScreen Happy Hare Edition repository"
                return 1
            fi
        fi
        chmod +x "$ks_script"
        sed -i 's/xserver-xorg-legacy[[:space:]]*//' "$ks_script"
        info "Running upstream KlipperScreen-install.sh (NETWORK=N)"
        NETWORK=N bash "$ks_script"
        local ks_exit=$?
        [ $ks_exit -ne 0 ] && \
            warn "KlipperScreen installer exited ${ks_exit}"
        local hh_script="$ks_install_dir/happy_hare/install_ks.sh"
        if [ -f "$hh_script" ]; then
            info "Configuring Happy Hare Edition for 4 gates (Qidi Box)"
            chmod +x "$hh_script"
            bash "$hh_script" -g 4
            local hh_exit=$?
            [ $hh_exit -ne 0 ] && \
                warn "Happy Hare Edition gate setup exited ${hh_exit}"
        else
            warn "Happy Hare Edition setup script not found at ${hh_script}"
        fi
        # The Q2 kernel does not create /dev/tty0 (no VT subsystem in the
        # Rockchip BSP kernel). Xorg needs it for VT auto-detection and the
        # upstream service unit has ConditionPathExists=/dev/tty0. A drop-in
        # clears the condition and creates the device node before each start.
        info "Installing /dev/tty0 workaround for Q2"
        sudo mkdir -p /etc/systemd/system/KlipperScreen.service.d
        sudo tee /etc/systemd/system/KlipperScreen.service.d/q2-tty0-fix.conf > /dev/null <<'DROPIN'
[Unit]
ConditionPathExists=

[Service]
ExecStartPre=-/bin/sh -c '[ -e /dev/tty0 ] || /bin/mknod /dev/tty0 c 4 0'
DROPIN
        sudo systemctl daemon-reload 2>/dev/null || true
        ok "/dev/tty0 workaround installed"

        prepare_display_for_klipperscreen
        sudo systemctl restart "$KLIPPERSCREEN_SERVICE" 2>/dev/null || true
        ok "KlipperScreen Happy Hare Edition install complete"

        verify_klipperscreen
    } 2>&1 | tee -a "$INSTALL_LOG"

    local _pipe_exit="${PIPESTATUS[0]}"
    if [ "$_pipe_exit" != "0" ]; then
        err "Install aborted — a required step failed (see log above)"
        err "Log saved to: ${INSTALL_LOG}"
        press_enter
        return 1
    fi

    banner "Install complete"
    cat <<EOF
${C_BOLD}Next steps:${C_RESET}
  1. FIRMWARE_RESTART (Klipper console or KlipperScreen)
  2. sudo reboot
  3. Verify:    systemctl status klipper
  4. Verify:    systemctl status ${KLIPPERSCREEN_SERVICE}

Install log:    ${INSTALL_LOG}
Config backup:  ${BACKUP_DIR}
EOF

    press_enter
}

# ---------- install: Just Faster Printer -----------------------------
install_just_faster() {
    banner "Install: Just Faster Printer (Q2 without Box)"

    preflight || { press_enter; return 1; }
    do_backup || { press_enter; return 1; }
    cleanup_aio_install_artifacts

    info "Updating gcode_macro.cfg..."
    fetch "${REPO_BASE}/gcode_macro(JustFasterPrinter).cfg" \
          "${CONFIG_DIR}/gcode_macro.cfg" || { press_enter; return 1; }
    ok "gcode_macro.cfg installed"

    info "Updating printer.cfg..."
    fetch "${REPO_BASE}/JustFasterPrinter.cfg" \
          "${CONFIG_DIR}/printer.cfg" || { press_enter; return 1; }
    ok "printer.cfg installed"

    info "Applying KAMP settings (KAMP subdir layout)..."
    mkdir -p "${CONFIG_DIR}/KAMP"
    fetch "${REPO_BASE}/KAMP/KAMP_settings.cfg"    "${CONFIG_DIR}/KAMP/KAMP_Settings.cfg"    || { press_enter; return 1; }
    fetch "${REPO_BASE}/KAMP/Adaptive_Meshing.cfg" "${CONFIG_DIR}/KAMP/Adaptive_Meshing.cfg" || { press_enter; return 1; }
    fetch "${REPO_BASE}/KAMP/Line_Purge.cfg"       "${CONFIG_DIR}/KAMP/Line_Purge.cfg"       || { press_enter; return 1; }
    ok "KAMP settings applied"

    verify_jfp_install

    banner "Install complete"
    cat <<EOF
${C_BOLD}Your Q2 is now running the 'Just Faster' setup.${C_RESET}
  No Bunny Box, no HelixScreen - just cleaner macros and faster starts.

${C_BOLD}Next steps:${C_RESET}
  1. FIRMWARE_RESTART (Klipper console or stock screen)
  2. sudo reboot
  3. Run a bed level + screws_tilt_adjust before your first print.

Config backup:  ${BACKUP_DIR}
EOF

    press_enter
}

# ---------- about ----------------------------------------------------
show_about() {
    banner "About - Qidi Q2 Superuser AIO"
    cat <<EOF
${C_CYAN}Qidi Q2 Superuser - All-in-One Installer${C_RESET}
${C_BOLD}Version:${C_RESET} ${AIO_VERSION}

A community-built toolkit to unlock advanced features on the Qidi Q2
3D printer beyond stock Qidi firmware. This menu is the single entry
point for every supported install / uninstall path.

${C_BOLD}What it can install:${C_RESET}

  ${C_GREEN}BunnyBox & HelixScreen${C_RESET}  (Q2 ${C_BOLD}with${C_RESET} the Qidi Box)
    - Happy Hare MMU firmware/macros for multi-material printing
    - HelixScreen replacement touchscreen UI (pinned >= ${HELIXSCREEN_PIN})
    - Happier Hare hook: installs a rebuilt HelixScreen archive from
      HAPPIER_HARE_ZIP_URL, or from ${HAPPIER_HARE_LOCAL_ZIP} when that
      file is present, for native Box humidity/dryer UI and Happy
      Hare-compatible dryer commands
    - Unified printer.cfg + gcode_macro.cfg
    - box_drying.cfg: spool rotation during filament drying using
      Happy Hare's Environment Manager, with humidity-based early
      termination via the AHT2X sensor
    - KAMP adaptive bed meshing
    - ${C_CYAN}Strips the HELIX_QIDI_BOX_WRITE drop-in${C_RESET} if present.
      That env var lets HelixScreen drive the Qidi Box natively
      (load_filament, unload_filament, change_tool, set_tool_mapping).
      With BunnyBox + Happy Hare driving the Box via MMU macros, having
      HelixScreen also drive it natively causes contention.
    - helixscreen_settings.json: AMS spool style set to '3d' for
      Qidi Box slot visualization in the HelixScreen AMS panel
    - Post-install verification: checks box.cfg, [box_stepper] sections,
      officiall_filas_list.cfg, and HelixScreen version compatibility

  ${C_GREEN}Just Faster Printer${C_RESET}    (Q2 ${C_BOLD}without${C_RESET} the Box, stock screen)
    - Faster, cleaner PRINT_START / PRINT_END macros
    - KAMP adaptive meshing, screws_tilt_adjust, Spoolman hooks
    - No UI changes - stock Qidi screen stays

  ${C_YELLOW}KlipperScreen Happy Hare Edition${C_RESET}
    - Installer body is preserved, but menu option 2 is disabled while
      the Q2 display backend issue is investigated

${C_BOLD}What it can uninstall:${C_RESET}
  - 'Revert to Backup' is the supported full restore path.
  - Revert removes KlipperScreen, HelixScreen, BunnyBox/Happy Hare,
    optional addons, display-service overrides, AIO-created KIAUH dirs,
    helix_print, and ${BACKUP_ROOT}/ after a successful restore.
  - Revert re-enables lightdm + makerbase-client, sets graphical.target,
    and prints recent service logs if the stock display stack fails.
    If the stock display stack does not verify, ${BACKUP_ROOT}/ is kept
    for recovery instead of being deleted.
  - Config restore prefers ${BACKUP_ROOT}/_FIRST_STOCK, then the
    oldest timestamped backup.

${C_BOLD}Safety:${C_RESET}
  Every install and uninstall first writes a timestamped backup of
  ${CONFIG_DIR}/ to ${BACKUP_ROOT}/<timestamp>/.
  Health-check repairs also create a backup before editing configs.
  Refuses to run as root.

${C_BOLD}Known limitations:${C_RESET}
  - Native HelixScreen Qidi Box humidity/dryer UI currently requires the
    Happier Hare patched HelixScreen zip via HAPPIER_HARE_ZIP_URL or
    ${HAPPIER_HARE_LOCAL_ZIP}.
    Macro buttons remain the fallback when using the stock HelixScreen zip.
  - ${C_YELLOW}MMU_CALIBRATE_GEAR${C_RESET} is required after clean installs.
  - BunnyBox currently requires HelixScreen for MMU workflows; the
    stock Qidi screen does not yet expose the MMU UI.

${C_BOLD}Repo:${C_RESET}     Camden-Winder/Qidi-Q2-superuser
${C_BOLD}Upstream:${C_RESET} Camden-Winder/Qidi-Q2-superuser (uninstall lineage)
EOF
    press_enter
}

# ---------- main menu ------------------------------------------------
show_status_line() {
    local bb_status display_status idle_status box_write_status mainsail_status camera_status
    if bunnybox_installed; then
        bb_status="${C_GREEN}installed${C_RESET}"
    else
        bb_status="${C_YELLOW}not found${C_RESET}"
    fi
    if klipperscreen_installed; then
        display_status="${C_GREEN}KlipperScreen${C_RESET}"
    elif helixscreen_installed; then
        display_status="${C_GREEN}HelixScreen${C_RESET}"
    else
        display_status="${C_YELLOW}none${C_RESET}"
    fi
    if idle_fan_shutdown_installed; then
        idle_status="${C_GREEN}on${C_RESET}"
    else
        idle_status="${C_YELLOW}off${C_RESET}"
    fi
    if mainsail_installed; then
        mainsail_status="${C_GREEN}installed${C_RESET}"
    else
        mainsail_status="${C_YELLOW}not found${C_RESET}"
    fi
    if camera_installed; then
        camera_status="${C_GREEN}streaming${C_RESET}"
    else
        camera_status="${C_YELLOW}off${C_RESET}"
    fi
    # With BunnyBox installed, the HELIX_QIDI_BOX_WRITE drop-in conflicts
    # with Happy Hare's MMU control of the Box — so "off" is the desired
    # state. Without BunnyBox, "on" is fine for native HelixScreen control.
    if bunnybox_installed; then
        if qidi_box_write_enabled; then
            box_write_status="${C_YELLOW}on (conflict)${C_RESET}"
        else
            box_write_status="${C_GREEN}off${C_RESET}"
        fi
    else
        if qidi_box_write_enabled; then
            box_write_status="${C_GREEN}on${C_RESET}"
        else
            box_write_status="${C_YELLOW}off${C_RESET}"
        fi
    fi
    printf '  BunnyBox: %b | Display: %b | IdleFan: %b | BoxWrite: %b\n' \
           "$bb_status" "$display_status" "$idle_status" "$box_write_status"
    printf '  Mainsail: %b | Camera: %b\n' \
           "$mainsail_status" "$camera_status"
}

draw_menu() {
    clear 2>/dev/null || true
    printf '%s============================================%s\n' "$C_BOLD$C_MAGENTA" "$C_RESET"
    printf '%s   Qidi Q2 Superuser - AIO Setup Menu (%s)%s\n'   "$C_BOLD$C_MAGENTA" "$AIO_VERSION" "$C_RESET"
    printf '%s============================================%s\n' "$C_BOLD$C_MAGENTA" "$C_RESET"
    show_status_line
    printf '%s--------------------------------------------%s\n' "$C_BOLD" "$C_RESET"
    printf '  %sINSTALL%s\n' "$C_BOLD$C_GREEN" "$C_RESET"
    printf '   %s1)%s Install BunnyBox & HelixScreen    (Q2 with Qidi Box)\n'         "$C_CYAN" "$C_RESET"
    printf '   %s2)%s Install KlipperScreen             (temporarily disabled)\n'       "$C_YELLOW" "$C_RESET"
    printf '   %s3)%s Install Just Faster Printer       (Q2 without Box)\n'           "$C_CYAN" "$C_RESET"
    printf '  %sUNINSTALL%s\n' "$C_BOLD$C_YELLOW" "$C_RESET"
    printf '   %s4)%s Revert to Backup                  (full uninstall + restore stock)\n' "$C_CYAN" "$C_RESET"
    printf '  %sADDONS%s\n' "$C_BOLD$C_MAGENTA" "$C_RESET"
    printf '   %s5)%s Idle Fan Shutdown                 (10m idle, temp-gated)\n' "$C_CYAN" "$C_RESET"
    printf '   %s6)%s Mainsail                          (web UI on port 100)\n'   "$C_CYAN" "$C_RESET"
    printf '  %sINFO%s\n' "$C_BOLD$C_CYAN" "$C_RESET"
    printf '   %s7)%s About\n'                                                    "$C_CYAN" "$C_RESET"
    printf '   %s8)%s Health Check / Run Verifiers\n'                             "$C_CYAN" "$C_RESET"
    printf '   %s0)%s Exit\n'                                                    "$C_CYAN" "$C_RESET"
    printf '%s============================================%s\n' "$C_BOLD$C_MAGENTA" "$C_RESET"
    printf '%sEnter selection:%s ' "$C_BOLD" "$C_RESET"
}

confirm() {
    local prompt="$1"
    local ans
    printf '%s%s [y/N]:%s ' "$C_YELLOW" "$prompt" "$C_RESET"
    read -r ans </dev/tty || return 1
    case "$ans" in
        y|Y|yes|YES) return 0 ;;
        *) return 1 ;;
    esac
}

show_disclaimer() {
    clear 2>/dev/null || true
    printf '%s============================================%s\n' "$C_BOLD$C_YELLOW" "$C_RESET"
    printf '%s   DISCLAIMER%s\n' "$C_BOLD$C_YELLOW" "$C_RESET"
    printf '%s============================================%s\n' "$C_BOLD$C_YELLOW" "$C_RESET"
    printf '\n'
    printf '  This tool modifies Klipper configuration files on your\n'
    printf '  Qidi Q2 printer. %sUse it at your own risk.%s\n' "$C_BOLD" "$C_RESET"
    printf '\n'
    printf '  The author is not responsible for any damage, malfunction,\n'
    printf '  or data loss caused to your printer as a result of using\n'
    printf '  this tool.\n'
    printf '\n'
    printf '  %sQidi states that any modifications to files on their\n' "$C_BOLD"
    printf '  printers may void the manufacturer warranty.%s\n' "$C_RESET"
    printf '\n'
    printf '%s============================================%s\n' "$C_BOLD$C_YELLOW" "$C_RESET"
    printf '\n'
    if ! confirm "I understand and wish to continue"; then
        info "Exiting."
        exit 0
    fi
}

main_loop() {
    while true; do
        draw_menu
        local choice
        read -r choice </dev/tty || exit 0
        case "$choice" in
            1) install_bunnybox_helixscreen ;;
            2) warn "KlipperScreen install is temporarily disabled — display issue under investigation." ; press_enter ;;
            3) install_just_faster ;;
            4)
                warn "Revert to Backup will uninstall AIO display/MMU changes,"
                warn "restore configs from ${BACKUP_ROOT}/, and re-enable stock lightdm + makerbase-client."
                if confirm "Proceed with full revert?"; then
                    revert_to_backup
                    press_enter
                fi
                ;;
            5) menu_idle_fan_shutdown ;;
            6) menu_mainsail ;;
            7) show_about ;;
            8) run_all_verifiers ;;
            0|q|Q|exit) info "Bye."; exit 0 ;;
            *) err "Invalid selection: '$choice'"; sleep 1 ;;
        esac
    done
}

show_disclaimer
main_loop
