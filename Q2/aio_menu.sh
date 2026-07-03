#!/bin/bash
# =====================================================================
# Qidi Q2 Superuser - All-in-One (AIO) Installer / Manager
#
# A single entry point for the ChanceVegas/Qidi-Q2-superuser_helpinghands
# toolkit. Drives every supported install path and uninstall path from
# one ANSI-colored menu:
#
#   * Install BunnyBox & HelixScreen   (Q2 with Qidi Box)
#   * Install Just Faster Printer      (Q2 without Box, stock screen)
#   * Revert to Backup                 (uninstall both + restore stock)
#   * About
#
# Target: Qidi Q2, ARM Linux, running Klipper. Legacy mks firmware is
# supported for mutating actions; 1.1.2/qidi firmware is detected and
# blocked until the compatibility lane is complete. Do NOT run as root.
# =====================================================================

set -uo pipefail

# ---------- version --------------------------------------------------
AIO_VERSION='RC2.66'

# ---------- firmware layout ------------------------------------------
detect_q2_firmware_layout() {
    local mks_target
    mks_target=$(readlink -f /home/mks 2>/dev/null || true)

    if [ "$mks_target" = "/home/qidi" ] || \
       [ -d /home/qidi/QIDI_Client ] || \
       systemctl cat qidi-client.service >/dev/null 2>&1; then
        printf '%s\n' "q2_112"
        return 0
    fi

    if [ -d /home/mks/printer_data/config ]; then
        printf '%s\n' "legacy_mks"
        return 0
    fi

    printf '%s\n' "unknown"
}

AIO_LAYOUT="${AIO_LAYOUT_OVERRIDE:-$(detect_q2_firmware_layout)}"
case "$AIO_LAYOUT" in
    q2_112)
        AIO_USER='qidi'
        AIO_HOME='/home/qidi'
        AIO_LAYOUT_NAME='Q2 firmware 1.1.2 / qidi layout'
        AIO_LAYOUT_SUPPORTS_MUTATION=false
        STOCK_UI_SERVICE='qidi-client'
        STOCK_UI_LABEL='QIDIClient stock UI'
        STOCK_DISPLAY_SERVICE=''
        STOCK_DISPLAY_LABEL='none'
        MACRO_LAYOUT='klipper-macros-qd'
        CAMERA_STACK='crowsnest'
        ;;
    legacy_mks)
        AIO_USER='mks'
        AIO_HOME='/home/mks'
        AIO_LAYOUT_NAME='legacy mks layout'
        AIO_LAYOUT_SUPPORTS_MUTATION=true
        STOCK_UI_SERVICE='makerbase-client'
        STOCK_UI_LABEL='Makerbase stock UI'
        STOCK_DISPLAY_SERVICE='lightdm'
        STOCK_DISPLAY_LABEL='LightDM'
        MACRO_LAYOUT='root'
        CAMERA_STACK='ustreamer'
        ;;
    *)
        AIO_USER="${USER:-mks}"
        AIO_HOME="${HOME:-/home/mks}"
        AIO_LAYOUT_NAME='unknown layout'
        AIO_LAYOUT_SUPPORTS_MUTATION=false
        STOCK_UI_SERVICE='makerbase-client'
        STOCK_UI_LABEL='Makerbase stock UI'
        STOCK_DISPLAY_SERVICE='lightdm'
        STOCK_DISPLAY_LABEL='LightDM'
        MACRO_LAYOUT='unknown'
        CAMERA_STACK='unknown'
        ;;
esac

# ---------- repo / installer URLs ------------------------------------
REPO_REF="${AIO_REPO_REF:-main}"
REPO_BASE="https://raw.githubusercontent.com/Camden-Winder/Qidi-Q2-superuser/refs/heads/${REPO_REF}/Q2"
BUNNYBOX_INSTALLER='https://raw.githubusercontent.com/Camden-Winder/Bunny-Box/refs/heads/main/Q2/install-bb-q2.sh'
HELIXSCREEN_INSTALLER="https://raw.githubusercontent.com/prestonbrown/helixscreen/main/scripts/install.sh"
HELIX_UNINSTALLER='https://releases.helixscreen.org/install.sh'
# KAMP_BASE no longer used — Adaptive_Meshing.cfg, Line_Purge.cfg, Smart_Park.cfg now served from REPO_BASE
# Mainsail is delegated to Camden-Winder's standalone installer, which
# installs to ${AIO_HOME}/mainsail on port 100 (Qidi's stock lighttpd owns
# port 80) and patches moonraker.conf for CORS.
MAINSAIL_INSTALLER='https://raw.githubusercontent.com/Camden-Winder/Qidi-Q2-superuser/refs/heads/main/Q2/install-mainsail.sh'

# ---------- paths ----------------------------------------------------
CONFIG_DIR="${AIO_HOME}/printer_data/config"
BACKUP_ROOT="${AIO_HOME}/mudstockbackups"
SNAPSHOT_DIR="${AIO_HOME}/aio_config_backup"
AIO_MARKER="${CONFIG_DIR}/aoi.ini"
HELIX_DIR="${AIO_HOME}/helixscreen"
HELIX_PRINT_DIR="${AIO_HOME}/helix_print"
HELIX_CONFIG_DIR="${HELIX_DIR}/config"
HAPPY_HARE_DIR="${AIO_HOME}/Happy-Hare"
KIAUH_DIR="${AIO_HOME}/kiauh"
KIAUH_BACKUPS_DIR="${AIO_HOME}/kiauh-backups"
KIAUH_UPPER_DIR="${AIO_HOME}/KIAUH"
KIAUH_UPPER_BACKUPS_DIR="${AIO_HOME}/KIAUH-backups"
MAINSAIL_DIR="${AIO_HOME}/mainsail"
KLIPPER_DIR="${AIO_HOME}/klipper"
MOONRAKER_DIR="${AIO_HOME}/moonraker"
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

Q2_112_PROBE_STATE_DIR="${BACKUP_ROOT}/_Q2_112_PROBE_STATE"
Q2_112_PROBE_ORIGINAL="${Q2_112_PROBE_STATE_DIR}/printer.cfg.original"
Q2_112_PROBE_MODIFIED="${Q2_112_PROBE_STATE_DIR}/printer.cfg.probe"
Q2_112_PROBE_MANIFEST="${Q2_112_PROBE_STATE_DIR}/manifest"
Q2_112_PROBE_CFG="${CONFIG_DIR}/aio_q2_112_compat_probe.cfg"
Q2_112_PROBE_INCLUDE='[include aio_q2_112_compat_probe.cfg]'
Q2_112_CONTRACT_DIR="${BACKUP_ROOT}/_Q2_112_RESTORE_CONTRACT"
Q2_112_CONTRACT_PATH_STATES="${Q2_112_CONTRACT_DIR}/path_states"
Q2_112_CONTRACT_SERVICES="${Q2_112_CONTRACT_DIR}/services"
Q2_112_REHEARSAL_DIR="${BACKUP_ROOT}/_Q2_112_RESTORE_REHEARSAL"
Q2_112_LIVE_PROOF_DIR="${BACKUP_ROOT}/_Q2_112_LIVE_RESTORE_PROOF"
Q2_112_LIVE_PROOF_CFG="${CONFIG_DIR}/aio_q2_112_live_restore_proof.cfg"
Q2_112_LIVE_PROOF_EXTERNAL_DIR="${HELIX_PRINT_DIR}"
Q2_112_LIVE_PROOF_EXTERNAL_MARKER="${Q2_112_LIVE_PROOF_EXTERNAL_DIR}/.aio_q2_112_live_restore_proof"
Q2_112_PRESENT_PROOF_DIR="${BACKUP_ROOT}/_Q2_112_PRESENT_PATH_RESTORE_PROOF"
Q2_112_PRESENT_PROOF_TARGET="/etc/systemd/system/${STOCK_UI_SERVICE}.service.d"
Q2_112_PRESENT_PROOF_SOURCE="${Q2_112_CONTRACT_DIR}/external${Q2_112_PRESENT_PROOF_TARGET}"
Q2_112_PRESENT_PROOF_MARKER="${Q2_112_PRESENT_PROOF_TARGET}/aio-q2-112-restore-proof.marker"
Q2_112_KLIPPER_EXTRAS_PROOF_DIR="${BACKUP_ROOT}/_Q2_112_KLIPPER_EXTRAS_RESTORE_PROOF"
Q2_112_KLIPPER_EXTRAS_PROOF_TARGET="${KLIPPER_DIR}/klippy/extras"
Q2_112_KLIPPER_EXTRAS_PROOF_MARKER="${Q2_112_KLIPPER_EXTRAS_PROOF_TARGET}/.aio-q2-112-restore-proof.marker"
Q2_112_MOONRAKER_COMPONENTS_PROOF_DIR="${BACKUP_ROOT}/_Q2_112_MOONRAKER_COMPONENTS_RESTORE_PROOF"
Q2_112_MOONRAKER_COMPONENTS_PROOF_TARGET="${MOONRAKER_DIR}/moonraker/components"
Q2_112_MOONRAKER_COMPONENTS_PROOF_MARKER="${Q2_112_MOONRAKER_COMPONENTS_PROOF_TARGET}/.aio-q2-112-restore-proof.marker"

# Returns the installed HelixScreen version string (e.g. "0.99.66"), or empty if undetermined; tries the binary first, then a VERSION file.
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

q2_firmware_layout() {
    printf '%s\n' "$AIO_LAYOUT"
}

q2_firmware_layout_label() {
    case "$AIO_LAYOUT" in
        q2_112) printf '%s\n' "${AIO_LAYOUT_NAME} (unsupported)" ;;
        legacy_mks) printf '%s\n' "$AIO_LAYOUT_NAME" ;;
        *) printf '%s\n' "${AIO_LAYOUT_NAME} (unsupported)" ;;
    esac
}

layout_supports_mutation() {
    [ "$AIO_LAYOUT_SUPPORTS_MUTATION" = true ]
}

unsupported_mutation_layout() {
    ! layout_supports_mutation
}

stock_display_stack_label() {
    if [ -n "$STOCK_DISPLAY_SERVICE" ] && [ -n "$STOCK_UI_SERVICE" ]; then
        printf '%s + %s\n' "$STOCK_DISPLAY_LABEL" "$STOCK_UI_LABEL"
    elif [ -n "$STOCK_UI_SERVICE" ]; then
        printf '%s\n' "$STOCK_UI_LABEL"
    elif [ -n "$STOCK_DISPLAY_SERVICE" ]; then
        printf '%s\n' "$STOCK_DISPLAY_LABEL"
    else
        printf '%s\n' "no separate stock display service"
    fi
}

require_supported_firmware_layout() {
    local action="${1:-this action}"

    if unsupported_mutation_layout; then
        banner "Unsupported Qidi Q2 firmware layout"
        err "AIO ${AIO_VERSION} is paused for the detected firmware layout."
        warn "Blocked action: ${action}"
        warn "Detected layout: ${AIO_LAYOUT_NAME}"
        if [ "$AIO_LAYOUT" = "q2_112" ]; then
            warn "Detected /home/mks -> /home/qidi, qidi-client.service, or /home/qidi/QIDI_Client."
        fi
        warn "AIO paths are now layout-aware, but install/revert/addon mutations"
        warn "still need a dedicated compatibility pass for ${STOCK_UI_SERVICE} and ${MACRO_LAYOUT}."
        warn "Do not run install, revert, addon, or repair paths until the 1.1.2"
        warn "compatibility lane is implemented."
        return 1
    fi

    return 0
}

show_layout_report() {
    local mks_target
    banner "Detected firmware layout"
    info "Layout: ${AIO_LAYOUT_NAME} (${AIO_LAYOUT})"
    info "Mutation support: ${AIO_LAYOUT_SUPPORTS_MUTATION}"
    info "AIO user/home: ${AIO_USER} / ${AIO_HOME}"
    info "Config dir: ${CONFIG_DIR}"
    info "Backup root: ${BACKUP_ROOT}"
    info "Klipper dir: ${KLIPPER_DIR}"
    info "Moonraker dir: ${MOONRAKER_DIR}"
    info "Stock UI service: ${STOCK_UI_SERVICE:-none}"
    info "Stock display service: ${STOCK_DISPLAY_SERVICE:-none}"
    info "Macro layout: ${MACRO_LAYOUT}"
    info "Camera stack: ${CAMERA_STACK}"
    if [ -L /home/mks ]; then
        mks_target=$(readlink -f /home/mks 2>/dev/null || printf 'unknown')
        info "/home/mks target: ${mks_target}"
    fi
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

verify_qidi_tuning_service_health() {
    local active enabled restart_policy restarts

    if ! systemctl cat qidi-tuning >/dev/null 2>&1; then
        info "Qidi tuning service: systemd unit not installed"
        return 0
    fi

    active=$(systemctl is-active qidi-tuning 2>/dev/null || true)
    enabled=$(systemctl is-enabled qidi-tuning 2>/dev/null || true)
    restart_policy=$(systemctl show qidi-tuning -p Restart --value 2>/dev/null || true)
    restarts=$(systemctl show qidi-tuning -p NRestarts --value 2>/dev/null || true)

    case "$active" in
        active|activating)
            ok "Qidi tuning service: ${active} (enabled=${enabled:-unknown})"
            ;;
        *)
            warn "Qidi tuning service: ${active:-unknown} (enabled=${enabled:-unknown})"
            ;;
    esac

    if [ "$restart_policy" = "always" ]; then
        info "Qidi tuning service uses Restart=always; restart count=${restarts:-unknown} is expected stock behavior"
    elif [ -n "$restarts" ] && [ "$restarts" != "0" ]; then
        warn "Qidi tuning service: systemd restart count=${restarts}"
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

        if ! systemctl is-active --quiet helixscreen 2>/dev/null; then
            warn "HelixScreen: not active — attempting restart"
            if sudo systemctl restart helixscreen 2>/dev/null; then
                sleep 2
                if systemctl is-active --quiet helixscreen 2>/dev/null; then
                    ok "HelixScreen: restarted successfully"
                else
                    err "HelixScreen: restart failed — if this persists, re-run the installer"
                    show_systemd_journal_tail helixscreen "HelixScreen"
                fi
            else
                err "HelixScreen: restart failed — if this persists, re-run the installer"
                show_systemd_journal_tail helixscreen "HelixScreen"
            fi
        fi

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

    if [ -n "$STOCK_DISPLAY_SERVICE" ]; then
        verify_systemd_service_health "$STOCK_DISPLAY_SERVICE" "$STOCK_DISPLAY_LABEL" true
    else
        info "Stock display manager: none for ${AIO_LAYOUT_NAME}"
    fi
    if [ -n "$STOCK_UI_SERVICE" ]; then
        verify_systemd_service_health "$STOCK_UI_SERVICE" "$STOCK_UI_LABEL" true
    else
        info "Stock UI service: none"
    fi

    if [ -n "$STOCK_DISPLAY_SERVICE" ] && \
       ! systemctl is-active --quiet "$STOCK_DISPLAY_SERVICE" 2>/dev/null; then
        show_systemd_journal_tail "$STOCK_DISPLAY_SERVICE" "$STOCK_DISPLAY_LABEL"
    fi
    if [ -n "$STOCK_UI_SERVICE" ] && \
       ! systemctl is-active --quiet "$STOCK_UI_SERVICE" 2>/dev/null; then
        show_systemd_journal_tail "$STOCK_UI_SERVICE" "$STOCK_UI_LABEL"
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

    if [ -d "${KLIPPER_DIR}/klippy/extras/mmu" ]; then
        ok "Happy Hare Klipper extras package linked"
    else
        warn "Happy Hare Klipper extras package missing: ${KLIPPER_DIR}/klippy/extras/mmu"
    fi

    if [ -f "${MOONRAKER_DIR}/moonraker/components/mmu_server.py" ]; then
        ok "Happy Hare Moonraker component linked"
    else
        warn "Happy Hare Moonraker component missing: ${MOONRAKER_DIR}/moonraker/components/mmu_server.py"
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

    verify_qidi_box_runtime_sensors
}

verify_qidi_box_runtime_sensors() {
    banner "Qidi Box live sensor health"

    local response summary level message
    if ! response=$(moonraker_get "/printer/objects/query?aht10%20box1_env=temperature,humidity&temperature_sensor%20box1_env=temperature,humidity&heater_generic%20box1_heater=temperature,target,power&aht20_f%20heater_box1=temperature,humidity&heater_generic%20heater_box1=temperature,target,power&temperature_sensor%20heater_temp_a_box1=temperature&temperature_sensor%20heater_temp_b_box1=temperature"); then
        warn "Could not query Qidi Box sensor objects through Moonraker"
        return 0
    fi

    summary=$(printf '%s' "$response" | python3 -c '
import json
import sys

status = json.load(sys.stdin).get("result", {}).get("status", {})
aht = status.get("aht10 box1_env", {})
env = status.get("temperature_sensor box1_env", {})
heater = status.get("heater_generic box1_heater", {})
stock_aht = status.get("aht20_f heater_box1", {})
stock_heater = status.get("heater_generic heater_box1", {})
stock_temp_a = status.get("temperature_sensor heater_temp_a_box1", {})
stock_temp_b = status.get("temperature_sensor heater_temp_b_box1", {})

def emit(level, label, value, suffix=""):
    if isinstance(value, (int, float)):
        print(f"{level}|{label}: {value}{suffix}")
    else:
        print(f"WARN|{label}: not published")

if isinstance(aht.get("temperature"), (int, float)) or isinstance(aht.get("humidity"), (int, float)):
    print("INFO|BunnyBox/AIO sensor namespace detected")
    emit("OK", "Box environment temperature", aht.get("temperature"), " C")
    emit("OK", "Box environment humidity", aht.get("humidity"), " %")
    emit("OK", "Box heater temperature", heater.get("temperature"), " C")
    emit("OK", "Box heater target", heater.get("target"), " C")
    emit("OK", "Box heater power", heater.get("power"), "")

if isinstance(stock_aht.get("temperature"), (int, float)) or isinstance(stock_aht.get("humidity"), (int, float)):
    print("INFO|Stock Qidi Box sensor namespace detected")
    emit("OK", "Stock Box environment temperature", stock_aht.get("temperature"), " C")
    emit("OK", "Stock Box environment humidity", stock_aht.get("humidity"), " %")
    emit("OK", "Stock Box heater temperature", stock_heater.get("temperature"), " C")
    emit("OK", "Stock Box heater target", stock_heater.get("target"), " C")
    emit("OK", "Stock Box heater power", stock_heater.get("power"), "")
    emit("OK", "Stock Box heater temp A", stock_temp_a.get("temperature"), " C")
    emit("OK", "Stock Box heater temp B", stock_temp_b.get("temperature"), " C")

if not any(isinstance(obj.get(key), (int, float)) for obj in (aht, heater, stock_aht, stock_heater) for key in ("temperature", "humidity", "target", "power")):
    print("WARN|No live Qidi Box temperature/heater values are currently published")

if isinstance(aht.get("temperature"), (int, float)) and not isinstance(env.get("humidity"), (int, float)):
    print("INFO|temperature_sensor box1_env wrapper does not publish humidity; HelixScreen must read aht10 box1_env")
' 2>/dev/null || true)

    if [ -z "$summary" ]; then
        warn "Qidi Box sensor query returned, but status could not be parsed"
        return 0
    fi

    while IFS='|' read -r level message; do
        case "$level" in
            OK) ok "$message" ;;
            INFO) info "$message" ;;
            *) warn "$message" ;;
        esac
    done <<< "$summary"
}

verify_runtime_health() {
    verify_klipper_runtime_health
    verify_happy_hare_runtime_health
    verify_helixscreen_runtime_health
    if ! helixscreen_installed; then
        verify_stock_display_runtime_health
    fi
}

# Post-install sanity check for the Qidi Box / HelixScreen read-path; warns on missing box.cfg, filament list, version, and [include box.cfg] conflicts. Never fails.
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

}

QIDI_BOX_WRITE_DROPIN='/etc/systemd/system/helixscreen.service.d/qidi-box-write.conf'

# Returns 0 if the HELIX_QIDI_BOX_WRITE=1 systemd drop-in is installed and active.
qidi_box_write_enabled() {
    [ -f "$QIDI_BOX_WRITE_DROPIN" ] && \
    grep -q 'HELIX_QIDI_BOX_WRITE=1' "$QIDI_BOX_WRITE_DROPIN" 2>/dev/null
}

# Installs a systemd drop-in that sets HELIX_QIDI_BOX_WRITE=1, enabling HelixScreen's experimental Qidi Box write ops (load/unload filament, change_tool). Prompts with 5s default-yes before writing.
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

# ---------- Mainsail (delegated to Camden-Winder's installer) --------

# Returns true if Mainsail's index.html and nginx site config are both present.
mainsail_installed() {
    [ -f "${MAINSAIL_DIR}/index.html" ] && \
    [ -f "$MAINSAIL_NGINX_SITE_AVAIL" ]
}

install_mainsail() {
    banner "Installing Mainsail (Camden-Winder's installer)"
    if [ "$AIO_LAYOUT" = "q2_112" ]; then
        warn "Mainsail installation has not been tested on 01.01.02+ / qidi firmware."
        warn "If you experience issues, please open a GitHub issue at:"
        warn "  https://github.com/Camden-Winder/Qidi-Q2-superuser/issues"
    fi
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

# Returns true if the ustreamer systemd service unit is enabled.
camera_installed() {
    systemctl is-enabled --quiet "$USTREAMER_SERVICE" 2>/dev/null
}

# Returns 0 if the camera config matches the current design: ustreamer bound to 127.0.0.1, nginx /webcam/ proxy present, and moonraker.conf stream_url using the proxy path.
camera_config_is_current() {
    [ -f "$USTREAMER_UNIT" ] || return 1
    grep -q 'host=127.0.0.1' "$USTREAMER_UNIT" || return 1
    [ -f "$MAINSAIL_NGINX_SITE_AVAIL" ] || return 1
    grep -q 'location /webcam/' "$MAINSAIL_NGINX_SITE_AVAIL" || return 1
    grep -q '/webcam/stream' "${CONFIG_DIR}/moonraker.conf" 2>/dev/null || return 1
    return 0
}

# Inserts a /webcam/ proxy location block into the Mainsail nginx config before its closing brace; idempotent.
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

# Queries Moonraker's webcam API and offers to delete database-source (UI-added) webcam entries so only one [webcam printer] entry remains in Mainsail.
purge_mainsail_ui_webcams() {
    local api="http://127.0.0.1:${MOONRAKER_PORT}"
    local response
    local attempt
    for attempt in 1 2 3 4 5 6; do
        response=$(curl -sf --max-time 5 "${api}/server/webcams/list" 2>/dev/null) && break
        sleep 2
    done
    if [ -z "$response" ]; then
        warn "Could not reach Moonraker API after 6 attempts (~12s) — skipping duplicate-webcam check"
        warn "If Mainsail shows a duplicate camera, run option 7 again to retry the check"
        return 0
    fi
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
    if [ "$AIO_LAYOUT" = "q2_112" ]; then
        warn "Camera installation has not been tested on 01.01.02+ / qidi firmware."
        warn "If you experience issues, please open a GitHub issue at:"
        warn "  https://github.com/Camden-Winder/Qidi-Q2-superuser/issues"
    fi

    if camera_installed && camera_config_is_current; then
        ok "Camera streaming already configured (current format) — skipping"
        return 0
    fi
    if camera_installed; then
        info "Existing camera config detected — rewriting to current format"
    fi

    # Query Moonraker for any existing webcam entries (config or database
    # sourced) before touching anything. Moonraker is already running
    # normally at this point (not just-restarted), so this call is reliable
    # without needing a retry loop.
    local existing_webcams
    existing_webcams=$(curl -sf --max-time 5 "http://127.0.0.1:${MOONRAKER_PORT}/server/webcams/list" 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for c in data.get('result', {}).get('webcams', []):
        print(c.get('name', 'unknown') + '|' + c.get('source', 'unknown'))
except Exception:
    pass
" 2>/dev/null)

    if [ -n "$existing_webcams" ]; then
        warn "Existing webcam(s) already registered in Moonraker:"
        while IFS='|' read -r cam_name cam_source; do
            [ -z "$cam_name" ] && continue
            warn "  - ${cam_name} (source: ${cam_source})"
        done <<< "$existing_webcams"
        warn "Installing ustreamer will add a new 'printer' camera entry and may result in duplicates."
        if ! confirm "Proceed with ustreamer install anyway?"; then
            info "Skipping ustreamer install — existing webcam entry will be used."
            info "If Mainsail shows no camera, run option 7 again and choose to proceed."
            return 0
        fi
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
User=${AIO_USER}
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
        purge_mainsail_ui_webcams || true
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

update_macros() {
    banner "Update Macros"

    local group
    if ! group=$(read_aoi_ini "install_group"); then
        err "aoi.ini not found or install_group missing — please reinstall using option 1, 2, or 3"
        press_enter
        return 1
    fi

    if [ "$group" = "unknown" ]; then
        err "Install group is unknown in aoi.ini — please reinstall using option 1, 2, or 3"
        press_enter
        return 1
    fi

    warn "This will overwrite your current macro files with the latest AOI versions."
    warn "Any custom modifications to these files will be lost."
    warn "Detected install group: ${group}"
    if ! confirm "Proceed with macro update?"; then
        info "Macro update cancelled"
        press_enter
        return 0
    fi

    case "$group" in
        BunnyBox)
            info "Updating gcode_macro.cfg..."
            fetch "${REPO_BASE}/macros/gcode_macro-BunnyBox.cfg" \
                  "${CONFIG_DIR}/gcode_macro.cfg" || { press_enter; return 1; }
            ok "gcode_macro.cfg updated"
            info "Updating printer.cfg..."
            fetch "${REPO_BASE}/macros/printer-BunnyBox.cfg" \
                  "${CONFIG_DIR}/printer.cfg" || { press_enter; return 1; }
            ok "printer.cfg updated"
            ;;
        JustFasterPrinter)
            info "Updating gcode_macro.cfg..."
            fetch "${REPO_BASE}/macros/gcode_macro-JustFasterPrinter.cfg" \
                  "${CONFIG_DIR}/klipper-macros-qd/gcode_macro.cfg" || { press_enter; return 1; }
            ok "gcode_macro.cfg updated"
            local kamp_include="[include KAMP/KAMP_settings.cfg]"
            local printer_cfg="${CONFIG_DIR}/printer.cfg"
            local tmp_cfg
            tmp_cfg=$(mktemp /tmp/printer_cfg_patched.XXXXXX)
            info "Re-patching printer.cfg: KAMP include missing"
            python3 - "$printer_cfg" "$kamp_include" "$tmp_cfg" <<'PYEOF'
import sys
cfg, line, out = sys.argv[1], sys.argv[2], sys.argv[3]
txt = open(cfg).read()
if line not in txt:
    txt = txt.rstrip('\n') + '\n' + line + '\n'
with open(out, 'w') as f:
    f.write(txt)
PYEOF
            if grep -qF "$kamp_include" "$tmp_cfg" 2>/dev/null; then
                sudo cp "$tmp_cfg" "$printer_cfg"
                ok "KAMP include re-added to printer.cfg"
            elif grep -qF "$kamp_include" "$printer_cfg" 2>/dev/null; then
                info "KAMP include already present in printer.cfg — skipping"
            else
                err "Failed to patch printer.cfg — add '[include KAMP/KAMP_settings.cfg]' manually"
            fi
            rm -f "$tmp_cfg"
            ;;
        JustFasterBox)
            info "Updating gcode_macro.cfg..."
            fetch "${REPO_BASE}/macros/gcode_macro-JustFasterBox.cfg" \
                  "${CONFIG_DIR}/klipper-macros-qd/gcode_macro.cfg" || { press_enter; return 1; }
            ok "gcode_macro.cfg updated"
            local kamp_include="[include KAMP/KAMP_settings.cfg]"
            local printer_cfg="${CONFIG_DIR}/printer.cfg"
            local tmp_cfg
            tmp_cfg=$(mktemp /tmp/printer_cfg_patched.XXXXXX)
            info "Re-patching printer.cfg: KAMP include missing"
            python3 - "$printer_cfg" "$kamp_include" "$tmp_cfg" <<'PYEOF'
import sys
cfg, line, out = sys.argv[1], sys.argv[2], sys.argv[3]
txt = open(cfg).read()
if line not in txt:
    txt = txt.rstrip('\n') + '\n' + line + '\n'
with open(out, 'w') as f:
    f.write(txt)
PYEOF
            if grep -qF "$kamp_include" "$tmp_cfg" 2>/dev/null; then
                sudo cp "$tmp_cfg" "$printer_cfg"
                ok "KAMP include re-added to printer.cfg"
            elif grep -qF "$kamp_include" "$printer_cfg" 2>/dev/null; then
                info "KAMP include already present in printer.cfg — skipping"
            else
                err "Failed to patch printer.cfg — add '[include KAMP/KAMP_settings.cfg]' manually"
            fi
            rm -f "$tmp_cfg"
            ;;
        *)
            err "Unknown install group '${group}' in aoi.ini — please reinstall using option 1, 2, or 3"
            press_enter
            return 1
            ;;
    esac

    info "Updating KAMP files..."
    clean_kamp_dir
    fetch "${REPO_BASE}/KAMP/KAMP_settings.cfg"    "${CONFIG_DIR}/KAMP/KAMP_settings.cfg"    || { press_enter; return 1; }
    fetch "${REPO_BASE}/KAMP/Adaptive_Meshing.cfg" "${CONFIG_DIR}/KAMP/Adaptive_Meshing.cfg" || { press_enter; return 1; }
    fetch "${REPO_BASE}/KAMP/Line_Purge.cfg"       "${CONFIG_DIR}/KAMP/Line_Purge.cfg"       || { press_enter; return 1; }
    fetch "${REPO_BASE}/KAMP/Smart_Park.cfg"       "${CONFIG_DIR}/KAMP/Smart_Park.cfg"       || { press_enter; return 1; }
    ok "KAMP files updated"

    local install_ver install_group
    install_ver=$(read_aoi_ini "install_version") || install_ver="unknown"
    install_group=$(read_aoi_ini "install_group") || install_group="$group"
    write_aoi_ini "$install_group" "$install_ver" "${AIO_VERSION}"

    ok "Macro update complete — macro_version set to ${AIO_VERSION}"
    press_enter
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
                    info "Run FIRMWARE_RESTART to finish applying changes."
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
                    info "Run FIRMWARE_RESTART to finish applying changes."
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
                info "Run FIRMWARE_RESTART to finish applying changes."
            else
                warn "Setup had problems (see above)"
            fi
        fi
    fi
    press_enter
}

# Echoes the path to mmu_parameters.cfg, checking both mmu/ (current) and mmu/base/ (older Happy Hare installs).
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

# Restores macros in box1.cfg and gcode_macro.cfg that fix_known_klipper_conflicts() commented out with ## AIO_DISABLED: during BunnyBox install.
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

# Removes Happy Hare / BunnyBox artifacts outside CONFIG_DIR: source tree, klipper extras, and the moonraker mmu_server component.
# Config files are handled separately by rsync --delete in revert_to_backup(), which is the only caller.
_purge_happy_hare_nonconfig() {
    banner "Removing Happy Hare / BunnyBox (non-config cleanup)"

    if [ -f "${HAPPY_HARE_DIR}/install.sh" ]; then
        info "Running Happy Hare uninstaller (-d)..."
        sudo bash "${HAPPY_HARE_DIR}/install.sh" -d 2>/dev/null || true
    fi

    info "Removing Happy Hare source tree: ${HAPPY_HARE_DIR}"
    sudo rm -rf "$HAPPY_HARE_DIR"
    if [ -d "$HAPPY_HARE_DIR" ]; then
        err "Failed to remove ${HAPPY_HARE_DIR} — trying alternate approach"
        sudo find "$HAPPY_HARE_DIR" -delete 2>/dev/null || true
    fi

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

    local residue=0
    [ -d "$HAPPY_HARE_DIR" ]                          && { warn "RESIDUE: ${HAPPY_HARE_DIR} still exists"; residue=1; }
    [ -d "${HOME}/klipper/klippy/extras/mmu" ]        && { warn "RESIDUE: extras/mmu/ still exists"; residue=1; }
    if [ $residue -eq 1 ]; then
        warn "Some Happy Hare artifacts survived purge — check output above"
    else
        ok "Happy Hare / BunnyBox non-config purge verified clean"
    fi
}

# Exhaustively removes every known Happy Hare / BunnyBox footprint regardless of whether upstream uninstallers ran.
# Called from both uninstall_bunnybox() and the verifier repair path.
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

    # Config files Happy Hare / BunnyBox may have written at config root
    rm -f "${CONFIG_DIR}/bunnybox_macros.cfg"
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

    # Root-level KAMP files installed by the AIO BunnyBox flow. Do not remove
    # ${CONFIG_DIR}/KAMP here: Qidi stock configs may own that directory and
    # revert_to_backup()'s rsync --delete handles it from the snapshot.
    for f in KAMP_settings.cfg Adaptive_Meshing.cfg Line_Purge.cfg Smart_Park.cfg; do
        rm -f "${CONFIG_DIR}/${f}"
    done

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
    # KAMP_settings.cfg as root, then curl --output to it gets EACCES).
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

# Clears all KAMP files from CONFIG_DIR and creates a fresh empty KAMP directory.
clean_kamp_dir() {
    # On q2_112, stock firmware ships KAMP_Settings.cfg inside klipper-macros-qd/
    # which collides with ours ([gcode_macro _KAMP_Settings] defined twice).
    if [ "$AIO_LAYOUT" = "q2_112" ]; then
        rm -f "${CONFIG_DIR}/klipper-macros-qd/KAMP_Settings.cfg" 2>/dev/null || \
            sudo rm -f "${CONFIG_DIR}/klipper-macros-qd/KAMP_Settings.cfg" 2>/dev/null
    fi
    # Remove any file in config root with "kamp" in the name (case-insensitive)
    find "${CONFIG_DIR}" -maxdepth 1 -iname "*kamp*" -type f -delete 2>/dev/null
    # Remove the entire KAMP folder and all contents
    rm -rf "${CONFIG_DIR}/KAMP" 2>/dev/null || sudo rm -rf "${CONFIG_DIR}/KAMP" 2>/dev/null
    # Create a fresh KAMP directory
    mkdir -p "${CONFIG_DIR}/KAMP" 2>/dev/null || sudo mkdir -p "${CONFIG_DIR}/KAMP" 2>/dev/null
}

bunnybox_installed() {
    # Look for mmu_parameters.cfg anywhere under ${CONFIG_DIR}/mmu/ so
    # we work with both flat (current) and base/ (legacy) layouts.
    [ -d "${CONFIG_DIR}/mmu" ] && \
    [ -n "$(find "${CONFIG_DIR}/mmu" -maxdepth 3 -name 'mmu_parameters.cfg' \
            -print -quit 2>/dev/null)" ]
}

just_faster_printer_installed() {
    [ -f "${CONFIG_DIR}/gcode_macro.cfg" ] && \
    grep -q 'Superuser Macros: Just Faster Printer' "${CONFIG_DIR}/gcode_macro.cfg" 2>/dev/null
}

just_faster_box_installed() {
    [ -f "${CONFIG_DIR}/gcode_macro.cfg" ] && \
    grep -q 'Superuser Macros: Just Faster Box' "${CONFIG_DIR}/gcode_macro.cfg" 2>/dev/null
}

# Scans well-known BunnyBox artifact paths; prints any found and returns 0 if any are present, 1 if clean.
detect_bunnybox_artifacts() {
    local found=0
    local paths=(
        "$HAPPY_HARE_DIR"
        "${CONFIG_DIR}/mmu"
        "${CONFIG_DIR}/bunnybox_macros.cfg"
        "${KLIPPER_DIR}/klippy/extras/mmu.py"
        "${KLIPPER_DIR}/klippy/extras/mmu_machine.py"
        "${KLIPPER_DIR}/klippy/extras/mmu_leds.py"
        "${MOONRAKER_DIR}/moonraker/components/mmu_server.py"
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
    systemctl is-enabled helixscreen &>/dev/null
}

preflight() {
    banner "Pre-flight checks"

    require_supported_firmware_layout "pre-flight install/addon checks" || return 1

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

# Variant of preflight() for q2_112 installs; skips the mutation layout guard since q2_112 submenu functions scope their own layout checks.
preflight_q2_112() {
    banner "Pre-flight checks (01.01.02+ / qidi layout)"
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
    ok "Config directory: $CONFIG_DIR"
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

install_jfp_q2_112() {
    banner "Install: Just Faster Printer (01.01.02+ / qidi layout)"
    preflight_q2_112 || { press_enter; return 1; }
    do_backup        || { press_enter; return 1; }
    local macro_dest="${CONFIG_DIR}/klipper-macros-qd/gcode_macro.cfg"
    local printer_cfg="${CONFIG_DIR}/printer.cfg"
    local kamp_include="[include KAMP/KAMP_settings.cfg]"
    info "Writing macro file → klipper-macros-qd/gcode_macro.cfg"
    fetch "${REPO_BASE}/macros/gcode_macro-JustFasterPrinter.cfg" \
          "$macro_dest" || { press_enter; return 1; }
    ok "gcode_macro.cfg installed to klipper-macros-qd/"
    info "Applying KAMP settings..."
    clean_kamp_dir
    fetch "${REPO_BASE}/KAMP/KAMP_settings.cfg"    "${CONFIG_DIR}/KAMP/KAMP_settings.cfg"    || { press_enter; return 1; }
    fetch "${REPO_BASE}/KAMP/Adaptive_Meshing.cfg" "${CONFIG_DIR}/KAMP/Adaptive_Meshing.cfg" || { press_enter; return 1; }
    fetch "${REPO_BASE}/KAMP/Line_Purge.cfg"       "${CONFIG_DIR}/KAMP/Line_Purge.cfg"       || { press_enter; return 1; }
    fetch "${REPO_BASE}/KAMP/Smart_Park.cfg"       "${CONFIG_DIR}/KAMP/Smart_Park.cfg"       || { press_enter; return 1; }
    ok "KAMP files installed to ${CONFIG_DIR}/KAMP/"
    local tmp_cfg
    tmp_cfg=$(mktemp /tmp/printer_cfg_patched.XXXXXX)
    info "Patching printer.cfg: adding KAMP include"
    python3 - "$printer_cfg" "$kamp_include" "$tmp_cfg" <<'PYEOF'
import sys, re
path, line_to_add, out = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    content = f.read()
if line_to_add in content:
    sys.exit(0)
patched = re.sub(r'(\[include )', line_to_add + '\n' + r'\1', content, count=1)
with open(out, 'w') as f:
    f.write(patched)
PYEOF
    if grep -qF "$kamp_include" "$tmp_cfg" 2>/dev/null; then
        sudo cp "$tmp_cfg" "$printer_cfg"
        ok "KAMP include added to printer.cfg"
    elif grep -qF "$kamp_include" "$printer_cfg" 2>/dev/null; then
        info "KAMP include already present in printer.cfg — skipping"
    else
        err "Failed to patch printer.cfg — add '[include KAMP/KAMP_settings.cfg]' manually"
    fi
    rm -f "$tmp_cfg"
    write_aoi_ini "JustFasterPrinter" "${AIO_VERSION}" "${AIO_VERSION}"
    banner "Install complete"
    cat <<EOF
${C_BOLD}Just Faster Printer applied (01.01.02+ mode).${C_RESET}
  Macros written to: ${macro_dest}
  KAMP files:        ${CONFIG_DIR}/KAMP/
${C_BOLD}Next steps:${C_RESET}
  1. FIRMWARE_RESTART (Klipper console or stock screen)
Config snapshot: ${SNAPSHOT_DIR}
EOF
    press_enter
}

install_jfb_q2_112() {
    banner "Install: Just Faster Box (01.01.02+ / qidi layout)"
    preflight_q2_112 || { press_enter; return 1; }
    do_backup        || { press_enter; return 1; }
    local macro_dest="${CONFIG_DIR}/klipper-macros-qd/gcode_macro.cfg"
    local printer_cfg="${CONFIG_DIR}/printer.cfg"
    local kamp_include="[include KAMP/KAMP_settings.cfg]"
    info "Writing macro file → klipper-macros-qd/gcode_macro.cfg"
    fetch "${REPO_BASE}/macros/gcode_macro-JustFasterBox.cfg" \
          "$macro_dest" || { press_enter; return 1; }
    ok "gcode_macro.cfg installed to klipper-macros-qd/"
    info "Applying KAMP settings..."
    clean_kamp_dir
    fetch "${REPO_BASE}/KAMP/KAMP_settings.cfg"    "${CONFIG_DIR}/KAMP/KAMP_settings.cfg"    || { press_enter; return 1; }
    fetch "${REPO_BASE}/KAMP/Adaptive_Meshing.cfg" "${CONFIG_DIR}/KAMP/Adaptive_Meshing.cfg" || { press_enter; return 1; }
    fetch "${REPO_BASE}/KAMP/Line_Purge.cfg"       "${CONFIG_DIR}/KAMP/Line_Purge.cfg"       || { press_enter; return 1; }
    fetch "${REPO_BASE}/KAMP/Smart_Park.cfg"       "${CONFIG_DIR}/KAMP/Smart_Park.cfg"       || { press_enter; return 1; }
    ok "KAMP files installed to ${CONFIG_DIR}/KAMP/"
    local tmp_cfg
    tmp_cfg=$(mktemp /tmp/printer_cfg_patched.XXXXXX)
    info "Patching printer.cfg: adding KAMP include"
    python3 - "$printer_cfg" "$kamp_include" "$tmp_cfg" <<'PYEOF'
import sys, re
path, line_to_add, out = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    content = f.read()
if line_to_add in content:
    sys.exit(0)
patched = re.sub(r'(\[include )', line_to_add + '\n' + r'\1', content, count=1)
with open(out, 'w') as f:
    f.write(patched)
PYEOF
    if grep -qF "$kamp_include" "$tmp_cfg" 2>/dev/null; then
        sudo cp "$tmp_cfg" "$printer_cfg"
        ok "KAMP include added to printer.cfg"
    elif grep -qF "$kamp_include" "$printer_cfg" 2>/dev/null; then
        info "KAMP include already present in printer.cfg — skipping"
    else
        err "Failed to patch printer.cfg — add '[include KAMP/KAMP_settings.cfg]' manually"
    fi
    rm -f "$tmp_cfg"
    write_aoi_ini "JustFasterBox" "${AIO_VERSION}" "${AIO_VERSION}"
    banner "Install complete"
    cat <<EOF
${C_BOLD}Just Faster Box applied (01.01.02+ mode).${C_RESET}
  Macros written to: ${macro_dest}
  KAMP files:        ${CONFIG_DIR}/KAMP/
${C_BOLD}Next steps:${C_RESET}
  1. FIRMWARE_RESTART (Klipper console or stock screen)
Config snapshot: ${SNAPSHOT_DIR}
EOF
    press_enter
}

# Returns the path to the AIO persistent state directory inside BACKUP_ROOT.
aio_state_dir() {
    printf '%s\n' "${BACKUP_ROOT}/_AIO_STATE"
}

# Returns the path to the manifest file that lists AIO-managed paths that existed before the first install.
aio_preexisting_paths_file() {
    printf '%s\n' "$(aio_state_dir)/preexisting_paths"
}

# On first run, records which AIO-managed paths already existed so uninstall can avoid removing user-preexisting directories.
capture_first_run_state() {
    local state_dir preexisting path
    state_dir=$(aio_state_dir)
    preexisting=$(aio_preexisting_paths_file)
    if [ -f "$preexisting" ]; then
        return 0
    fi

    mkdir -p "$state_dir" 2>/dev/null || sudo mkdir -p "$state_dir" || {
        warn "Could not create AIO state manifest directory"
        return 0
    }
    : > "$preexisting" 2>/dev/null || sudo touch "$preexisting" || {
        warn "Could not write AIO state manifest"
        return 0
    }

    for path in \
        "$HAPPY_HARE_DIR" \
        "$HELIX_DIR" \
        "$HELIX_PRINT_DIR" \
        "$KIAUH_DIR" \
        "$KIAUH_BACKUPS_DIR" \
        "$KIAUH_UPPER_DIR" \
        "$KIAUH_UPPER_BACKUPS_DIR" \
        "$MAINSAIL_DIR" \
        "${CONFIG_DIR}/KAMP" \
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

# Returns true if the given path was present on disk before AIO first ran.
path_was_preexisting() {
    local path="$1"
    local preexisting
    preexisting=$(aio_preexisting_paths_file)
    [ -f "$preexisting" ] && grep -Fxq "$path" "$preexisting"
}

# Returns true if a path exists and was not preexisting — i.e., safe to remove on uninstall.
should_remove_aio_path() {
    local path="$1"
    [ -e "$path" ] || return 1
    if path_was_preexisting "$path"; then
        info "Keeping pre-existing path: $path"
        return 1
    fi
    return 0
}

take_snapshot() {
    # Takes the rsync snapshot only. Does NOT write .aio_installed.
    if [ ! -f "${AIO_MARKER}" ]; then
        banner "Capturing stock config snapshot"
        mkdir -p "${SNAPSHOT_DIR}" 2>/dev/null || sudo mkdir -p "${SNAPSHOT_DIR}"
        if ! rsync -a "${CONFIG_DIR}/" "${SNAPSHOT_DIR}/" 2>/dev/null; then
            if ! sudo rsync -a "${CONFIG_DIR}/" "${SNAPSHOT_DIR}/"; then
                err "Snapshot failed — cannot proceed safely"
                return 1
            fi
        fi
        ok "Stock snapshot saved to ${SNAPSHOT_DIR}"
    else
        info "AIO marker present — existing snapshot retained"
    fi
    return 0
}

write_aoi_ini() {
    local group="$1"
    local install_ver="$2"
    local macro_ver="$3"
    local date
    date=$(date +%Y-%m-%d)
    local content
    content="$(printf '[aoi]\ninstall_version=%s\nmacro_version=%s\ninstall_group=%s\ninstall_date=%s\n' \
        "$install_ver" "$macro_ver" "$group" "$date")"
    if printf '%s' "$content" | install -m 0644 /dev/stdin "${AIO_MARKER}" 2>/dev/null || \
       printf '%s' "$content" | sudo install -m 0644 /dev/stdin "${AIO_MARKER}" 2>/dev/null; then
        ok "aoi.ini written: ${AIO_MARKER}"
    else
        warn "Could not write aoi.ini — state file missing"
    fi
}

read_aoi_ini() {
    local key="$1"
    if [ ! -f "${AIO_MARKER}" ]; then
        return 1
    fi
    local val
    val=$(grep "^${key}=" "${AIO_MARKER}" 2>/dev/null | cut -d'=' -f2-)
    if [ -z "$val" ]; then
        return 1
    fi
    printf '%s' "$val"
}

do_backup() {
    # If AIO has never run an install on this printer, snapshot the current
    # config as "stock" — regardless of what's in it (manual installs included).
    # The marker is created AFTER the snapshot so the snapshot never contains it;
    # rsync --delete in revert_to_backup() removes the marker automatically.
    take_snapshot || return 1
    if [ ! -f "${AIO_MARKER}" ]; then
        # Migrate old empty marker to aoi.ini
        local old_marker="${CONFIG_DIR}/.aio_installed"
        if [ -f "$old_marker" ]; then
            rm -f "$old_marker" 2>/dev/null || sudo rm -f "$old_marker"
            info "Migrated .aio_installed → aoi.ini"
        fi
        write_aoi_ini "unknown" "${AIO_VERSION}" "${AIO_VERSION}"
    fi
    return 0
}

# Takes a safety snapshot before verifier auto-repairs; idempotent — only backs up once per session.
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
    ok "BunnyBox / Happy Hare uninstalled"
}

# Removes all AIO-created runtime directories and systemd/udev/polkit files installed by HelixScreen and BunnyBox.
cleanup_aio_runtime_artifacts() {
    banner "Cleaning AIO runtime artifacts"

    uninstall_qidi_box_write

    for d in \
        "$HAPPY_HARE_DIR" \
        "$HELIX_DIR" \
        "$HELIX_PRINT_DIR" \
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

    sudo rm -f /etc/systemd/system/helixscreen.service
    sudo rm -f /etc/systemd/system/helixscreen-update.path
    sudo rm -f /etc/systemd/system/helixscreen-update.service
    sudo rm -f /etc/udev/rules.d/99-helixscreen-backlight.rules
    sudo rm -f /etc/polkit-1/localauthority/50-local.d/helixscreen-network.pkla
    sudo rm -f /etc/polkit-1/rules.d/49-helixscreen-network.rules
    sudo rm -f /etc/polkit-1/rules.d/50-helixscreen-network.rules
    sudo systemctl daemon-reload 2>/dev/null || true
}


# Unmasks, enables, and starts the Qidi stock display services (STOCK_DISPLAY_SERVICE and STOCK_UI_SERVICE), undoing HelixScreen's service masking and boot-target override.
restore_stock_display_services() {
    info "Re-enabling Qidi stock display services: $(stock_display_stack_label)"

    # HelixScreen owns the framebuffer directly, so installs mask the stock
    # display stack. Revert must undo both service masking and the boot target.
    sudo systemctl daemon-reload                     2>/dev/null || true
    sudo systemctl set-default graphical.target      2>/dev/null || true
    if [ -n "$STOCK_DISPLAY_SERVICE" ]; then
        sudo systemctl reset-failed "$STOCK_DISPLAY_SERVICE" 2>/dev/null || true
        sudo systemctl unmask       "$STOCK_DISPLAY_SERVICE" 2>/dev/null || true
        sudo systemctl enable       "$STOCK_DISPLAY_SERVICE" 2>/dev/null || true
    fi
    if [ -n "$STOCK_UI_SERVICE" ]; then
        sudo systemctl reset-failed "$STOCK_UI_SERVICE"      2>/dev/null || true
        sudo systemctl unmask       "$STOCK_UI_SERVICE"      2>/dev/null || true
        sudo systemctl enable       "$STOCK_UI_SERVICE"      2>/dev/null || true
    fi
    sudo systemctl reset-failed display-manager.service      2>/dev/null || true
    sudo systemctl unmask  display-manager.service           2>/dev/null || true

    sudo systemctl stop helixscreen 2>/dev/null || true
    if [ -n "$STOCK_DISPLAY_SERVICE" ]; then
        sudo systemctl start "$STOCK_DISPLAY_SERVICE" 2>/dev/null || true
    fi
    if [ -n "$STOCK_DISPLAY_SERVICE" ] && \
       ! systemctl is-active --quiet "$STOCK_DISPLAY_SERVICE" 2>/dev/null; then
        sudo systemctl start display-manager.service 2>/dev/null || true
    fi
    sleep 2
    if [ -n "$STOCK_UI_SERVICE" ]; then
        sudo systemctl start "$STOCK_UI_SERVICE" 2>/dev/null || true
    fi

    local display_ok=true ui_ok=true
    if [ -n "$STOCK_DISPLAY_SERVICE" ] && \
       ! systemctl is-active --quiet "$STOCK_DISPLAY_SERVICE" 2>/dev/null; then
        display_ok=false
    fi
    if [ -n "$STOCK_UI_SERVICE" ] && \
       ! systemctl is-active --quiet "$STOCK_UI_SERVICE" 2>/dev/null; then
        ui_ok=false
    fi

    if [ "$display_ok" = true ] && [ "$ui_ok" = true ]; then
        ok "Qidi stock display services are active"
    else
        warn "Qidi stock display services were requested but one is not active"
        warn "Run Option 8 or check: systemctl status ${STOCK_DISPLAY_SERVICE:-display-manager.service} ${STOCK_UI_SERVICE:-}"
        if [ "$display_ok" != true ]; then
            show_systemd_journal_tail "$STOCK_DISPLAY_SERVICE" "$STOCK_DISPLAY_LABEL"
        fi
        if [ "$ui_ok" != true ]; then
            show_systemd_journal_tail "$STOCK_UI_SERVICE" "$STOCK_UI_LABEL"
        fi
        return 1
    fi
}


# Prints whether a given path is present/absent/symlink without making any changes (used in dry-run reports).
dry_run_path_state() {
    local label="$1"
    local path="$2"

    if [ -L "$path" ]; then
        ok "${label}: present symlink (${path} -> $(readlink "$path" 2>/dev/null || printf 'unknown'))"
    elif [ -e "$path" ]; then
        if [ -d "$path" ]; then
            ok "${label}: present directory (${path})"
        else
            ok "${label}: present file (${path})"
        fi
    else
        info "${label}: absent (${path})"
    fi
}

# Prints whether a path would be kept or removed on uninstall, based on the preexisting-path manifest.
dry_run_removal_state() {
    local path="$1"

    if [ ! -e "$path" ] && [ ! -L "$path" ]; then
        info "Absent: ${path}"
    elif path_was_preexisting "$path"; then
        info "Would keep pre-existing path: ${path}"
    else
        warn "Would remove AIO-created path: ${path}"
    fi
}

select_revert_backup_source() {
    if [ ! -d "$BACKUP_ROOT" ]; then
        return 1
    fi

    if [ -d "${BACKUP_ROOT}/_FIRST_STOCK" ] && \
       [ -n "$(ls -A "${BACKUP_ROOT}/_FIRST_STOCK" 2>/dev/null)" ]; then
        printf '%s|%s|%s\n' "first-run stock snapshot" "${BACKUP_ROOT}/_FIRST_STOCK" "true"
        return 0
    fi

    local oldest
    oldest=$(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d \
             -not -name '_*' 2>/dev/null | sort | head -n 1)
    if [ -n "$oldest" ]; then
        printf '%s|%s|%s\n' "oldest timestamped backup" "$oldest" "true"
        return 0
    fi

    printf '%s|%s|%s\n' "flat backup root" "$BACKUP_ROOT" "false"
    return 0
}

# Checks whether key stock config files are present in the selected backup source and warns if any are missing before a restore.
backup_missing_active_stock_essentials() {
    local selected_path="$1"
    local missing=false
    local rel active_path backup_path

    for rel in \
        klipper-macros-qd \
        crowsnest.conf \
        timelapse.cfg \
        printer.cfg \
        box.cfg \
        MCU_ID.cfg; do
        active_path="${CONFIG_DIR}/${rel}"
        backup_path="${selected_path}/${rel}"
        if [ -e "$active_path" ] || [ -L "$active_path" ]; then
            if [ ! -e "$backup_path" ] && [ ! -L "$backup_path" ]; then
                missing=true
            fi
        fi
    done

    [ "$missing" = true ]
}


q2_112_stock_essentials_present() {
    banner "Checking 1.1.2 stock essentials"

    local missing=false
    local rel
    for rel in \
        printer.cfg \
        box.cfg \
        MCU_ID.cfg \
        crowsnest.conf \
        timelapse.cfg \
        klipper-macros-qd; do
        if [ -e "${CONFIG_DIR}/${rel}" ] || [ -L "${CONFIG_DIR}/${rel}" ]; then
            ok "Stock essential present: ${rel}"
        else
            err "Stock essential missing: ${rel}"
            missing=true
        fi
    done

    if [ "$missing" = true ]; then
        err "Cannot capture 1.1.2 baseline because stock essentials are missing."
        return 1
    fi
    return 0
}

q2_112_aio_artifacts_absent() {
    banner "Checking AIO artifact slate"

    local found=false
    local path

    for path in \
        "$HAPPY_HARE_DIR" \
        "$HELIX_DIR" \
        "$HELIX_PRINT_DIR" \
        "$KIAUH_DIR" \
        "$KIAUH_BACKUPS_DIR" \
        "$KIAUH_UPPER_DIR" \
        "$KIAUH_UPPER_BACKUPS_DIR" \
        "$MAINSAIL_DIR" \
        "$Q2_112_PROBE_STATE_DIR" \
        "${CONFIG_DIR}/bunnybox_macros.cfg" \
        "${CONFIG_DIR}/KAMP_settings.cfg" \
        "${CONFIG_DIR}/KAMP_settings.cfg" \
        "${CONFIG_DIR}/Adaptive_Meshing.cfg" \
        "${CONFIG_DIR}/Adaptive_Mesh.cfg" \
        "${CONFIG_DIR}/Line_Purge.cfg" \
        "${CONFIG_DIR}/Smart_Park.cfg" \
        "${CONFIG_DIR}/moonraker.conf.aio-bak" \
        "$Q2_112_LIVE_PROOF_CFG" \
        "$Q2_112_PRESENT_PROOF_MARKER" \
        "$Q2_112_KLIPPER_EXTRAS_PROOF_MARKER" \
        "$Q2_112_MOONRAKER_COMPONENTS_PROOF_MARKER" \
        "$Q2_112_PROBE_CFG"; do
        if [ -e "$path" ] || [ -L "$path" ]; then
            warn "AIO artifact present: ${path}"
            found=true
        fi
    done

    while IFS= read -r -d '' path; do
        warn "AIO/MMU residue present: ${path}"
        found=true
    done < <(
        find "$CONFIG_DIR" -maxdepth 1 \
            \( -name 'mmu' -o -name 'mmu-*' -o -name 'mmu_*' -o -name 'mmu[0-9]*' \
               -o -name 'backup_hh_*' -o -name 'backup_revert_*' -o -name 'backup_mmu_*' \
               -o -name 'backup_bunnybox_*' \
               -o -name 'moonraker.conf.aio-bak' -o -name 'moonraker.conf.bak.helixscreen*' \) \
            -print0 2>/dev/null
    )

    if [ "$found" = true ]; then
        err "Cannot capture 1.1.2 baseline while AIO artifacts are present."
        return 1
    fi

    ok "No AIO install artifacts detected in the guarded capture checks"
    return 0
}

capture_q2_112_stock_baseline() {
    banner "Capture 1.1.2 stock baseline"

    if [ "$AIO_LAYOUT" != "q2_112" ]; then
        err "This capture flow is only for Q2 firmware 1.1.2 / qidi layout."
        return 1
    fi
    q2_112_stock_essentials_present || return 1
    q2_112_aio_artifacts_absent || return 1

    warn "This will quarantine the current ${BACKUP_ROOT}/_FIRST_STOCK"
    warn "and capture a fresh baseline from ${CONFIG_DIR}."
    warn "It does not modify active printer configs or services."
    if ! confirm "Capture a fresh 1.1.2 stock baseline now?"; then
        info "Baseline capture cancelled."
        return 1
    fi

    sudo mkdir -p "$BACKUP_ROOT"
    if [ -e "${BACKUP_ROOT}/_FIRST_STOCK" ] || [ -L "${BACKUP_ROOT}/_FIRST_STOCK" ]; then
        local quarantine
        quarantine="${BACKUP_ROOT}/_FIRST_STOCK.unsafe-q2-112.$(date +%Y%m%d_%H%M%S)"
        if sudo mv "${BACKUP_ROOT}/_FIRST_STOCK" "$quarantine"; then
            ok "Quarantined old _FIRST_STOCK to ${quarantine}"
        else
            err "Could not quarantine existing _FIRST_STOCK"
            return 1
        fi
    fi

    sudo mkdir -p "${BACKUP_ROOT}/_FIRST_STOCK"
    if sudo rsync -a "${CONFIG_DIR}/" "${BACKUP_ROOT}/_FIRST_STOCK/"; then
        ok "Captured fresh 1.1.2 stock baseline: ${BACKUP_ROOT}/_FIRST_STOCK"
    else
        err "Could not capture fresh _FIRST_STOCK baseline"
        return 1
    fi

    local selected selected_label selected_path selected_delete
    if selected=$(select_revert_backup_source); then
        IFS='|' read -r selected_label selected_path selected_delete <<< "$selected"
        if backup_missing_active_stock_essentials "$selected_path"; then
            err "Fresh baseline capture completed, but safety validation still fails."
            return 1
        fi
        ok "Fresh baseline contains active stock essentials"
        info "Selected backup source is now ${selected_label}: ${selected_path}"
    fi
    return 0
}

q2_112_restore_contract_paths() {
    printf '%s\n' \
        "${KLIPPER_DIR}/klippy/extras" \
        "${MOONRAKER_DIR}/moonraker/components" \
        "$HAPPY_HARE_DIR" \
        "$HELIX_DIR" \
        "$HELIX_PRINT_DIR" \
        "${AIO_HOME}/.config/helixscreen" \
        /opt/helixscreen \
        /var/lib/helixscreen \
        /var/log/helixscreen \
        /root/.helixscreen \
        /etc/systemd/system/default.target \
        "/etc/systemd/system/${STOCK_UI_SERVICE}.service" \
        "/etc/systemd/system/${STOCK_UI_SERVICE}.service.d" \
        /etc/systemd/system/helixscreen.service \
        /etc/systemd/system/helixscreen.service.d \
        /etc/systemd/system/helixscreen-update.path \
        /etc/systemd/system/helixscreen-update.service \
        /etc/udev/rules.d/99-helixscreen-backlight.rules \
        /etc/polkit-1/localauthority/50-local.d/helixscreen-network.pkla \
        /etc/polkit-1/rules.d/49-helixscreen-network.rules \
        /etc/polkit-1/rules.d/50-helixscreen-network.rules
}

q2_112_restore_contract_services() {
    printf '%s\n' \
        "$STOCK_UI_SERVICE" \
        crowsnest \
        klipper \
        moonraker \
        qidi-tuning \
        helixscreen
}

q2_112_contract_path_state_line() {
    local path="$1"
    local kind mode uid gid target=""

    if [ -L "$path" ]; then
        kind="symlink"
        target=$(sudo readlink "$path" 2>/dev/null || printf 'unknown')
    elif [ -d "$path" ]; then
        kind="directory"
    elif [ -f "$path" ]; then
        kind="file"
    elif [ -e "$path" ]; then
        kind="other"
    else
        printf 'absent|||||%s|\n' "$path"
        return 0
    fi

    IFS='|' read -r mode uid gid < <(
        sudo stat -c '%a|%u|%g' "$path" 2>/dev/null || printf 'unknown|unknown|unknown\n'
    )
    printf 'present|%s|%s|%s|%s|%s|%s\n' \
        "$kind" "$mode" "$uid" "$gid" "$path" "$target"
}

q2_112_contract_service_state_line() {
    local service="$1"
    local exists="false" enabled active fragment

    if systemctl cat "$service" >/dev/null 2>&1; then
        exists="true"
    fi
    enabled=$(systemctl is-enabled "$service" 2>/dev/null || true)
    active=$(systemctl is-active "$service" 2>/dev/null || true)
    enabled="${enabled:-not-found}"
    active="${active:-inactive}"
    fragment=$(systemctl show "$service" -p FragmentPath --value 2>/dev/null || true)
    printf '%s|%s|%s|%s|%s\n' "$service" "$exists" "$enabled" "$active" "$fragment"
}

write_q2_112_contract_tree_hashes() {
    local tree="$1"
    local output="$2"

    sudo sh -c '
        cd "$1" || exit 1
        find . -type f -print0 | sort -z | xargs -0 -r sha256sum > "$2"
    ' sh "$tree" "$output"
}

write_q2_112_contract_tree_inventory() {
    local tree="$1"
    local output="$2"

    sudo sh -c '
        cd "$1" || exit 1
        find . -printf "%y|%m|%U|%G|%s|%T@|%p|%l\n" | LC_ALL=C sort > "$2"
    ' sh "$tree" "$output"
}

verify_q2_112_contract_tree_inventory() {
    local tree="$1"
    local inventory="$2"

    sudo sh -c '
        cd "$1" || exit 1
        find . -printf "%y|%m|%U|%G|%s|%T@|%p|%l\n" | LC_ALL=C sort | cmp -s - "$2"
    ' sh "$tree" "$inventory"
}

validate_q2_112_restore_contract() {
    local contract_dir="${1:-$Q2_112_CONTRACT_DIR}"
    local manifest="${contract_dir}/manifest"
    local path_states="${contract_dir}/path_states"
    local services="${contract_dir}/services"
    local config_hashes="${contract_dir}/config.sha256"
    local external_hashes="${contract_dir}/external.sha256"
    local config_inventory="${contract_dir}/config.inventory"
    local external_inventory="${contract_dir}/external.inventory"
    local packages="${contract_dir}/packages"
    local contract_hashes="${contract_dir}/contract.sha256"
    local complete="${contract_dir}/COMPLETE"
    local config_tree="${contract_dir}/config"
    local external_tree="${contract_dir}/external"

    [ -f "$complete" ] || return 1
    [ -f "$manifest" ] || return 1
    [ -f "$path_states" ] || return 1
    [ -f "$services" ] || return 1
    [ -f "$config_hashes" ] || return 1
    [ -f "$external_hashes" ] || return 1
    [ -f "$config_inventory" ] || return 1
    [ -f "$external_inventory" ] || return 1
    [ -s "$packages" ] || return 1
    [ -s "$contract_hashes" ] || return 1
    [ -d "$config_tree" ] || return 1
    [ -d "$external_tree" ] || return 1
    grep -Fqx 'CONTRACT_SCHEMA=1' "$manifest" 2>/dev/null || return 1
    grep -Fqx 'AIO_LAYOUT=q2_112' "$manifest" 2>/dev/null || return 1
    grep -Fqx "CONFIG_DIR=${CONFIG_DIR}" "$manifest" 2>/dev/null || return 1
    [ -s "$path_states" ] || return 1
    [ -s "$services" ] || return 1
    [ -s "$config_hashes" ] || return 1

    sudo sh -c 'cd "$1" && sha256sum -c contract.sha256 >/dev/null' \
        sh "$contract_dir" || return 1
    sudo sh -c 'cd "$1" && sha256sum -c "$2" >/dev/null' \
        sh "$config_tree" "$config_hashes" || return 1
    if [ -s "$external_hashes" ]; then
        sudo sh -c 'cd "$1" && sha256sum -c "$2" >/dev/null' \
            sh "$external_tree" "$external_hashes" || return 1
    fi
    verify_q2_112_contract_tree_inventory "$config_tree" "$config_inventory" || return 1
    verify_q2_112_contract_tree_inventory "$external_tree" "$external_inventory" || return 1

    local rel
    for rel in printer.cfg box.cfg MCU_ID.cfg crowsnest.conf timelapse.cfg klipper-macros-qd; do
        if [ ! -e "${config_tree}/${rel}" ] && [ ! -L "${config_tree}/${rel}" ]; then
            return 1
        fi
    done
    return 0
}

capture_q2_112_restore_contract() {
    banner "Capture 1.1.2 restore contract"

    if [ "$AIO_LAYOUT" != "q2_112" ]; then
        err "The restore contract is only available on Q2 firmware 1.1.2 / qidi layout."
        return 1
    fi
    q2_112_stock_essentials_present || return 1
    q2_112_aio_artifacts_absent || return 1
    q2_112_baseline_safe || return 1

    if validate_q2_112_restore_contract; then
        ok "A complete, verified 1.1.2 restore contract already exists."
        info "Contract: ${Q2_112_CONTRACT_DIR}"
        return 0
    fi

    warn "This captures recovery material for every currently mapped Option 1 mutation surface:"
    warn "  exact Klipper config tree; Klipper extras; Moonraker components;"
    warn "  display/runtime paths; system integration paths; and service states."
    warn "  It also records the installed Debian package inventory for later comparison."
    warn "It records both present and absent paths so a future restore can remove only AIO additions."
    warn "It does not modify active printer configs or service states."
    if ! confirm "Capture the guarded 1.1.2 restore contract now?"; then
        info "Restore contract capture cancelled."
        return 1
    fi

    local staging="${Q2_112_CONTRACT_DIR}.staging.$$"
    local quarantine path service default_target
    sudo rm -rf "$staging"
    sudo mkdir -p "${staging}/config" "${staging}/external" || {
        err "Could not create restore contract staging directory."
        return 1
    }

    if [ -e "$Q2_112_CONTRACT_DIR" ] || [ -L "$Q2_112_CONTRACT_DIR" ]; then
        quarantine="${Q2_112_CONTRACT_DIR}.invalid.$(date +%Y%m%d_%H%M%S)"
        if sudo mv "$Q2_112_CONTRACT_DIR" "$quarantine"; then
            warn "Quarantined incomplete restore contract: ${quarantine}"
        else
            err "Could not quarantine incomplete restore contract."
            sudo rm -rf "$staging"
            return 1
        fi
    fi

    if ! sudo rsync -aHAX --numeric-ids "${CONFIG_DIR}/" "${staging}/config/"; then
        err "Could not capture exact stock config tree."
        sudo rm -rf "$staging"
        return 1
    fi

    sudo tee "${staging}/path_states" >/dev/null < /dev/null
    while IFS= read -r path; do
        q2_112_contract_path_state_line "$path" | sudo tee -a "${staging}/path_states" >/dev/null
        if [ -e "$path" ] || [ -L "$path" ]; then
            if ! sudo rsync -aHAX --numeric-ids --relative "$path" "${staging}/external/"; then
                err "Could not capture mapped path: ${path}"
                sudo rm -rf "$staging"
                return 1
            fi
        fi
    done < <(q2_112_restore_contract_paths)

    sudo tee "${staging}/services" >/dev/null < /dev/null
    while IFS= read -r service; do
        q2_112_contract_service_state_line "$service" | sudo tee -a "${staging}/services" >/dev/null
    done < <(q2_112_restore_contract_services)

    if ! dpkg-query -W -f='${binary:Package}|${Version}|${db:Status-Abbrev}\n' 2>/dev/null | \
        LC_ALL=C sort | sudo tee "${staging}/packages" >/dev/null; then
        err "Could not capture installed Debian package inventory."
        sudo rm -rf "$staging"
        return 1
    fi

    default_target=$(systemctl get-default 2>/dev/null || printf 'unknown')
    if ! sudo tee "${staging}/manifest" >/dev/null <<EOF
CONTRACT_SCHEMA=1
AIO_VERSION=${AIO_VERSION}
AIO_LAYOUT=${AIO_LAYOUT}
AIO_HOME=${AIO_HOME}
CONFIG_DIR=${CONFIG_DIR}
STOCK_UI_SERVICE=${STOCK_UI_SERVICE}
DEFAULT_TARGET=${default_target}
CAPTURED_AT=$(date -Iseconds)
EOF
    then
        err "Could not write restore contract manifest."
        sudo rm -rf "$staging"
        return 1
    fi

    write_q2_112_contract_tree_hashes "${staging}/config" "${staging}/config.sha256" || {
        err "Could not hash captured stock config tree."
        sudo rm -rf "$staging"
        return 1
    }
    write_q2_112_contract_tree_hashes "${staging}/external" "${staging}/external.sha256" || {
        err "Could not hash captured external recovery files."
        sudo rm -rf "$staging"
        return 1
    }
    write_q2_112_contract_tree_inventory "${staging}/config" "${staging}/config.inventory" || {
        err "Could not inventory captured stock config metadata."
        sudo rm -rf "$staging"
        return 1
    }
    write_q2_112_contract_tree_inventory "${staging}/external" "${staging}/external.inventory" || {
        err "Could not inventory captured external recovery metadata."
        sudo rm -rf "$staging"
        return 1
    }
    sudo tee "${staging}/COMPLETE" >/dev/null <<EOF
Q2 1.1.2 restore contract capture complete
EOF
    if ! sudo sh -c '
        cd "$1" || exit 1
        sha256sum manifest path_states services packages config.sha256 external.sha256 \
            config.inventory external.inventory COMPLETE > contract.sha256
    ' sh "$staging"; then
        err "Could not seal restore contract metadata."
        sudo rm -rf "$staging"
        return 1
    fi

    if ! validate_q2_112_restore_contract "$staging"; then
        err "Restore contract integrity validation failed; staging data was kept for inspection."
        warn "Inspect: ${staging}"
        return 1
    fi
    if ! sudo mv "$staging" "$Q2_112_CONTRACT_DIR"; then
        err "Could not activate verified restore contract."
        return 1
    fi

    ok "Verified 1.1.2 restore contract captured atomically."
    info "Contract: ${Q2_112_CONTRACT_DIR}"
    info "Full install and general real revert remain blocked while the 1.1.2 compatibility lane is tested."
    return 0
}

report_q2_112_restore_contract() {
    banner "1.1.2 restore contract"

    if ! validate_q2_112_restore_contract; then
        warn "No complete, verified 1.1.2 restore contract is available."
        info "Option 4 can capture one after the guarded stock baseline passes."
        return 1
    fi

    ok "Restore contract integrity verified: ${Q2_112_CONTRACT_DIR}"
    info "Exact config restore source: ${Q2_112_CONTRACT_DIR}/config"
    info "Config restore would use rsync -aHAX --numeric-ids --delete"
    info "Captured Debian package count: $(wc -l < "${Q2_112_CONTRACT_DIR}/packages" | tr -d ' ')"
    local package_diff
    package_diff=$(comm -13 "${Q2_112_CONTRACT_DIR}/packages" <(
        dpkg-query -W -f='${binary:Package}|${Version}|${db:Status-Abbrev}\n' 2>/dev/null | LC_ALL=C sort
    ) || true)
    if [ -n "$package_diff" ]; then
        warn "Current package entries not present in the stock contract:"
        local package_entry
        while IFS= read -r package_entry; do
            warn "  ${package_entry}"
        done <<< "$package_diff"
    else
        ok "Current Debian package inventory matches the captured stock contract"
    fi

    local current_default captured_default
    current_default=$(systemctl get-default 2>/dev/null || printf 'unknown')
    captured_default=$(sed -n 's/^DEFAULT_TARGET=//p' "${Q2_112_CONTRACT_DIR}/manifest" | head -n 1)
    if [ "$current_default" = "$captured_default" ]; then
        ok "Default boot target matches capture: ${captured_default}"
    else
        warn "Would restore default boot target from ${current_default} to ${captured_default}"
    fi

    banner "Restore contract service-state preview"
    local service exists captured_enabled captured_active fragment current_enabled current_active
    while IFS='|' read -r service exists captured_enabled captured_active fragment; do
        current_enabled=$(systemctl is-enabled "$service" 2>/dev/null || true)
        current_active=$(systemctl is-active "$service" 2>/dev/null || true)
        current_enabled="${current_enabled:-not-found}"
        current_active="${current_active:-inactive}"
        if [ "$service" = "qidi-tuning" ] && \
           { [ "$captured_active" = "active" ] || [ "$captured_active" = "activating" ]; } && \
           { [ "$current_active" = "active" ] || [ "$current_active" = "activating" ]; } && \
           [ "$captured_enabled" = "$current_enabled" ]; then
            ok "${service}: captured/current healthy (enabled=${captured_enabled}, active=${captured_active}/${current_active})"
        elif [ "$captured_enabled" = "$current_enabled" ] && [ "$captured_active" = "$current_active" ]; then
            ok "${service}: captured/current enabled=${captured_enabled}, active=${captured_active}"
        else
            warn "${service}: captured enabled=${captured_enabled}, active=${captured_active}; current enabled=${current_enabled}, active=${current_active}"
        fi
    done < "$Q2_112_CONTRACT_SERVICES"

    banner "Restore contract path-state preview"
    local captured kind mode uid gid target
    while IFS='|' read -r captured kind mode uid gid path target; do
        if [ "$captured" = "absent" ]; then
            if [ -e "$path" ] || [ -L "$path" ]; then
                warn "Would remove path absent at capture: ${path}"
            else
                ok "Still absent as captured: ${path}"
            fi
        elif [ -e "$path" ] || [ -L "$path" ]; then
            info "Would restore captured ${kind}: ${path}"
        else
            warn "Would restore missing captured ${kind}: ${path}"
        fi
    done < "$Q2_112_CONTRACT_PATH_STATES"
    return 0
}

report_q2_112_external_restore_audit() {
    banner "Q2 1.1.2 external restore audit (read-only)"

    if [ "$AIO_LAYOUT" != "q2_112" ]; then
        err "The external restore audit is only available on Q2 firmware 1.1.2 / qidi layout."
        return 1
    fi
    if ! validate_q2_112_restore_contract; then
        err "No complete, verified restore contract is available."
        info "Run option 4 to capture and validate the restore contract first."
        return 1
    fi

    warn "This compares live external paths with the sealed stock contract."
    warn "It uses rsync --dry-run only; no files, packages, services, or boot targets are changed."

    local captured kind mode uid gid path target source destination changes change
    local exact=0 drift=0 absent_ok=0 unexpected=0 missing=0 errors=0 shown total
    while IFS='|' read -r captured kind mode uid gid path target; do
        source="${Q2_112_CONTRACT_DIR}/external${path}"
        if [ "$captured" = "absent" ]; then
            if [ -e "$path" ] || [ -L "$path" ]; then
                warn "Captured absent but currently present: ${path}"
                unexpected=$((unexpected + 1))
            else
                ok "Still absent as captured: ${path}"
                absent_ok=$((absent_ok + 1))
            fi
            continue
        fi

        if [ ! -e "$path" ] && [ ! -L "$path" ]; then
            warn "Captured ${kind} is currently missing: ${path}"
            missing=$((missing + 1))
            continue
        fi
        if [ ! -e "$source" ] && [ ! -L "$source" ]; then
            err "Contract source is missing for captured ${kind}: ${source}"
            errors=$((errors + 1))
            continue
        fi

        case "$kind" in
            directory)
                if [ ! -d "$path" ] || [ -L "$path" ] || \
                   [ ! -d "$source" ] || [ -L "$source" ]; then
                    warn "Captured directory changed type or contract source is invalid: ${path}"
                    errors=$((errors + 1))
                    continue
                fi
                if ! changes=$(sudo rsync -aHAX --numeric-ids --checksum --delete --dry-run --itemize-changes \
                    "${source}/" "${path}/" 2>&1); then
                    err "Could not audit captured directory: ${path}"
                    errors=$((errors + 1))
                    continue
                fi
                ;;
            file)
                if [ ! -f "$path" ] || [ -L "$path" ] || \
                   [ ! -f "$source" ] || [ -L "$source" ]; then
                    warn "Captured file changed type or contract source is invalid: ${path}"
                    errors=$((errors + 1))
                    continue
                fi
                destination=$(dirname "$path")
                if ! changes=$(sudo rsync -aHAX --numeric-ids --checksum --dry-run --itemize-changes \
                    "$source" "${destination}/" 2>&1); then
                    err "Could not audit captured file: ${path}"
                    errors=$((errors + 1))
                    continue
                fi
                ;;
            symlink)
                if [ ! -L "$path" ] || [ ! -L "$source" ]; then
                    warn "Captured symlink changed type or contract source is invalid: ${path}"
                    errors=$((errors + 1))
                    continue
                fi
                destination=$(dirname "$path")
                if ! changes=$(sudo rsync -aHAX --numeric-ids --checksum --dry-run --itemize-changes \
                    "$source" "${destination}/" 2>&1); then
                    err "Could not audit captured symlink: ${path}"
                    errors=$((errors + 1))
                    continue
                fi
                ;;
            *)
                warn "Captured path kind requires manual review (${kind}): ${path}"
                errors=$((errors + 1))
                continue
                ;;
        esac

        if [ -z "$changes" ]; then
            ok "Exact external contract match: ${path}"
            exact=$((exact + 1))
            continue
        fi

        total=$(printf '%s\n' "$changes" | wc -l | tr -d ' ')
        warn "External contract drift: ${path} (${total} rsync change item(s))"
        shown=0
        while IFS= read -r change; do
            [ -n "$change" ] || continue
            warn "  ${change}"
            shown=$((shown + 1))
            [ "$shown" -ge 8 ] && break
        done <<< "$changes"
        if [ "$total" -gt "$shown" ]; then
            warn "  ... $((total - shown)) additional change item(s)"
        fi
        drift=$((drift + 1))
    done < "$Q2_112_CONTRACT_PATH_STATES"

    banner "External restore audit summary"
    info "Exact captured-present paths: ${exact}"
    info "Drifted captured-present paths: ${drift}"
    info "Missing captured-present paths: ${missing}"
    info "Captured-absent paths still absent: ${absent_ok}"
    info "Captured-absent paths now present: ${unexpected}"
    info "Audit errors/manual-review paths: ${errors}"
    if [ "$drift" -eq 0 ] && [ "$missing" -eq 0 ] && \
       [ "$unexpected" -eq 0 ] && [ "$errors" -eq 0 ]; then
        ok "All mapped external paths exactly match the sealed stock contract"
    else
        warn "Do not enable general real revert until every reported external-path change is classified."
    fi
    return 0
}

menu_q2_112_external_restore_audit() {
    report_q2_112_external_restore_audit
    press_enter
}

q2_112_external_paths_match_contract() {
    local captured kind mode uid gid path target source destination changes

    while IFS='|' read -r captured kind mode uid gid path target; do
        source="${Q2_112_CONTRACT_DIR}/external${path}"
        if [ "$captured" = "absent" ]; then
            [ ! -e "$path" ] && [ ! -L "$path" ] || return 1
            continue
        fi
        [ -e "$path" ] || [ -L "$path" ] || return 1
        [ -e "$source" ] || [ -L "$source" ] || return 1

        case "$kind" in
            directory)
                [ -d "$path" ] && [ ! -L "$path" ] || return 1
                [ -d "$source" ] && [ ! -L "$source" ] || return 1
                changes=$(sudo rsync -aHAX --numeric-ids --checksum --delete --dry-run --itemize-changes \
                    "${source}/" "${path}/" 2>/dev/null) || return 1
                ;;
            file)
                [ -f "$path" ] && [ ! -L "$path" ] || return 1
                [ -f "$source" ] && [ ! -L "$source" ] || return 1
                destination=$(dirname "$path")
                changes=$(sudo rsync -aHAX --numeric-ids --checksum --dry-run --itemize-changes \
                    "$source" "${destination}/" 2>/dev/null) || return 1
                ;;
            symlink)
                [ -L "$path" ] && [ -L "$source" ] || return 1
                destination=$(dirname "$path")
                changes=$(sudo rsync -aHAX --numeric-ids --checksum --dry-run --itemize-changes \
                    "$source" "${destination}/" 2>/dev/null) || return 1
                ;;
            *)
                return 1
                ;;
        esac
        [ -z "$changes" ] || return 1
    done < "$Q2_112_CONTRACT_PATH_STATES"
    return 0
}

write_q2_112_service_restore_plan() {
    local output="$1"
    local service exists enabled active fragment

    sudo tee "$output" >/dev/null < /dev/null
    while IFS='|' read -r service exists enabled active fragment; do
        if [ "$exists" = "false" ]; then
            printf 'REMOVE_IF_AIO_CREATED|%s|captured unit absent\n' "$service"
            continue
        fi

        case "$enabled" in
            enabled|enabled-runtime|linked|linked-runtime)
                printf 'ENABLE|%s|captured enabled=%s\n' "$service" "$enabled"
                ;;
            masked|masked-runtime)
                printf 'MASK|%s|captured enabled=%s\n' "$service" "$enabled"
                ;;
            disabled)
                printf 'DISABLE|%s|captured disabled\n' "$service"
                ;;
            static|indirect|generated|transient|alias)
                printf 'PRESERVE_ENABLEMENT|%s|captured enabled=%s\n' "$service" "$enabled"
                ;;
            *)
                printf 'REVIEW_ENABLEMENT|%s|captured enabled=%s\n' "$service" "$enabled"
                ;;
        esac

        case "$active" in
            active|activating|reloading)
                printf 'START|%s|captured active=%s\n' "$service" "$active"
                ;;
            *)
                printf 'STOP|%s|captured active=%s\n' "$service" "$active"
                ;;
        esac
        printf 'FRAGMENT|%s|%s\n' "$service" "$fragment"
    done < "$Q2_112_CONTRACT_SERVICES" | sudo tee -a "$output" >/dev/null
}

write_q2_112_path_restore_plan() {
    local output="$1"
    local captured kind mode uid gid path target source

    printf 'RESTORE_CONFIG_TREE|%s|source=%s|rsync=-aHAX --numeric-ids --delete\n' \
        "$CONFIG_DIR" "${Q2_112_CONTRACT_DIR}/config" | sudo tee "$output" >/dev/null
    while IFS='|' read -r captured kind mode uid gid path target; do
        if [ "$captured" = "absent" ]; then
            printf 'REMOVE_IF_PRESENT|%s|captured absent\n' "$path"
            continue
        fi

        source="${Q2_112_CONTRACT_DIR}/external${path}"
        printf 'RESTORE|%s|%s|mode=%s|uid=%s|gid=%s|source=%s|target=%s\n' \
            "$kind" "$path" "$mode" "$uid" "$gid" "$source" "$target"
    done < "$Q2_112_CONTRACT_PATH_STATES" | sudo tee -a "$output" >/dev/null
}

write_q2_112_rehearsal_live_guard() {
    local output_dir="$1"

    write_q2_112_contract_tree_hashes "$CONFIG_DIR" "${output_dir}/active-config.sha256" || return 1
    write_q2_112_contract_tree_inventory "$CONFIG_DIR" "${output_dir}/active-config.inventory" || return 1
    q2_112_restore_contract_services | while IFS= read -r service; do
        local enabled fragment
        enabled=$(systemctl is-enabled "$service" 2>/dev/null || true)
        enabled="${enabled:-not-found}"
        fragment=$(systemctl show "$service" -p FragmentPath --value 2>/dev/null || true)
        printf '%s|%s|%s\n' "$service" "$enabled" "$fragment"
    done | sudo tee "${output_dir}/service-enablements" >/dev/null
    systemctl get-default 2>/dev/null | sudo tee "${output_dir}/default-target" >/dev/null
    dpkg-query -W -f='${binary:Package}|${Version}|${db:Status-Abbrev}\n' 2>/dev/null | \
        LC_ALL=C sort | sudo tee "${output_dir}/packages" >/dev/null
}

q2_112_restore_rehearsal_passed() {
    local pass_file="${Q2_112_REHEARSAL_DIR}/PASS"
    local expected_seal current_seal
    local rehearsal_config="${Q2_112_REHEARSAL_DIR}/reconstructed/config"
    local rehearsal_external="${Q2_112_REHEARSAL_DIR}/reconstructed/external"
    local rehearsal_plans="${Q2_112_REHEARSAL_DIR}/plans"
    local before_dir="${Q2_112_REHEARSAL_DIR}/checks/before"
    local after_dir="${Q2_112_REHEARSAL_DIR}/checks/after"

    [ -f "$pass_file" ] || return 1
    validate_q2_112_restore_contract || return 1
    expected_seal=$(sed -n 's/^CONTRACT_SEAL_SHA256=//p' "$pass_file" 2>/dev/null | head -n 1)
    current_seal=$(file_sha256 "${Q2_112_CONTRACT_DIR}/contract.sha256")
    [ -n "$expected_seal" ] && [ "$expected_seal" = "$current_seal" ] || return 1
    [ -s "${rehearsal_plans}/services.plan" ] || return 1
    [ -s "${rehearsal_plans}/paths.plan" ] || return 1
    [ -s "${rehearsal_plans}/packages.stock" ] || return 1
    [ -s "${rehearsal_plans}/plans.sha256" ] || return 1
    sudo sh -c 'cd "$1" && sha256sum -c plans.sha256 >/dev/null' \
        sh "$rehearsal_plans" || return 1
    sudo sh -c 'cd "$1" && sha256sum -c "$2" >/dev/null' \
        sh "$rehearsal_config" "${Q2_112_CONTRACT_DIR}/config.sha256" || return 1
    if [ -s "${Q2_112_CONTRACT_DIR}/external.sha256" ]; then
        sudo sh -c 'cd "$1" && sha256sum -c "$2" >/dev/null' \
            sh "$rehearsal_external" "${Q2_112_CONTRACT_DIR}/external.sha256" || return 1
    fi
    verify_q2_112_contract_tree_inventory \
        "$rehearsal_config" "${Q2_112_CONTRACT_DIR}/config.inventory" || return 1
    verify_q2_112_contract_tree_inventory \
        "$rehearsal_external" "${Q2_112_CONTRACT_DIR}/external.inventory" || return 1
    verify_q2_112_rehearsal_live_guard "$before_dir" "$after_dir"
}

verify_q2_112_rehearsal_live_guard() {
    local before_dir="$1"
    local after_dir="$2"
    local item

    for item in active-config.sha256 active-config.inventory service-enablements default-target packages; do
        if ! sudo cmp -s "${before_dir}/${item}" "${after_dir}/${item}"; then
            err "Restore rehearsal live-state guard changed: ${item}"
            return 1
        fi
    done
    return 0
}

run_q2_112_restore_rehearsal() {
    banner "Q2 1.1.2 contract-backed restore rehearsal"

    if [ "$AIO_LAYOUT" != "q2_112" ]; then
        err "The restore rehearsal is only available on Q2 firmware 1.1.2 / qidi layout."
        return 1
    fi
    if ! validate_q2_112_restore_contract; then
        err "No complete, verified restore contract is available."
        info "Run option 4 to capture and validate the restore contract first."
        return 1
    fi

    warn "This reconstructs the sealed contract only under:"
    warn "  ${Q2_112_REHEARSAL_DIR}"
    warn "It will not write to active configs, /home/qidi runtime trees, /etc, packages, or services."
    if ! confirm "Run the isolated restore rehearsal now?"; then
        info "Restore rehearsal cancelled."
        return 1
    fi

    local before_dir="${Q2_112_REHEARSAL_DIR}/checks/before"
    local after_dir="${Q2_112_REHEARSAL_DIR}/checks/after"
    local rehearsal_config="${Q2_112_REHEARSAL_DIR}/reconstructed/config"
    local rehearsal_external="${Q2_112_REHEARSAL_DIR}/reconstructed/external"
    local rehearsal_plans="${Q2_112_REHEARSAL_DIR}/plans"

    sudo rm -rf "$Q2_112_REHEARSAL_DIR"
    sudo mkdir -p "$before_dir" "$after_dir" "$rehearsal_plans" \
        "${Q2_112_REHEARSAL_DIR}/reconstructed" || {
        err "Could not create isolated restore rehearsal workspace."
        return 1
    }

    banner "Sealing live-state guard"
    write_q2_112_rehearsal_live_guard "$before_dir" || {
        err "Could not capture the pre-rehearsal live-state guard."
        return 1
    }
    ok "Pre-rehearsal active config, service enablement, target, and package state sealed"

    banner "Reconstructing contract in isolation"
    if ! sudo rsync -aHAX --numeric-ids "${Q2_112_CONTRACT_DIR}/config" \
        "${Q2_112_REHEARSAL_DIR}/reconstructed/"; then
        err "Could not reconstruct the config contract tree."
        return 1
    fi
    if ! sudo rsync -aHAX --numeric-ids "${Q2_112_CONTRACT_DIR}/external" \
        "${Q2_112_REHEARSAL_DIR}/reconstructed/"; then
        err "Could not reconstruct the external contract tree."
        return 1
    fi
    ok "Contract trees reconstructed under isolated rehearsal workspace"

    banner "Verifying reconstructed contract"
    sudo sh -c 'cd "$1" && sha256sum -c "$2" >/dev/null' \
        sh "$rehearsal_config" "${Q2_112_CONTRACT_DIR}/config.sha256" || {
        err "Reconstructed config file hashes do not match the sealed contract."
        return 1
    }
    if [ -s "${Q2_112_CONTRACT_DIR}/external.sha256" ]; then
        sudo sh -c 'cd "$1" && sha256sum -c "$2" >/dev/null' \
            sh "$rehearsal_external" "${Q2_112_CONTRACT_DIR}/external.sha256" || {
            err "Reconstructed external file hashes do not match the sealed contract."
            return 1
        }
    fi
    verify_q2_112_contract_tree_inventory \
        "$rehearsal_config" "${Q2_112_CONTRACT_DIR}/config.inventory" || {
        err "Reconstructed config metadata does not match the sealed contract."
        return 1
    }
    verify_q2_112_contract_tree_inventory \
        "$rehearsal_external" "${Q2_112_CONTRACT_DIR}/external.inventory" || {
        err "Reconstructed external metadata does not match the sealed contract."
        return 1
    }
    ok "Reconstructed file contents, ownership, permissions, timestamps, and symlinks match"

    banner "Generating non-executing restore plans"
    write_q2_112_service_restore_plan "${rehearsal_plans}/services.plan" || return 1
    write_q2_112_path_restore_plan "${rehearsal_plans}/paths.plan" || return 1
    sudo tee "${rehearsal_plans}/packages.stock" >/dev/null < "${Q2_112_CONTRACT_DIR}/packages" || return 1
    if [ ! -s "${rehearsal_plans}/services.plan" ] || \
       [ ! -s "${rehearsal_plans}/paths.plan" ] || \
       [ ! -s "${rehearsal_plans}/packages.stock" ]; then
        err "One or more generated restore plans are empty."
        return 1
    fi
    if ! sudo sh -c '
        cd "$1" || exit 1
        sha256sum services.plan paths.plan packages.stock > plans.sha256
    ' sh "$rehearsal_plans"; then
        err "Could not seal generated restore plans."
        return 1
    fi
    ok "Service, path, absent-path, and stock-package plans generated"
    info "Plans: ${rehearsal_plans}"

    banner "Verifying live printer was untouched"
    write_q2_112_rehearsal_live_guard "$after_dir" || {
        err "Could not capture the post-rehearsal live-state guard."
        return 1
    }
    if ! verify_q2_112_rehearsal_live_guard "$before_dir" "$after_dir"; then
        err "Restore rehearsal failed: live printer state changed during the rehearsal."
        return 1
    fi

    ok "Restore rehearsal passed: reconstructed contract exactly matches the sealed source"
    ok "Live active config, service enablement, default target, and package inventory are unchanged"
    sudo tee "${Q2_112_REHEARSAL_DIR}/PASS" >/dev/null <<EOF
AIO_VERSION=${AIO_VERSION}
CONTRACT_DIR=${Q2_112_CONTRACT_DIR}
CONTRACT_SEAL_SHA256=$(file_sha256 "${Q2_112_CONTRACT_DIR}/contract.sha256")
REHEARSED_AT=$(date -Iseconds)
EOF
    info "Full install and general real revert remain blocked."
    return 0
}

menu_q2_112_restore_rehearsal() {
    run_q2_112_restore_rehearsal
    press_enter
}

verify_q2_112_active_config_matches_contract() {
    sudo sh -c 'cd "$1" && sha256sum -c "$2" >/dev/null' \
        sh "$CONFIG_DIR" "${Q2_112_CONTRACT_DIR}/config.sha256" || return 1
    verify_q2_112_contract_tree_inventory \
        "$CONFIG_DIR" "${Q2_112_CONTRACT_DIR}/config.inventory"
}

q2_112_contract_path_was_absent() {
    local path="$1"
    awk -F'|' -v wanted="$path" '$1 == "absent" && $6 == wanted { found=1 } END { exit !found }' \
        "$Q2_112_CONTRACT_PATH_STATES"
}

q2_112_contract_path_was_present_directory() {
    local path="$1"
    awk -F'|' -v wanted="$path" \
        '$1 == "present" && $2 == "directory" && $6 == wanted { found=1 } END { exit !found }' \
        "$Q2_112_CONTRACT_PATH_STATES"
}

remove_q2_112_live_proof_external_path() {
    local expected_token="${1:-}"
    local marker_token=""

    q2_112_contract_path_was_absent "$Q2_112_LIVE_PROOF_EXTERNAL_DIR" || return 1
    [ ! -L "$Q2_112_LIVE_PROOF_EXTERNAL_DIR" ] || return 1
    [ -d "$Q2_112_LIVE_PROOF_EXTERNAL_DIR" ] || return 0
    if [ -f "$Q2_112_LIVE_PROOF_EXTERNAL_MARKER" ]; then
        marker_token=$(sudo cat "$Q2_112_LIVE_PROOF_EXTERNAL_MARKER" 2>/dev/null || true)
        [ -z "$expected_token" ] || [ "$marker_token" = "$expected_token" ] || return 1
    elif [ -n "$expected_token" ]; then
        sudo rmdir "$Q2_112_LIVE_PROOF_EXTERNAL_DIR" 2>/dev/null
        return $?
    fi
    if sudo find "$Q2_112_LIVE_PROOF_EXTERNAL_DIR" -mindepth 1 \
        ! -path "$Q2_112_LIVE_PROOF_EXTERNAL_MARKER" -print -quit | grep -q .; then
        return 1
    fi
    sudo rm -rf "$Q2_112_LIVE_PROOF_EXTERNAL_DIR"
}

rollback_q2_112_live_restore_proof() {
    local emergency_config="${Q2_112_LIVE_PROOF_DIR}/emergency/config"
    local expected_token="${1:-}"

    warn "Rolling back the controlled live restore proof"
    if [ -d "$emergency_config" ]; then
        sudo rsync -aHAX --numeric-ids --delete "${emergency_config}/" "${CONFIG_DIR}/" || \
            err "Emergency config rollback failed; inspect ${emergency_config}"
    fi
    if [ -e "$Q2_112_LIVE_PROOF_EXTERNAL_DIR" ] || [ -L "$Q2_112_LIVE_PROOF_EXTERNAL_DIR" ]; then
        remove_q2_112_live_proof_external_path "$expected_token" || \
            warn "External proof path contains unexpected state; inspect ${Q2_112_LIVE_PROOF_EXTERNAL_DIR}"
    fi
}

q2_112_live_restore_proof_passed() {
    local pass_file="${Q2_112_LIVE_PROOF_DIR}/PASS"
    local expected_seal current_seal
    local before_dir="${Q2_112_LIVE_PROOF_DIR}/checks/before"
    local after_dir="${Q2_112_LIVE_PROOF_DIR}/checks/after"

    [ -f "$pass_file" ] || return 1
    validate_q2_112_restore_contract || return 1
    q2_112_restore_rehearsal_passed || return 1
    expected_seal=$(sed -n 's/^CONTRACT_SEAL_SHA256=//p' "$pass_file" 2>/dev/null | head -n 1)
    current_seal=$(file_sha256 "${Q2_112_CONTRACT_DIR}/contract.sha256")
    [ -n "$expected_seal" ] && [ "$expected_seal" = "$current_seal" ] || return 1
    [ ! -e "$Q2_112_LIVE_PROOF_CFG" ] || return 1
    [ ! -e "$Q2_112_LIVE_PROOF_EXTERNAL_MARKER" ] || return 1
    verify_q2_112_rehearsal_live_guard "$before_dir" "$after_dir"
}

run_q2_112_live_restore_proof() {
    banner "Q2 1.1.2 controlled live restore proof"

    if [ "$AIO_LAYOUT" != "q2_112" ]; then
        err "The controlled live restore proof is only available on Q2 firmware 1.1.2 / qidi layout."
        return 1
    fi
    if ! validate_q2_112_restore_contract; then
        err "No complete, verified restore contract is available."
        return 1
    fi
    if ! q2_112_restore_rehearsal_passed; then
        err "The isolated restore rehearsal has not passed for the current contract."
        info "Run option 10 before attempting the controlled live restore proof."
        return 1
    fi
    if ! verify_q2_112_active_config_matches_contract; then
        err "Active config does not exactly match the sealed stock contract."
        warn "Refusing the live proof to avoid overwriting unrelated config changes."
        return 1
    fi
    if ! q2_112_contract_path_was_absent "$Q2_112_LIVE_PROOF_EXTERNAL_DIR"; then
        err "External proof path was not captured absent: ${Q2_112_LIVE_PROOF_EXTERNAL_DIR}"
        return 1
    fi
    if [ -e "$Q2_112_LIVE_PROOF_CFG" ] || [ -L "$Q2_112_LIVE_PROOF_CFG" ] || \
       [ -e "$Q2_112_LIVE_PROOF_EXTERNAL_DIR" ] || [ -L "$Q2_112_LIVE_PROOF_EXTERNAL_DIR" ]; then
        err "Controlled proof artifacts already exist; refusing to overwrite them."
        return 1
    fi

    warn "This is the first controlled live contract-backed restore test."
    warn "It will create exactly two harmless, non-active proof artifacts:"
    warn "  ${Q2_112_LIVE_PROOF_CFG}"
    warn "  ${Q2_112_LIVE_PROOF_EXTERNAL_MARKER}"
    warn "It will then restore the exact sealed stock config tree with rsync --delete"
    warn "and remove only the external proof directory that was captured absent."
    warn "No includes, packages, service states, boot targets, or stock runtime files are changed."
    if ! confirm "Run the controlled live restore proof now?"; then
        info "Controlled live restore proof cancelled."
        return 1
    fi

    local before_dir="${Q2_112_LIVE_PROOF_DIR}/checks/before"
    local after_dir="${Q2_112_LIVE_PROOF_DIR}/checks/after"
    local emergency_config="${Q2_112_LIVE_PROOF_DIR}/emergency/config"
    local proof_token
    proof_token="AIO_Q2_112_LIVE_RESTORE_PROOF_$(date +%Y%m%d_%H%M%S)"

    sudo rm -rf "$Q2_112_LIVE_PROOF_DIR"
    sudo mkdir -p "$before_dir" "$after_dir" "$emergency_config" || {
        err "Could not create controlled live restore proof state."
        return 1
    }

    banner "Capturing emergency rollback and live-state guard"
    if ! sudo rsync -aHAX --numeric-ids "${CONFIG_DIR}/" "${emergency_config}/"; then
        err "Could not capture emergency config rollback."
        return 1
    fi
    write_q2_112_rehearsal_live_guard "$before_dir" || {
        err "Could not capture pre-proof live-state guard."
        return 1
    }
    ok "Emergency rollback and pre-proof live-state guard captured"

    banner "Creating controlled proof artifacts"
    if ! sudo tee "$Q2_112_LIVE_PROOF_CFG" >/dev/null <<EOF
# ${proof_token}
# Harmless, non-included marker for the Q2 1.1.2 contract-backed restore proof.
EOF
    then
        err "Could not create controlled config proof artifact."
        rollback_q2_112_live_restore_proof "$proof_token"
        return 1
    fi
    if ! sudo mkdir -p "$Q2_112_LIVE_PROOF_EXTERNAL_DIR" || \
       ! printf '%s\n' "$proof_token" | sudo tee "$Q2_112_LIVE_PROOF_EXTERNAL_MARKER" >/dev/null; then
        err "Could not create controlled external proof artifact."
        rollback_q2_112_live_restore_proof "$proof_token"
        return 1
    fi
    ok "Controlled proof artifacts created"

    banner "Executing sealed contract-backed config restore"
    if ! sudo rsync -aHAX --numeric-ids --delete \
        "${Q2_112_CONTRACT_DIR}/config/" "${CONFIG_DIR}/"; then
        err "Contract-backed config restore failed."
        rollback_q2_112_live_restore_proof "$proof_token"
        return 1
    fi
    if [ -e "$Q2_112_LIVE_PROOF_CFG" ] || [ -L "$Q2_112_LIVE_PROOF_CFG" ]; then
        err "Config proof artifact survived contract-backed rsync --delete."
        rollback_q2_112_live_restore_proof "$proof_token"
        return 1
    fi
    ok "Contract-backed config restore removed the controlled config artifact"

    banner "Applying controlled captured-absent path restore"
    if [ ! -f "$Q2_112_LIVE_PROOF_EXTERNAL_MARKER" ] || \
       [ "$(sudo cat "$Q2_112_LIVE_PROOF_EXTERNAL_MARKER" 2>/dev/null)" != "$proof_token" ]; then
        err "External proof marker identity could not be verified; refusing removal."
        rollback_q2_112_live_restore_proof "$proof_token"
        return 1
    fi
    if ! remove_q2_112_live_proof_external_path "$proof_token"; then
        err "Could not safely remove controlled external proof path."
        rollback_q2_112_live_restore_proof "$proof_token"
        return 1
    fi
    ok "Controlled external path restored to its captured absent state"

    banner "Verifying exact restoration and unchanged system state"
    if ! verify_q2_112_active_config_matches_contract; then
        err "Restored active config does not exactly match the sealed stock contract."
        rollback_q2_112_live_restore_proof "$proof_token"
        return 1
    fi
    write_q2_112_rehearsal_live_guard "$after_dir" || {
        err "Could not capture post-proof live-state guard."
        rollback_q2_112_live_restore_proof "$proof_token"
        return 1
    }
    if ! verify_q2_112_rehearsal_live_guard "$before_dir" "$after_dir"; then
        err "Live system state differs after the controlled restore proof."
        rollback_q2_112_live_restore_proof "$proof_token"
        return 1
    fi
    if [ -e "$Q2_112_LIVE_PROOF_CFG" ] || [ -e "$Q2_112_LIVE_PROOF_EXTERNAL_DIR" ]; then
        err "Controlled proof artifacts remain after restoration."
        rollback_q2_112_live_restore_proof "$proof_token"
        return 1
    fi

    if ! sudo tee "${Q2_112_LIVE_PROOF_DIR}/PASS" >/dev/null <<EOF
AIO_VERSION=${AIO_VERSION}
CONTRACT_DIR=${Q2_112_CONTRACT_DIR}
CONTRACT_SEAL_SHA256=$(file_sha256 "${Q2_112_CONTRACT_DIR}/contract.sha256")
PROVED_AT=$(date -Iseconds)
EOF
    then
        err "Restore succeeded, but the controlled proof PASS record could not be written."
        return 1
    fi
    sudo rm -rf "${Q2_112_LIVE_PROOF_DIR}/emergency"
    ok "Controlled live restore proof passed"
    ok "Active config exactly matches stock contract; proof artifacts are absent"
    ok "Service enablement, default target, and package inventory are unchanged"
    info "Run option 8 to verify Klipper, Moonraker, QIDIClient, Crowsnest, and Qidi Box health."
    info "Full install and general real revert remain blocked."
    return 0
}

menu_q2_112_live_restore_proof() {
    run_q2_112_live_restore_proof
    press_enter
}

write_q2_112_present_proof_guard() {
    local output_dir="$1"
    local active

    write_q2_112_rehearsal_live_guard "$output_dir" || return 1
    active=$(systemctl is-active "$STOCK_UI_SERVICE" 2>/dev/null || true)
    printf '%s\n' "${active:-inactive}" | sudo tee "${output_dir}/stock-ui-active" >/dev/null
}

verify_q2_112_present_proof_guard() {
    local before_dir="$1"
    local after_dir="$2"

    verify_q2_112_rehearsal_live_guard "$before_dir" "$after_dir" || return 1
    if ! sudo cmp -s "${before_dir}/stock-ui-active" "${after_dir}/stock-ui-active"; then
        err "Present-path restore proof changed stock UI active state"
        return 1
    fi
    return 0
}

rollback_q2_112_present_path_restore_proof() {
    local emergency_target="${Q2_112_PRESENT_PROOF_DIR}/emergency/target"

    warn "Rolling back the controlled captured-present path restore proof"
    if [ -d "$emergency_target" ]; then
        sudo rsync -aHAX --numeric-ids --checksum --delete \
            "${emergency_target}/" "${Q2_112_PRESENT_PROOF_TARGET}/" || \
            err "Emergency target rollback failed; inspect ${emergency_target}"
    else
        err "Emergency target rollback is unavailable; inspect ${Q2_112_PRESENT_PROOF_TARGET}"
    fi
}

remove_q2_112_present_proof_marker() {
    local expected_token="$1"
    local marker_token

    [ -f "$Q2_112_PRESENT_PROOF_MARKER" ] && [ ! -L "$Q2_112_PRESENT_PROOF_MARKER" ] || return 1
    marker_token=$(sudo cat "$Q2_112_PRESENT_PROOF_MARKER" 2>/dev/null || true)
    [ "$marker_token" = "$expected_token" ] || return 1
    sudo rm -f "$Q2_112_PRESENT_PROOF_MARKER"
}

q2_112_present_path_restore_proof_passed() {
    local pass_file="${Q2_112_PRESENT_PROOF_DIR}/PASS"
    local expected_seal current_seal
    local before_dir="${Q2_112_PRESENT_PROOF_DIR}/checks/before"
    local after_dir="${Q2_112_PRESENT_PROOF_DIR}/checks/after"

    [ -f "$pass_file" ] || return 1
    validate_q2_112_restore_contract || return 1
    q2_112_live_restore_proof_passed || return 1
    expected_seal=$(sed -n 's/^CONTRACT_SEAL_SHA256=//p' "$pass_file" 2>/dev/null | head -n 1)
    current_seal=$(file_sha256 "${Q2_112_CONTRACT_DIR}/contract.sha256")
    [ -n "$expected_seal" ] && [ "$expected_seal" = "$current_seal" ] || return 1
    [ ! -e "$Q2_112_PRESENT_PROOF_MARKER" ] && [ ! -L "$Q2_112_PRESENT_PROOF_MARKER" ] || return 1
    verify_q2_112_present_proof_guard "$before_dir" "$after_dir"
}

run_q2_112_present_path_restore_proof() {
    banner "Q2 1.1.2 captured-present path restore proof"

    if [ "$AIO_LAYOUT" != "q2_112" ] || [ "$STOCK_UI_SERVICE" != "qidi-client" ]; then
        err "This proof is only available on Q2 firmware 1.1.2 with qidi-client."
        return 1
    fi
    if ! validate_q2_112_restore_contract; then
        err "No complete, verified restore contract is available."
        return 1
    fi
    if ! q2_112_restore_rehearsal_passed || ! q2_112_live_restore_proof_passed; then
        err "The isolated rehearsal and controlled live restore proof must pass first."
        return 1
    fi
    if ! q2_112_external_paths_match_contract; then
        err "One or more external paths no longer exactly match the sealed contract."
        info "Run option 12 and review every reported change before continuing."
        return 1
    fi
    if ! q2_112_contract_path_was_present_directory "$Q2_112_PRESENT_PROOF_TARGET"; then
        err "Target was not captured as a present directory: ${Q2_112_PRESENT_PROOF_TARGET}"
        return 1
    fi
    if [ ! -d "$Q2_112_PRESENT_PROOF_TARGET" ] || [ -L "$Q2_112_PRESENT_PROOF_TARGET" ] || \
       [ ! -d "$Q2_112_PRESENT_PROOF_SOURCE" ] || [ -L "$Q2_112_PRESENT_PROOF_SOURCE" ]; then
        err "Live target or sealed contract source directory is missing."
        return 1
    fi
    if [ -e "$Q2_112_PRESENT_PROOF_MARKER" ] || [ -L "$Q2_112_PRESENT_PROOF_MARKER" ]; then
        err "Controlled proof marker already exists; refusing to overwrite it."
        return 1
    fi
    if ! systemctl is-active --quiet "$STOCK_UI_SERVICE"; then
        err "Stock QIDIClient UI is not active; refusing the controlled proof."
        return 1
    fi

    warn "This tests restoration of one captured-present system directory:"
    warn "  ${Q2_112_PRESENT_PROOF_TARGET}"
    warn "It creates one uniquely identified marker without a .conf extension,"
    warn "so systemd ignores it, then restores the directory from the sealed contract."
    warn "It does not run daemon-reload, restart services, or touch Klipper code/configs."
    if ! confirm "Run the controlled captured-present path restore proof now?"; then
        info "Captured-present path restore proof cancelled."
        return 1
    fi

    local before_dir="${Q2_112_PRESENT_PROOF_DIR}/checks/before"
    local after_dir="${Q2_112_PRESENT_PROOF_DIR}/checks/after"
    local emergency_target="${Q2_112_PRESENT_PROOF_DIR}/emergency/target"
    local proof_token proof_marker_name changes
    proof_token="AIO_Q2_112_PRESENT_PATH_PROOF_$(date +%Y%m%d_%H%M%S)"
    proof_marker_name="${Q2_112_PRESENT_PROOF_MARKER##*/}"

    sudo rm -rf "$Q2_112_PRESENT_PROOF_DIR"
    sudo mkdir -p "$before_dir" "$after_dir" "$emergency_target" || {
        err "Could not create captured-present proof state."
        return 1
    }

    banner "Capturing emergency rollback and live-state guard"
    if ! sudo rsync -aHAX --numeric-ids \
        "${Q2_112_PRESENT_PROOF_TARGET}/" "${emergency_target}/"; then
        err "Could not capture emergency target rollback."
        return 1
    fi
    write_q2_112_present_proof_guard "$before_dir" || {
        err "Could not capture pre-proof live-state guard."
        return 1
    }
    ok "Emergency target rollback and pre-proof live-state guard captured"

    banner "Creating ignored systemd proof marker"
    if ! printf '%s\n' "$proof_token" | sudo tee "$Q2_112_PRESENT_PROOF_MARKER" >/dev/null; then
        err "Could not create controlled proof marker."
        rollback_q2_112_present_path_restore_proof
        return 1
    fi
    if [ "$(sudo cat "$Q2_112_PRESENT_PROOF_MARKER" 2>/dev/null || true)" != "$proof_token" ]; then
        err "Controlled proof marker identity could not be verified."
        warn "The ignored marker was left for inspection: ${Q2_112_PRESENT_PROOF_MARKER}"
        return 1
    fi
    changes=$(sudo rsync -aHAX --numeric-ids --checksum --delete --dry-run --itemize-changes \
        --omit-dir-times --exclude="/${proof_marker_name}" \
        "${Q2_112_PRESENT_PROOF_SOURCE}/" "${Q2_112_PRESENT_PROOF_TARGET}/" 2>/dev/null) || {
        err "Could not verify target safety immediately before restore."
        remove_q2_112_present_proof_marker "$proof_token" || \
            warn "The ignored marker was left for inspection: ${Q2_112_PRESENT_PROOF_MARKER}"
        return 1
    }
    if [ -n "$changes" ]; then
        err "Target changed after the initial safety gate; refusing rsync --delete."
        remove_q2_112_present_proof_marker "$proof_token" || \
            warn "The ignored marker was left for inspection: ${Q2_112_PRESENT_PROOF_MARKER}"
        return 1
    fi
    ok "Ignored proof marker created; no daemon-reload or service restart performed"

    banner "Executing sealed captured-present directory restore"
    if ! sudo rsync -aHAX --numeric-ids --checksum --delete \
        "${Q2_112_PRESENT_PROOF_SOURCE}/" "${Q2_112_PRESENT_PROOF_TARGET}/"; then
        err "Contract-backed captured-present directory restore failed."
        rollback_q2_112_present_path_restore_proof
        return 1
    fi
    if [ -e "$Q2_112_PRESENT_PROOF_MARKER" ] || [ -L "$Q2_112_PRESENT_PROOF_MARKER" ]; then
        err "Proof marker survived contract-backed rsync --delete."
        rollback_q2_112_present_path_restore_proof
        return 1
    fi
    changes=$(sudo rsync -aHAX --numeric-ids --checksum --delete --dry-run --itemize-changes \
        "${Q2_112_PRESENT_PROOF_SOURCE}/" "${Q2_112_PRESENT_PROOF_TARGET}/" 2>/dev/null) || {
        err "Could not verify restored target against the sealed contract."
        rollback_q2_112_present_path_restore_proof
        return 1
    }
    if [ -n "$changes" ]; then
        err "Restored target does not exactly match the sealed contract."
        rollback_q2_112_present_path_restore_proof
        return 1
    fi
    ok "Captured-present target exactly matches the sealed contract"

    banner "Verifying unchanged printer state"
    write_q2_112_present_proof_guard "$after_dir" || {
        err "Could not capture post-proof live-state guard."
        rollback_q2_112_present_path_restore_proof
        return 1
    }
    if ! verify_q2_112_present_proof_guard "$before_dir" "$after_dir"; then
        err "Guarded printer state differs after the captured-present proof."
        rollback_q2_112_present_path_restore_proof
        return 1
    fi
    if ! systemctl is-active --quiet "$STOCK_UI_SERVICE"; then
        err "QIDIClient stock UI is not active after the captured-present proof."
        rollback_q2_112_present_path_restore_proof
        return 1
    fi

    if ! sudo tee "${Q2_112_PRESENT_PROOF_DIR}/PASS" >/dev/null <<EOF
AIO_VERSION=${AIO_VERSION}
CONTRACT_DIR=${Q2_112_CONTRACT_DIR}
CONTRACT_SEAL_SHA256=$(file_sha256 "${Q2_112_CONTRACT_DIR}/contract.sha256")
TARGET=${Q2_112_PRESENT_PROOF_TARGET}
PROVED_AT=$(date -Iseconds)
EOF
    then
        err "Restore succeeded, but the captured-present proof PASS record could not be written."
        return 1
    fi
    sudo rm -rf "${Q2_112_PRESENT_PROOF_DIR}/emergency"
    ok "Controlled captured-present path restore proof passed"
    ok "QIDIClient remained active; no service reload or restart was performed"
    ok "Config, service enablement, default target, and package inventory are unchanged"
    info "Run option 8 to verify full printer runtime health."
    info "Full install and general real revert remain blocked."
    return 0
}

menu_q2_112_present_path_restore_proof() {
    run_q2_112_present_path_restore_proof
    press_enter
}

q2_112_runtime_proof_services() {
    printf '%s\n' klipper moonraker "$STOCK_UI_SERVICE" crowsnest
}

q2_112_runtime_services_active() {
    local service

    while IFS= read -r service; do
        systemctl is-active --quiet "$service" || return 1
    done < <(q2_112_runtime_proof_services)
    return 0
}

write_q2_112_runtime_proof_guard() {
    local output_dir="$1"
    local service active

    write_q2_112_present_proof_guard "$output_dir" || return 1
    while IFS= read -r service; do
        active=$(systemctl is-active "$service" 2>/dev/null || true)
        printf '%s|%s\n' "$service" "${active:-inactive}"
    done < <(q2_112_runtime_proof_services) | sudo tee "${output_dir}/runtime-services-active" >/dev/null
}

verify_q2_112_runtime_proof_guard() {
    local before_dir="$1"
    local after_dir="$2"

    verify_q2_112_present_proof_guard "$before_dir" "$after_dir" || return 1
    if ! sudo cmp -s "${before_dir}/runtime-services-active" "${after_dir}/runtime-services-active"; then
        err "Runtime-path restore proof changed a guarded service active state"
        return 1
    fi
    return 0
}

remove_q2_112_runtime_proof_marker() {
    local marker="$1"
    local expected_token="$2"
    local marker_token

    [ -f "$marker" ] && [ ! -L "$marker" ] || return 1
    marker_token=$(sudo cat "$marker" 2>/dev/null || true)
    [ "$marker_token" = "$expected_token" ] || return 1
    sudo rm -f "$marker"
}

rollback_q2_112_runtime_path_restore_proof() {
    local proof_dir="$1"
    local target="$2"
    local emergency_target="${proof_dir}/emergency/target"

    warn "Rolling back the controlled runtime-path restore proof"
    if [ -d "$emergency_target" ] && [ ! -L "$emergency_target" ] && \
       [ -d "$target" ] && [ ! -L "$target" ]; then
        sudo rsync -aHAX --numeric-ids --checksum --delete "${emergency_target}/" "${target}/" || \
            err "Emergency runtime-path rollback failed; inspect ${emergency_target}"
    else
        err "Emergency runtime-path rollback is unavailable; inspect ${target}"
    fi
}

q2_112_runtime_path_restore_proof_passed() {
    local proof_dir="$1"
    local target="$2"
    local marker="$3"
    local pass_file="${proof_dir}/PASS"
    local expected_seal current_seal expected_target
    local before_dir="${proof_dir}/checks/before"
    local after_dir="${proof_dir}/checks/after"

    [ -f "$pass_file" ] || return 1
    validate_q2_112_restore_contract || return 1
    q2_112_present_path_restore_proof_passed || return 1
    expected_seal=$(sed -n 's/^CONTRACT_SEAL_SHA256=//p' "$pass_file" 2>/dev/null | head -n 1)
    current_seal=$(file_sha256 "${Q2_112_CONTRACT_DIR}/contract.sha256")
    expected_target=$(sed -n 's/^TARGET=//p' "$pass_file" 2>/dev/null | head -n 1)
    [ -n "$expected_seal" ] && [ "$expected_seal" = "$current_seal" ] || return 1
    [ "$expected_target" = "$target" ] || return 1
    [ ! -e "$marker" ] && [ ! -L "$marker" ] || return 1
    verify_q2_112_runtime_proof_guard "$before_dir" "$after_dir"
}

run_q2_112_runtime_path_restore_proof() {
    local label="$1"
    local proof_dir="$2"
    local target="$3"
    local marker="$4"
    local source="${Q2_112_CONTRACT_DIR}/external${target}"
    local before_dir="${proof_dir}/checks/before"
    local after_dir="${proof_dir}/checks/after"
    local emergency_target="${proof_dir}/emergency/target"
    local proof_token marker_name changes

    banner "Q2 1.1.2 ${label} restore proof"

    if [ "$AIO_LAYOUT" != "q2_112" ] || [ "$STOCK_UI_SERVICE" != "qidi-client" ]; then
        err "This proof is only available on Q2 firmware 1.1.2 with qidi-client."
        return 1
    fi
    if ! validate_q2_112_restore_contract || ! q2_112_present_path_restore_proof_passed; then
        err "The verified contract and captured-present systemd proof must pass first."
        return 1
    fi
    if ! q2_112_external_paths_match_contract; then
        err "One or more external paths no longer exactly match the sealed contract."
        info "Run option 12 and review every reported change before continuing."
        return 1
    fi
    if ! q2_112_contract_path_was_present_directory "$target"; then
        err "Target was not captured as a present directory: ${target}"
        return 1
    fi
    if [ ! -d "$target" ] || [ -L "$target" ] || [ ! -d "$source" ] || [ -L "$source" ]; then
        err "Live target or sealed contract source is not a real directory."
        return 1
    fi
    if [ -e "$marker" ] || [ -L "$marker" ]; then
        err "Controlled runtime proof marker already exists; refusing to overwrite it."
        return 1
    fi
    if ! q2_112_runtime_services_active; then
        err "Klipper, Moonraker, QIDIClient, and Crowsnest must all be active."
        return 1
    fi

    warn "This tests sealed restoration of one loaded Python runtime directory:"
    warn "  ${target}"
    warn "It creates one hidden marker without a .py extension, verifies that marker"
    warn "is the only difference, then restores only this directory with rsync --delete."
    warn "It does not reload Python, restart services, or touch active Klipper configs."
    if ! confirm "Run the controlled ${label} restore proof now?"; then
        info "${label} restore proof cancelled."
        return 1
    fi
    if ! q2_112_runtime_services_active; then
        err "A guarded runtime service changed state while awaiting confirmation."
        return 1
    fi

    proof_token="AIO_Q2_112_RUNTIME_PATH_PROOF_$(date +%Y%m%d_%H%M%S)"
    marker_name="${marker##*/}"
    sudo rm -rf "$proof_dir"
    sudo mkdir -p "$before_dir" "$after_dir" "$emergency_target" || {
        err "Could not create runtime-path proof state."
        return 1
    }

    banner "Capturing emergency rollback and runtime guard"
    if ! sudo rsync -aHAX --numeric-ids "${target}/" "${emergency_target}/"; then
        err "Could not capture emergency runtime-path rollback."
        return 1
    fi
    write_q2_112_runtime_proof_guard "$before_dir" || {
        err "Could not capture pre-proof runtime guard."
        return 1
    }
    ok "Emergency rollback and pre-proof runtime guard captured"

    banner "Creating harmless non-Python proof marker"
    if ! printf '%s\n' "$proof_token" | sudo tee "$marker" >/dev/null; then
        err "Could not create controlled runtime proof marker."
        rollback_q2_112_runtime_path_restore_proof "$proof_dir" "$target"
        return 1
    fi
    if [ "$(sudo cat "$marker" 2>/dev/null || true)" != "$proof_token" ]; then
        err "Controlled runtime proof marker identity could not be verified."
        warn "The marker was left for inspection: ${marker}"
        return 1
    fi
    changes=$(sudo rsync -aHAX --numeric-ids --checksum --delete --dry-run --itemize-changes \
        --omit-dir-times --exclude="/${marker_name}" "${source}/" "${target}/" 2>/dev/null) || {
        err "Could not verify runtime target safety immediately before restore."
        remove_q2_112_runtime_proof_marker "$marker" "$proof_token" || \
            warn "The marker was left for inspection: ${marker}"
        return 1
    }
    if [ -n "$changes" ]; then
        err "Runtime target changed after the initial safety gate; refusing rsync --delete."
        remove_q2_112_runtime_proof_marker "$marker" "$proof_token" || \
            warn "The marker was left for inspection: ${marker}"
        return 1
    fi
    if ! q2_112_runtime_services_active; then
        err "A guarded runtime service changed state before the restore."
        remove_q2_112_runtime_proof_marker "$marker" "$proof_token" || \
            warn "The marker was left for inspection: ${marker}"
        return 1
    fi
    ok "Marker is the only target difference; all guarded services remain active"

    banner "Executing sealed runtime-directory restore"
    if ! sudo rsync -aHAX --numeric-ids --checksum --delete "${source}/" "${target}/"; then
        err "Contract-backed runtime-directory restore failed."
        rollback_q2_112_runtime_path_restore_proof "$proof_dir" "$target"
        return 1
    fi
    if [ -e "$marker" ] || [ -L "$marker" ]; then
        err "Runtime proof marker survived contract-backed rsync --delete."
        rollback_q2_112_runtime_path_restore_proof "$proof_dir" "$target"
        return 1
    fi
    changes=$(sudo rsync -aHAX --numeric-ids --checksum --delete --dry-run --itemize-changes \
        "${source}/" "${target}/" 2>/dev/null) || {
        err "Could not verify restored runtime target against the sealed contract."
        rollback_q2_112_runtime_path_restore_proof "$proof_dir" "$target"
        return 1
    }
    if [ -n "$changes" ]; then
        err "Restored runtime target does not exactly match the sealed contract."
        rollback_q2_112_runtime_path_restore_proof "$proof_dir" "$target"
        return 1
    fi
    ok "Runtime target exactly matches the sealed contract"

    banner "Verifying unchanged runtime and printer state"
    write_q2_112_runtime_proof_guard "$after_dir" || {
        err "Could not capture post-proof runtime guard."
        rollback_q2_112_runtime_path_restore_proof "$proof_dir" "$target"
        return 1
    }
    if ! verify_q2_112_runtime_proof_guard "$before_dir" "$after_dir" || \
       ! q2_112_runtime_services_active; then
        err "Guarded printer runtime differs after the controlled restore."
        rollback_q2_112_runtime_path_restore_proof "$proof_dir" "$target"
        return 1
    fi

    if ! sudo tee "${proof_dir}/PASS" >/dev/null <<EOF
AIO_VERSION=${AIO_VERSION}
CONTRACT_DIR=${Q2_112_CONTRACT_DIR}
CONTRACT_SEAL_SHA256=$(file_sha256 "${Q2_112_CONTRACT_DIR}/contract.sha256")
TARGET=${target}
PROVED_AT=$(date -Iseconds)
EOF
    then
        err "Restore succeeded, but the runtime-path proof PASS record could not be written."
        return 1
    fi
    sudo rm -rf "${proof_dir}/emergency"
    ok "Controlled ${label} restore proof passed"
    ok "Klipper, Moonraker, QIDIClient, and Crowsnest remained active"
    ok "No Python reload, service restart, config change, or package change occurred"
    info "Run option 8 to verify full printer runtime and Qidi Box sensor health."
    info "Full install and general real revert remain blocked."
    return 0
}

menu_q2_112_klipper_extras_restore_proof() {
    run_q2_112_runtime_path_restore_proof \
        "Klipper extras" \
        "$Q2_112_KLIPPER_EXTRAS_PROOF_DIR" \
        "$Q2_112_KLIPPER_EXTRAS_PROOF_TARGET" \
        "$Q2_112_KLIPPER_EXTRAS_PROOF_MARKER"
    press_enter
}

menu_q2_112_moonraker_components_restore_proof() {
    run_q2_112_runtime_path_restore_proof \
        "Moonraker components" \
        "$Q2_112_MOONRAKER_COMPONENTS_PROOF_DIR" \
        "$Q2_112_MOONRAKER_COMPONENTS_PROOF_TARGET" \
        "$Q2_112_MOONRAKER_COMPONENTS_PROOF_MARKER"
    press_enter
}

offer_q2_112_restore_contract_capture() {
    [ "$AIO_LAYOUT" = "q2_112" ] || return 0

    if validate_q2_112_restore_contract; then
        ok "Verified 1.1.2 restore contract is ready."
        return 0
    fi
    if capture_q2_112_restore_contract; then
        banner "Restore contract preview after capture"
        report_q2_112_restore_contract || true
    fi
}

report_stock_preservation_dry_run() {
    banner "Dry-run stock preservation checks"

    dry_run_path_state "Active config dir" "$CONFIG_DIR"
    dry_run_path_state "Stock macro directory" "${CONFIG_DIR}/klipper-macros-qd"
    dry_run_path_state "Stock crowsnest.conf" "${CONFIG_DIR}/crowsnest.conf"
    dry_run_path_state "Stock timelapse.cfg" "${CONFIG_DIR}/timelapse.cfg"
    dry_run_path_state "Stock QIDI_Client directory" "${AIO_HOME}/QIDI_Client"

    verify_systemd_service_health "$STOCK_UI_SERVICE" "$STOCK_UI_LABEL" true
    if [ "$CAMERA_STACK" = "crowsnest" ]; then
        verify_systemd_service_health crowsnest "Crowsnest camera stack" false
    fi
    verify_qidi_tuning_service_health
}

report_aio_removal_dry_run() {
    banner "Dry-run AIO artifact removal plan"

    for d in \
        "$HAPPY_HARE_DIR" \
        "$HELIX_DIR" \
        "$HELIX_PRINT_DIR" \
        "$KIAUH_DIR" \
        "$KIAUH_BACKUPS_DIR" \
        "$KIAUH_UPPER_DIR" \
        "$KIAUH_UPPER_BACKUPS_DIR" \
        "$MAINSAIL_DIR" \
        "$Q2_112_PROBE_STATE_DIR" \
        /opt/helixscreen \
        /var/lib/helixscreen \
        /var/log/helixscreen \
        "${HOME}/.helixscreen" \
        /root/.helixscreen; do
        dry_run_removal_state "$d"
    done

    for f in \
        "${CONFIG_DIR}/bunnybox_macros.cfg" \
        "${CONFIG_DIR}/KAMP_settings.cfg" \
        "${CONFIG_DIR}/KAMP_settings.cfg" \
        "${CONFIG_DIR}/Adaptive_Meshing.cfg" \
        "${CONFIG_DIR}/Adaptive_Mesh.cfg" \
        "${CONFIG_DIR}/Line_Purge.cfg" \
        "${CONFIG_DIR}/Smart_Park.cfg" \
        "${CONFIG_DIR}/mmu_cut_tip.cfg" \
        "${CONFIG_DIR}/mmu_form_tip.cfg" \
        "${CONFIG_DIR}/mmu_heater_vent.cfg" \
        "${CONFIG_DIR}/mmu_leds.cfg" \
        "${CONFIG_DIR}/mmu_purge.cfg" \
        "${CONFIG_DIR}/mmu_sequence.cfg" \
        "${CONFIG_DIR}/mmu_software.cfg" \
        "${CONFIG_DIR}/mmu_state.cfg" \
        "${CONFIG_DIR}/mmu_parameters.cfg" \
        "${CONFIG_DIR}/mmu_macro_vars.cfg" \
        "${CONFIG_DIR}/mmu_hardware.cfg" \
        "${CONFIG_DIR}/mmu_vars.cfg" \
        "${CONFIG_DIR}/mmu.cfg" \
        "${CONFIG_DIR}/moonraker.conf.aio-bak" \
        "$Q2_112_LIVE_PROOF_CFG" \
        "$Q2_112_PROBE_CFG" \
        /etc/systemd/system/helixscreen.service \
        "$Q2_112_PRESENT_PROOF_MARKER" \
        "$Q2_112_KLIPPER_EXTRAS_PROOF_MARKER" \
        "$Q2_112_MOONRAKER_COMPONENTS_PROOF_MARKER" \
        /etc/systemd/system/helixscreen-update.path \
        /etc/systemd/system/helixscreen-update.service \
        /etc/udev/rules.d/99-helixscreen-backlight.rules \
        /etc/polkit-1/localauthority/50-local.d/helixscreen-network.pkla \
        /etc/polkit-1/rules.d/49-helixscreen-network.rules \
        /etc/polkit-1/rules.d/50-helixscreen-network.rules; do
        dry_run_removal_state "$f"
    done

    while IFS= read -r -d '' path; do
        dry_run_removal_state "$path"
    done < <(
        find "$CONFIG_DIR" -maxdepth 1 \
            \( -name 'mmu' -o -name 'mmu-*' -o -name 'mmu_*' -o -name 'mmu[0-9]*' \
               -o -name 'backup_hh_*' -o -name 'backup_revert_*' -o -name 'backup_mmu_*' \
               -o -name 'backup_bunnybox_*' \
               -o -name 'moonraker.conf.bak.helixscreen*' \) \
            -print0 2>/dev/null
    )

    info "Installer-managed backup root: ${BACKUP_ROOT}/"
    info "This is not stock firmware content; dry-run does not remove installer-managed backups."
}

offer_q2_112_baseline_capture() {
    local selected selected_label selected_path selected_delete

    [ "$AIO_LAYOUT" = "q2_112" ] || return 0
    if ! selected=$(select_revert_backup_source); then
        warn "No backup source exists yet for this layout."
        capture_q2_112_stock_baseline || true
        return 0
    fi

    IFS='|' read -r selected_label selected_path selected_delete <<< "$selected"
    if backup_missing_active_stock_essentials "$selected_path"; then
        warn "The selected baseline is missing active 1.1.2 stock essentials."
        capture_q2_112_stock_baseline || true
    fi
}

q2_112_probe_installed() {
    [ -d "$Q2_112_PROBE_STATE_DIR" ] || \
    [ -e "$Q2_112_PROBE_CFG" ] || \
    grep -Fqx "$Q2_112_PROBE_INCLUDE" "${CONFIG_DIR}/printer.cfg" 2>/dev/null
}

file_sha256() {
    local path="$1"
    sudo sha256sum "$path" 2>/dev/null | awk '{print $1}'
}

q2_112_probe_manifest_value() {
    local key="$1"
    [ -f "$Q2_112_PROBE_MANIFEST" ] || return 1
    sed -n "s/^${key}=//p" "$Q2_112_PROBE_MANIFEST" 2>/dev/null | head -n 1
}

q2_112_baseline_safe() {
    local selected selected_label selected_path selected_delete
    if ! selected=$(select_revert_backup_source); then
        err "No stock baseline exists. Run option 4 and capture the guarded baseline first."
        return 1
    fi
    IFS='|' read -r selected_label selected_path selected_delete <<< "$selected"
    if backup_missing_active_stock_essentials "$selected_path"; then
        err "Selected stock baseline is missing active 1.1.2 stock essentials."
        info "Run option 4 to inspect or repair the baseline before using the probe."
        return 1
    fi
    ok "Guarded stock baseline is ready: ${selected_path}"
    return 0
}

rollback_q2_112_probe_install() {
    warn "Rolling back incomplete 1.1.2 compatibility probe install"
    if [ -f "$Q2_112_PROBE_ORIGINAL" ]; then
        sudo cp -a "$Q2_112_PROBE_ORIGINAL" "${CONFIG_DIR}/printer.cfg" 2>/dev/null || true
    fi
    sudo rm -f "$Q2_112_PROBE_CFG" 2>/dev/null || true
    sudo rm -rf "$Q2_112_PROBE_STATE_DIR" 2>/dev/null || true
}

install_q2_112_roundtrip_probe() {
    banner "Install 1.1.2 compatibility round-trip probe"

    if [ "$AIO_LAYOUT" != "q2_112" ]; then
        err "The compatibility probe is only available on Q2 firmware 1.1.2 / qidi layout."
        return 1
    fi
    if q2_112_probe_installed; then
        warn "Compatibility probe artifacts are already present."
        info "Run this option again and choose removal."
        return 1
    fi
    q2_112_stock_essentials_present || return 1
    q2_112_aio_artifacts_absent || return 1
    q2_112_baseline_safe || return 1

    warn "This controlled test will add exactly two active-config changes:"
    warn "  ${Q2_112_PROBE_CFG}"
    warn "  ${Q2_112_PROBE_INCLUDE} in ${CONFIG_DIR}/printer.cfg"
    warn "It records exact before/after printer.cfg hashes for guarded removal."
    if ! confirm "Install the reversible 1.1.2 compatibility probe?"; then
        info "Compatibility probe install cancelled."
        return 1
    fi

    local original_sha modified_sha
    original_sha=$(file_sha256 "${CONFIG_DIR}/printer.cfg")
    if [ -z "$original_sha" ]; then
        err "Could not hash active printer.cfg"
        return 1
    fi

    sudo mkdir -p "$Q2_112_PROBE_STATE_DIR" || return 1
    if ! sudo cp -a "${CONFIG_DIR}/printer.cfg" "$Q2_112_PROBE_ORIGINAL"; then
        err "Could not save exact pre-probe printer.cfg"
        rollback_q2_112_probe_install
        return 1
    fi
    if ! sudo cp -a "$Q2_112_PROBE_ORIGINAL" "$Q2_112_PROBE_MODIFIED"; then
        err "Could not stage compatibility probe printer.cfg"
        rollback_q2_112_probe_install
        return 1
    fi

    if ! sudo tee -a "$Q2_112_PROBE_MODIFIED" >/dev/null <<EOF

# AIO Q2 1.1.2 reversible compatibility probe
${Q2_112_PROBE_INCLUDE}
EOF
    then
        err "Could not stage compatibility probe include"
        rollback_q2_112_probe_install
        return 1
    fi

    modified_sha=$(file_sha256 "$Q2_112_PROBE_MODIFIED")
    if [ -z "$modified_sha" ] || [ "$modified_sha" = "$original_sha" ]; then
        err "Could not verify the staged compatibility probe printer.cfg"
        rollback_q2_112_probe_install
        return 1
    fi

    if ! sudo tee "$Q2_112_PROBE_MANIFEST" >/dev/null <<EOF
AIO_VERSION=${AIO_VERSION}
AIO_LAYOUT=${AIO_LAYOUT}
CONFIG_DIR=${CONFIG_DIR}
PROBE_CFG=${Q2_112_PROBE_CFG}
PROBE_INCLUDE=${Q2_112_PROBE_INCLUDE}
ORIGINAL_PRINTER_CFG_SHA256=${original_sha}
MODIFIED_PRINTER_CFG_SHA256=${modified_sha}
EOF
    then
        err "Could not write compatibility probe manifest"
        rollback_q2_112_probe_install
        return 1
    fi

    if ! sudo tee "$Q2_112_PROBE_CFG" >/dev/null <<'EOF'
# AIO Q2 firmware 1.1.2 reversible compatibility probe.
[gcode_macro AIO_Q2_112_COMPAT_PROBE]
description: AIO Q2 1.1.2 reversible compatibility probe
gcode:
    G4 P1
EOF
    then
        err "Could not write compatibility probe config"
        rollback_q2_112_probe_install
        return 1
    fi
    sudo chown --reference="${CONFIG_DIR}/printer.cfg" "$Q2_112_PROBE_CFG" 2>/dev/null || true
    sudo chmod --reference="${CONFIG_DIR}/printer.cfg" "$Q2_112_PROBE_CFG" 2>/dev/null || true

    if ! sudo cp -a "$Q2_112_PROBE_MODIFIED" "${CONFIG_DIR}/printer.cfg"; then
        err "Could not activate staged compatibility probe printer.cfg"
        rollback_q2_112_probe_install
        return 1
    fi

    if [ ! -f "$Q2_112_PROBE_CFG" ] || \
       ! grep -Fqx "$Q2_112_PROBE_INCLUDE" "${CONFIG_DIR}/printer.cfg" 2>/dev/null || \
       [ "$(file_sha256 "${CONFIG_DIR}/printer.cfg")" != "$modified_sha" ]; then
        err "Compatibility probe verification failed"
        rollback_q2_112_probe_install
        return 1
    fi

    ok "Compatibility probe installed with exact before/after hashes"
    info "Run FIRMWARE_RESTART, then option 8 to verify Klipper and the active include graph."
    info "After verification, run option 9 again to perform the guarded round-trip removal."
    return 0
}

remove_q2_112_roundtrip_probe() {
    banner "Remove 1.1.2 compatibility round-trip probe"

    if [ "$AIO_LAYOUT" != "q2_112" ]; then
        err "The compatibility probe is only available on Q2 firmware 1.1.2 / qidi layout."
        return 1
    fi
    if [ ! -f "$Q2_112_PROBE_ORIGINAL" ] || [ ! -f "$Q2_112_PROBE_MANIFEST" ]; then
        err "Probe state is incomplete; refusing to overwrite printer.cfg."
        info "Inspect: ${Q2_112_PROBE_STATE_DIR}"
        return 1
    fi

    local original_sha expected_modified_sha current_sha restored_sha
    original_sha=$(q2_112_probe_manifest_value ORIGINAL_PRINTER_CFG_SHA256)
    expected_modified_sha=$(q2_112_probe_manifest_value MODIFIED_PRINTER_CFG_SHA256)
    current_sha=$(file_sha256 "${CONFIG_DIR}/printer.cfg")
    if [ -z "$original_sha" ] || [ -z "$expected_modified_sha" ] || [ -z "$current_sha" ]; then
        err "Probe hash metadata could not be read; refusing cleanup."
        return 1
    fi
    if [ "$current_sha" = "$original_sha" ]; then
        warn "Active printer.cfg already matches the pre-probe hash."
        warn "Cleaning incomplete probe files/state without overwriting printer.cfg."
        sudo rm -f "$Q2_112_PROBE_CFG"
        sudo rm -rf "$Q2_112_PROBE_STATE_DIR"
        ok "Incomplete compatibility probe state removed"
        return 0
    elif [ "$current_sha" != "$expected_modified_sha" ]; then
        err "Active printer.cfg changed after the probe was installed."
        warn "Expected modified hash: ${expected_modified_sha}"
        warn "Current hash:           ${current_sha}"
        warn "Refusing to overwrite unrelated changes. Probe state was kept for recovery."
        return 1
    fi

    warn "This will restore the exact pre-probe printer.cfg and remove only:"
    warn "  ${Q2_112_PROBE_CFG}"
    if ! confirm "Remove the compatibility probe and verify the round trip?"; then
        info "Compatibility probe removal cancelled."
        return 1
    fi

    if ! sudo cp -a "$Q2_112_PROBE_ORIGINAL" "${CONFIG_DIR}/printer.cfg"; then
        err "Could not restore exact pre-probe printer.cfg"
        return 1
    fi
    sudo rm -f "$Q2_112_PROBE_CFG"

    restored_sha=$(file_sha256 "${CONFIG_DIR}/printer.cfg")
    if [ "$restored_sha" != "$original_sha" ]; then
        err "Round-trip verification failed: restored printer.cfg hash does not match original."
        warn "Probe state was kept: ${Q2_112_PROBE_STATE_DIR}"
        return 1
    fi
    if [ -e "$Q2_112_PROBE_CFG" ] || \
       grep -Fqx "$Q2_112_PROBE_INCLUDE" "${CONFIG_DIR}/printer.cfg" 2>/dev/null; then
        err "Round-trip verification failed: probe artifacts remain."
        warn "Probe state was kept: ${Q2_112_PROBE_STATE_DIR}"
        return 1
    fi

    sudo rm -rf "$Q2_112_PROBE_STATE_DIR"
    ok "Round-trip verified: printer.cfg exactly matches its pre-probe hash"
    ok "Compatibility probe config and state removed"
    info "Run FIRMWARE_RESTART."
    return 0
}

menu_q2_112_roundtrip_probe() {
    if [ "$AIO_LAYOUT" != "q2_112" ]; then
        warn "The 1.1.2 compatibility probe is only available on the q2_112 layout."
        press_enter
        return 0
    fi

    if q2_112_probe_installed; then
        remove_q2_112_roundtrip_probe
    else
        install_q2_112_roundtrip_probe
    fi
    press_enter
}

# Stops and masks the Qidi stock display services, then enables and restarts helixscreen so HelixScreen owns the physical screen.
# Needed because HelixScreen's upstream installer was written for the Artillery M1 Pro and has no knowledge of Qidi display services.
switch_display_to_helixscreen() {
    banner "Switching active display: stock Qidi → HelixScreen"
    if [ ! -f /etc/systemd/system/helixscreen.service ]; then
        warn "helixscreen.service not installed — display swap skipped"
        warn "HelixScreen package may not have installed correctly. Check output above."
        return 1
    fi
    if [ -n "$STOCK_UI_SERVICE" ]; then
        sudo systemctl stop    "$STOCK_UI_SERVICE" 2>/dev/null || true
        sudo systemctl disable "$STOCK_UI_SERVICE" 2>/dev/null || true
        sudo systemctl mask    "$STOCK_UI_SERVICE" 2>/dev/null || true
    fi
    if [ -n "$STOCK_DISPLAY_SERVICE" ]; then
        sudo systemctl stop    "$STOCK_DISPLAY_SERVICE" 2>/dev/null || true
        sudo systemctl disable "$STOCK_DISPLAY_SERVICE" 2>/dev/null || true
        sudo systemctl mask    "$STOCK_DISPLAY_SERVICE" 2>/dev/null || true
    fi
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

# Performs a full stock restore: re-enables the stock display stack, runs all uninstallers, and rsync-restores the config from the selected AIO backup snapshot.
revert_to_backup() {
    banner "Revert to Backup (full stock restore)"

    # 1. Refuse if snapshot missing or empty.
    if [ ! -d "${SNAPSHOT_DIR}" ] || [ -z "$(ls -A "${SNAPSHOT_DIR}" 2>/dev/null)" ]; then
        err "No stock snapshot found at ${SNAPSHOT_DIR} — cannot revert safely."
        info "Run an install action first so a snapshot can be captured, then revert."
        return 1
    fi

    # 2. Non-config cleanup (outside printer_data/config).
    if helixscreen_installed; then
        uninstall_helixscreen
    else
        info "HelixScreen not present, skipping"
    fi

    # _purge_happy_hare_nonconfig handles source tree + klipper extras + moonraker
    # component. Config files (mmu/, mmu*.cfg, etc.) are restored by rsync --delete.
    if [ -d "$HAPPY_HARE_DIR" ] || bunnybox_installed; then
        _purge_happy_hare_nonconfig
    else
        info "BunnyBox / Happy Hare not present, skipping"
    fi

    if mainsail_installed; then
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

    # 3. Config restore — single rsync --delete, no surgery.
    # All AIO-written config files (mmu/, mmu*.cfg, KAMP files added by AIO,
    # bunnybox_macros.cfg, moonraker.conf entries, etc.) are absent from the
    # pre-install snapshot and are removed automatically by --delete.
    info "Restoring config from snapshot: ${SNAPSHOT_DIR}"
    if ! rsync -a --delete --no-owner --no-group "${SNAPSHOT_DIR}/" "${CONFIG_DIR}/" 2>/dev/null; then
        if ! sudo rsync -a --delete --no-owner --no-group "${SNAPSHOT_DIR}/" "${CONFIG_DIR}/"; then
            err "Config restore failed — snapshot is intact at ${SNAPSHOT_DIR}"
            return 1
        fi
    fi
    ok "Config restore complete"

    # Re-enable any [idle_timeout] previously disabled by the idle_fan_shutdown addon
    local pcfg="${CONFIG_DIR}/printer.cfg"
    if [ -f "$pcfg" ] && grep -q '^#\[idle_timeout\] # disabled by AIO' "$pcfg"; then
        sed -i 's|^#\[idle_timeout\] # disabled by AIO - see idle_fan_shutdown.cfg|[idle_timeout]|' "$pcfg"
        ok "Re-enabled previously-disabled [idle_timeout] in printer.cfg"
    fi

    # The aoi.ini marker was created after the snapshot, so it is absent
    # from the snapshot and rsync --delete removes it automatically.
    # Verify and clean up as a safety net:
    if [ -f "${AIO_MARKER}" ]; then
        warn "AIO marker still present after restore — removing manually"
        rm -f "${AIO_MARKER}" 2>/dev/null || sudo rm -f "${AIO_MARKER}"
    fi
    rm -f "${CONFIG_DIR}/.aio_installed" 2>/dev/null || sudo rm -f "${CONFIG_DIR}/.aio_installed" 2>/dev/null || true

    # 4. Restore stock display services (live systemd — not a config file).
    restore_stock_display_services || \
        warn "Stock display services did not verify — check $(stock_display_stack_label)"

    # 5. Post-revert sanity check (diagnostic only, no destructive edits).
    _run_verifiers_core

    banner "Revert complete"
    info "Run FIRMWARE_RESTART from Klipper/Moonraker."
    info "After reboot, confirm stock display with: systemctl status ${STOCK_DISPLAY_SERVICE:-display-manager.service} ${STOCK_UI_SERVICE:-}"
}

# ---------- post-install verification --------------------------------
verify_bunnybox_install() {
    banner "Verifying installation"
    local all_ok=true

    for f in printer.cfg gcode_macro.cfg KAMP/KAMP_settings.cfg \
              KAMP/Adaptive_Meshing.cfg KAMP/Line_Purge.cfg KAMP/Smart_Park.cfg; do
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

    if [ -s "${HELIX_CONFIG_DIR}/settings.json" ]; then
        ok "helixscreen settings.json"
    else
        err "helixscreen settings.json missing"
        all_ok=false
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
    for f in printer.cfg gcode_macro.cfg KAMP/KAMP_settings.cfg; do
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

verify_jfb_install() {
    banner "Verifying installation"
    local all_ok=true
    for f in printer.cfg gcode_macro.cfg KAMP/KAMP_settings.cfg; do
        if [ -s "${CONFIG_DIR}/${f}" ]; then
            ok "${f}"
        else
            err "${f} missing"
            all_ok=false
        fi
    done
    if grep -q 'Superuser Macros: Just Faster Box' "${CONFIG_DIR}/gcode_macro.cfg" 2>/dev/null; then
        ok "gcode_macro.cfg identified as Just Faster Box macros"
    else
        warn "gcode_macro.cfg does not carry the 'Just Faster Box' identifier — wrong macro file?"
    fi
    if grep -q 'BOX_PRINT_START' "${CONFIG_DIR}/gcode_macro.cfg" 2>/dev/null; then
        ok "gcode_macro.cfg contains box-aware macros (BOX_PRINT_START)"
    else
        warn "gcode_macro.cfg does not appear to contain box-aware macros"
    fi
    if [ "$all_ok" = true ]; then
        ok "All files verified"
    else
        warn "Some files are missing - install may not work correctly."
    fi
}

# Scans printer.cfg for known boot-breaking misplacements (timeout: and gcode: inside [bed_mesh]) and offers to remove them after confirming.
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

# Finds [include X] lines in printer.cfg whose target file does not exist on disk and offers to comment them out.
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

# Detects Happy Hare / MMU artifacts (extras/mmu/, mmu_*.py, mmu_server.py) that survived an uninstall and offers to remove them interactively.
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

# Runs the full verifier sequence (runtime health, install checks, conflict scans); shared by menu option 8 and revert_to_backup(). Does not call press_enter.
_run_verifiers_core() {
    verify_runtime_health

    if bunnybox_installed; then
        verify_bunnybox_install
    else
        info "BunnyBox not installed — skipping MMU + Qidi Box checks"
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

report_firmware_layout_files() {
    banner "Firmware layout files"

    if [ -d "$AIO_HOME" ]; then
        ok "AIO home exists: ${AIO_HOME}"
    else
        warn "AIO home missing: ${AIO_HOME}"
    fi
    if [ -d "$CONFIG_DIR" ]; then
        ok "Config dir exists: ${CONFIG_DIR}"
    else
        warn "Config dir missing: ${CONFIG_DIR}"
    fi
    if [ -d "${CONFIG_DIR}/klipper-macros-qd" ]; then
        ok "Stock Qidi macro directory present: ${CONFIG_DIR}/klipper-macros-qd"
    else
        info "Stock Qidi macro directory not present: ${CONFIG_DIR}/klipper-macros-qd"
    fi
    if [ -d "${AIO_HOME}/QIDI_Client" ]; then
        ok "QIDI_Client directory present: ${AIO_HOME}/QIDI_Client"
    else
        info "QIDI_Client directory not present: ${AIO_HOME}/QIDI_Client"
    fi
    if [ -f "${CONFIG_DIR}/crowsnest.conf" ]; then
        ok "crowsnest.conf present"
    else
        info "crowsnest.conf not present"
    fi
    if [ -f "${CONFIG_DIR}/timelapse.cfg" ]; then
        ok "timelapse.cfg present"
    else
        info "timelapse.cfg not present"
    fi
}

report_stock_macro_layout() {
    banner "Stock macro layout"

    local macro_dir="${CONFIG_DIR}/klipper-macros-qd"
    if [ ! -d "$macro_dir" ]; then
        info "No klipper-macros-qd/ directory on this layout"
        return 0
    fi

    local count=0
    while IFS= read -r file; do
        [ -n "$file" ] || continue
        count=$((count + 1))
        if [ "$count" -le 20 ]; then
            info "  ${file#${CONFIG_DIR}/}"
        fi
    done < <(find "$macro_dir" -maxdepth 2 -type f -name '*.cfg' 2>/dev/null | sort)

    if [ "$count" -eq 0 ]; then
        warn "klipper-macros-qd/ exists but no .cfg files were found"
    elif [ "$count" -gt 20 ]; then
        info "  ... $((count - 20)) more .cfg files"
    fi
    info "Stock macro cfg count: ${count}"
}

report_qidi_box_object_inventory() {
    banner "Qidi Box Moonraker object inventory"

    local response summary level message
    if ! response=$(moonraker_get "/printer/objects/list"); then
        warn "Could not query Moonraker object list"
        return 0
    fi

    summary=$(printf '%s' "$response" | python3 -c '
import json
import sys

objects = json.load(sys.stdin).get("result", {}).get("objects", [])
needles = ("box", "heater_box", "heater_temp", "heater_fan", "slot")
matches = [name for name in objects if any(needle in name.lower() for needle in needles)]
if not matches:
    print("WARN|No Qidi Box-looking objects found in Moonraker")
else:
    for name in sorted(matches):
        print(f"INFO|  {name}")

expected_stock = [
    "mcu mcu_box1",
    "box_extras",
    "box_stepper slot0",
    "box_stepper slot1",
    "box_stepper slot2",
    "box_stepper slot3",
    "aht20_f heater_box1",
    "heater_generic heater_box1",
]
missing = [name for name in expected_stock if name not in objects]
if missing:
    print("WARN|Missing expected stock 1.1.2 objects: " + ", ".join(missing))
else:
    print("OK|Expected stock 1.1.2 Qidi Box objects are present")
' 2>/dev/null || true)

    if [ -z "$summary" ]; then
        warn "Moonraker object list returned, but status could not be parsed"
        return 0
    fi

    while IFS='|' read -r level message; do
        case "$level" in
            OK) ok "$message" ;;
            INFO) info "$message" ;;
            *) warn "$message" ;;
        esac
    done <<< "$summary"
}

report_active_config_graph() {
    banner "Active Klipper include graph"

    if [ ! -f "${CONFIG_DIR}/printer.cfg" ]; then
        warn "printer.cfg not found at ${CONFIG_DIR}/printer.cfg"
        return 0
    fi

    local count=0
    while IFS= read -r -d '' file; do
        count=$((count + 1))
        if [ "$count" -le 40 ]; then
            info "  ${file#${CONFIG_DIR}/}"
        fi
    done < <(list_active_klipper_configs)

    if [ "$count" -eq 0 ]; then
        warn "No active config files found from printer.cfg"
    elif [ "$count" -gt 40 ]; then
        info "  ... $((count - 40)) more active config files"
    fi
    info "Active config file count: ${count}"
}

find_duplicate_macros_readonly() {
    banner "Scanning duplicate gcode_macro declarations (read-only)"

    if [ ! -f "${CONFIG_DIR}/printer.cfg" ]; then
        warn "printer.cfg not found - skipping scan"
        return 0
    fi

    local summary level message
    summary=$(list_active_klipper_configs | python3 -c '
import collections
import re
import sys

macro_re = re.compile(r"^\[gcode_macro\s+([^\]]+)\]")
paths = [p.decode("utf-8", "replace") for p in sys.stdin.buffer.read().split(b"\0") if p]
seen = collections.defaultdict(list)
for path in paths:
    try:
        with open(path, encoding="utf-8", errors="replace") as config_file:
            for line_no, line in enumerate(config_file, 1):
                match = macro_re.match(line.strip())
                if match:
                    seen[match.group(1)].append((path, line_no))
    except OSError:
        continue

dups = {name: hits for name, hits in seen.items() if len(hits) > 1}
if not seen:
    print("INFO|No gcode_macro declarations found in the active include graph")
elif not dups:
    print("OK|No duplicate active gcode_macro declarations")
else:
    print("WARN|Duplicate active gcode_macro declarations detected")
    for name in sorted(dups):
        print(f"WARN|  [gcode_macro {name}]:")
        for path, line_no in dups[name]:
            print(f"WARN|    {path}:{line_no}")
' 2>/dev/null || true)

    if [ -z "$summary" ]; then
        warn "Duplicate macro scan returned no parseable output"
        return 0
    fi

    while IFS='|' read -r level message; do
        case "$level" in
            OK) ok "$message" ;;
            INFO) info "$message" ;;
            *) warn "$message" ;;
        esac
    done <<< "$summary"
}

check_invalid_klipper_options_readonly() {
    banner "Checking invalid Klipper config options (read-only)"
    local pcfg="${CONFIG_DIR}/printer.cfg"
    if [ ! -f "$pcfg" ]; then
        info "printer.cfg not found - skipping"
        return 0
    fi

    if awk '/^\[bed_mesh\]/{flag=1; next} /^\[/{flag=0} flag && /^[[:space:]]*timeout[[:space:]]*:/{found=1} END{exit !found}' "$pcfg"; then
        warn "Found 'timeout:' inside [bed_mesh] in printer.cfg"
    else
        ok "[bed_mesh] check 1/2: no invalid 'timeout:' found"
    fi
    if awk '/^\[bed_mesh\]/{flag=1; next} /^\[/{flag=0} flag && /^[[:space:]]*gcode[[:space:]]*:/{found=1} END{exit !found}' "$pcfg"; then
        warn "Found 'gcode:' inside [bed_mesh] in printer.cfg"
    else
        ok "[bed_mesh] check 2/2: no invalid 'gcode:' found"
    fi
}

check_orphan_includes_readonly() {
    banner "Checking orphan [include] lines (read-only)"
    local pcfg="${CONFIG_DIR}/printer.cfg"
    if [ ! -f "$pcfg" ]; then
        info "printer.cfg not found - skipping"
        return 0
    fi

    local found=0
    while IFS= read -r line; do
        local target resolved
        target=$(printf '%s' "$line" | sed -n 's/^\[include[[:space:]]\+\([^]]*\)\].*/\1/p' | tr -d ' ')
        [ -z "$target" ] && continue
        resolved="${CONFIG_DIR}/${target#./}"
        if [[ "$resolved" == *[\*\?\[]* ]]; then
            if ! compgen -G "$resolved" >/dev/null; then
                warn "  ${line}   (missing: ${target})"
                found=1
            fi
        elif [ ! -f "$resolved" ]; then
            warn "  ${line}   (missing: ${target})"
            found=1
        fi
    done < <(grep -E '^\[include ' "$pcfg" 2>/dev/null || true)

    if [ "$found" -eq 0 ]; then
        ok "All [include] targets exist"
    fi
}

run_readonly_diagnostics() {
    banner "Health Check / Read-only Diagnostics"
    warn "This firmware layout is not enabled for general AIO mutations."
    warn "Running diagnostics only: no backups, repairs, service changes, or file edits."

    show_layout_report
    verify_klipper_runtime_health
    verify_stock_display_runtime_health
    if [ "$CAMERA_STACK" = "crowsnest" ]; then
        verify_systemd_service_health crowsnest "Crowsnest camera stack" false
    fi
    report_firmware_layout_files
    report_stock_macro_layout
    report_qidi_box_object_inventory
    verify_qidi_box_runtime_sensors
    report_active_config_graph
    if q2_112_probe_installed; then
        ok "1.1.2 compatibility probe artifacts detected"
    else
        info "1.1.2 compatibility probe not installed"
    fi
    if validate_q2_112_restore_contract; then
        ok "Verified 1.1.2 restore contract is ready"
    else
        warn "Verified 1.1.2 restore contract is not ready"
    fi
    if q2_112_restore_rehearsal_passed; then
        ok "1.1.2 isolated restore rehearsal has passed"
    else
        info "1.1.2 isolated restore rehearsal has not passed yet"
    fi
    if q2_112_live_restore_proof_passed; then
        ok "1.1.2 controlled live restore proof has passed"
    else
        info "1.1.2 controlled live restore proof has not passed yet"
    fi
    if q2_112_present_path_restore_proof_passed; then
        ok "1.1.2 captured-present path restore proof has passed"
    else
        info "1.1.2 captured-present path restore proof has not passed yet"
    fi
    if q2_112_runtime_path_restore_proof_passed \
        "$Q2_112_KLIPPER_EXTRAS_PROOF_DIR" \
        "$Q2_112_KLIPPER_EXTRAS_PROOF_TARGET" \
        "$Q2_112_KLIPPER_EXTRAS_PROOF_MARKER"; then
        ok "1.1.2 Klipper extras restore proof has passed"
    else
        info "1.1.2 Klipper extras restore proof has not passed yet"
    fi
    if q2_112_runtime_path_restore_proof_passed \
        "$Q2_112_MOONRAKER_COMPONENTS_PROOF_DIR" \
        "$Q2_112_MOONRAKER_COMPONENTS_PROOF_TARGET" \
        "$Q2_112_MOONRAKER_COMPONENTS_PROOF_MARKER"; then
        ok "1.1.2 Moonraker components restore proof has passed"
    else
        info "1.1.2 Moonraker components restore proof has not passed yet"
    fi
    find_duplicate_macros_readonly
    check_invalid_klipper_options_readonly
    check_orphan_includes_readonly

    banner "Read-only diagnostics complete"
    info "Install, revert, addon, and repair paths remain blocked on this layout."
    press_enter
}

# Prints the active Klipper config graph as NUL-delimited absolute paths, recursively following [include] lines (glob-aware, skips commented includes).
list_active_klipper_configs() {
    local pcfg="${CONFIG_DIR}/printer.cfg"
    [ -f "$pcfg" ] || return 1

    python3 - "$pcfg" <<'PY'
import glob
import os
import re
import sys

include_re = re.compile(r"^\[include\s+([^\]]+)\]$")
seen = set()

def walk(filename):
    filename = os.path.abspath(filename)
    if filename in seen:
        return
    seen.add(filename)
    sys.stdout.write(filename + "\0")
    try:
        with open(filename, encoding="utf-8", errors="replace") as config_file:
            lines = config_file
            for line in lines:
                line = line.split("#", 1)[0].strip()
                match = include_re.match(line)
                if not match:
                    continue
                include_glob = os.path.join(os.path.dirname(filename), match.group(1).strip())
                for child in sorted(glob.glob(include_glob)):
                    if os.path.isfile(child):
                        walk(child)
    except OSError:
        pass

walk(sys.argv[1])
PY
}

# Scans the active printer.cfg include graph for duplicate [gcode_macro NAME] declarations and warns on any found; only reaches files referenced by active [include] lines.
find_duplicate_macros() {
    banner "Scanning for duplicate gcode_macro declarations"

    if [ ! -f "${CONFIG_DIR}/printer.cfg" ]; then
        warn "printer.cfg not found - skipping scan"
        return 0
    fi

    local tmp
    tmp=$(mktemp /tmp/aio_macros.XXXXXX) || return 0

    list_active_klipper_configs | \
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

    warn "Duplicate active gcode_macro declarations detected — Klipper will refuse to load:"
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

# Removes or comments out config files and macros known to cause "gcode command already registered" Klipper crashes when BunnyBox is installed alongside stock Qidi configs. Idempotent.
fix_known_klipper_conflicts() {
    banner "Resolving known Klipper macro conflicts"

    # 1. Adaptive_Mesh.cfg is the old KAMP override that redefined
    #    [gcode_macro BED_MESH_CALIBRATE]. KAMP_settings.cfg is the current
    #    replacement — delete the old file.
    if [ -f "${CONFIG_DIR}/Adaptive_Mesh.cfg" ]; then
        rm -f "${CONFIG_DIR}/Adaptive_Mesh.cfg"
        ok "Removed stale Adaptive_Mesh.cfg (superseded by KAMP_settings.cfg)"
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
    #    KAMP_settings.cfg if it contains an inline definition (older versions).
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
    # Legacy: re-fetch KAMP_settings.cfg if it still carries an inline definition.
    if grep -q '^\[gcode_macro BED_MESH_CALIBRATE\]' "${CONFIG_DIR}/KAMP_settings.cfg" 2>/dev/null; then
        fetch "${REPO_BASE}/KAMP/KAMP_settings.cfg" "${CONFIG_DIR}/KAMP/KAMP_settings.cfg" \
            && ok "Re-fetched KAMP_settings.cfg (removed stale inline BED_MESH_CALIBRATE)" \
            || warn "Could not re-fetch KAMP_settings.cfg — comment out [gcode_macro BED_MESH_CALIBRATE] in it manually"
    fi

    ok "Conflict resolution complete — FIRMWARE_RESTART to apply"
}

# ---------- helixscreen: patch dashboard layout ----------------------
apply_helixscreen_dashboard_layout() {
    local CANONICAL="${HELIX_CONFIG_DIR}/settings.json"
    local BACKUP2="${AIO_HOME}/.helixscreen/settings.json"
    local BACKUP1="/var/lib/helixscreen/settings.json.backup"

    sudo systemctl stop helixscreen

    if [ ! -f "$CANONICAL" ]; then
        err "settings.json not found at ${CANONICAL}"
        sudo systemctl start helixscreen
        return 1
    fi
    if ! python3 -c "import json,sys; json.load(sys.stdin)" < "$CANONICAL" 2>/dev/null; then
        err "settings.json is not valid JSON — cannot patch"
        sudo systemctl start helixscreen
        return 1
    fi

    HELIX_SETTINGS="$CANONICAL" \
    HELIX_BACKUP2="$BACKUP2" \
    HELIX_BACKUP1="$BACKUP1" \
    python3 <<'PYEOF' >/dev/null
import json, os, sys, tempfile, subprocess

CANONICAL = os.environ["HELIX_SETTINGS"]
BACKUP2   = os.environ["HELIX_BACKUP2"]
BACKUP1   = os.environ["HELIX_BACKUP1"]

DESIRED_BY_ID = {
  "printer_image":       {"col": 2,  "colspan": 2, "enabled": True,  "row": 0,  "rowspan": 2},
  "print_status":        {"col": 0,  "colspan": 2, "enabled": True,  "row": 2,  "rowspan": 2},
  "tips":                {"col": -1, "colspan": 2, "enabled": False, "row": -1, "rowspan": 2},
  "temperature":         {"col": 2,  "colspan": 1, "enabled": True,  "row": 2,  "rowspan": 1},
  "shutdown":            {"col": 5,  "colspan": 1, "enabled": False, "row": 3,  "rowspan": 1},
  "lock":                {"col": -1, "colspan": 1, "enabled": False, "row": -1, "rowspan": 1},
  "power_device":        {"col": -1, "colspan": 1, "enabled": False, "row": -1, "rowspan": 1},
  "network":             {"col": -1, "colspan": 1, "enabled": False, "row": -1, "rowspan": 1},
  "firmware_restart":    {"col": 4,  "colspan": 1, "enabled": True,  "row": 1,  "rowspan": 1},
  "ams":                 {"col": 2,  "colspan": 4, "enabled": True,  "row": 3,  "rowspan": 1},
  "tool_switcher":       {"col": -1, "colspan": 1, "enabled": False, "row": -1, "rowspan": 1},
  "led":                 {"col": 4,  "colspan": 1, "enabled": True,  "row": 0,  "rowspan": 1},
  "led_controls":        {"col": 5,  "colspan": 1, "enabled": False, "row": 0,  "rowspan": 1},
  "fan_stack":           {"col": 5,  "colspan": 1, "enabled": True,  "row": 2,  "rowspan": 1},
  "fan":                 {"col": -1, "colspan": 1, "enabled": False, "row": -1, "rowspan": 1},
  "nozzle_temps":        {"col": -1, "colspan": 1, "enabled": False, "row": -1, "rowspan": 1},
  "temp_stack":          {"col": 3,  "colspan": 1, "enabled": False, "row": 3,  "rowspan": 1},
  "thermistor":          {"col": -1, "colspan": 1, "enabled": False, "row": -1, "rowspan": 1},
  "temp_graph":          {"col": -1, "colspan": 2, "enabled": False, "row": -1, "rowspan": 2},
  "preheat":             {"col": 0,  "colspan": 2, "enabled": False, "row": 1,  "rowspan": 1,
                          "config": {"material_index": 3}},
  "active_spool":        {"col": 4,  "colspan": 1, "enabled": False, "row": 2,  "rowspan": 1},
  "filament":            {"col": -1, "colspan": 1, "enabled": False, "row": -1, "rowspan": 1},
  "humidity":            {"col": -1, "colspan": 1, "enabled": False, "row": -1, "rowspan": 1},
  "width_sensor":        {"col": -1, "colspan": 1, "enabled": False, "row": -1, "rowspan": 1},
  "favorite_macro":      {"col": -1, "colspan": 1, "enabled": False, "row": -1, "rowspan": 1},
  "macros":              {"col": -1, "colspan": 1, "enabled": False, "row": -1, "rowspan": 1},
  "motion":              {"col": -1, "colspan": 1, "enabled": False, "row": -1, "rowspan": 1},
  "clock":               {"col": 0,  "colspan": 2, "enabled": True,  "row": 0,  "rowspan": 1},
  "job_queue":           {"col": -1, "colspan": 2, "enabled": False, "row": -1, "rowspan": 2},
  "clog_detection":      {"col": 0,  "colspan": 2, "enabled": True,  "row": 1,  "rowspan": 1},
  "print_stats":         {"col": -1, "colspan": 2, "enabled": False, "row": -1, "rowspan": 2},
  "gcode_console":       {"col": 5,  "colspan": 1, "enabled": True,  "row": 1,  "rowspan": 1},
  "camera":              {"col": -1, "colspan": 2, "enabled": False, "row": -1, "rowspan": 2},
  "notifications":       {"col": 5,  "colspan": 1, "enabled": True,  "row": 0,  "rowspan": 1},
  "bed_temperature":     {"col": 3,  "colspan": 1, "enabled": True,  "row": 2,  "rowspan": 1},
  "chamber_temperature": {"col": 4,  "colspan": 1, "enabled": True,  "row": 2,  "rowspan": 1},
  "control_buttons":     {"col": -1, "colspan": 2, "enabled": False, "row": -1, "rowspan": 1},
}

def check_no_dups(path):
    def hook(pairs):
        d = {}
        for k, v in pairs:
            if k in d:
                raise ValueError(f"Duplicate key: {k!r}")
            d[k] = v
        return d
    json.load(open(path), object_pairs_hook=hook)

def write_direct(path, content):
    """Write directly, following symlinks. Never use os.replace() — it breaks symlinks."""
    with open(path, "w") as f:
        f.write(content)

# Load and validate
check_no_dups(CANONICAL)
with open(CANONICAL) as f:
    settings = json.load(f)

# Patch in-place: update each existing widget's fields from DESIRED_BY_ID
widgets = settings["printers"]["default"]["panel_widgets"]["home"]["pages"][0]["widgets"]
updated = 0
for w in widgets:
    if w["id"] in DESIRED_BY_ID:
        for k, v in DESIRED_BY_ID[w["id"]].items():
            w[k] = v
        updated += 1
print(f"Updated {updated}/{len(widgets)} widgets")

content = json.dumps(settings, indent=2) + "\n"

# Validate output before writing
tf_path = None
try:
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as tf:
        tf.write(content)
        tf_path = tf.name
    check_no_dups(tf_path)
except ValueError as e:
    print(f"ABORT: output has duplicate keys: {e}", file=sys.stderr)
    sys.exit(1)
finally:
    if tf_path:
        try: os.unlink(tf_path)
        except: pass

# Write all three locations
write_direct(CANONICAL, content)
print(f"OK {CANONICAL}")

backup2_dir = os.path.dirname(BACKUP2)
if os.path.isdir(backup2_dir):
    write_direct(BACKUP2, content)
    print(f"OK  {BACKUP2}")
else:
    print(f"SKIP {BACKUP2} (directory does not exist — HelixScreen will create it on first save)")

# /var/lib is root-owned — sudo sh -c 'cat >' is the only reliable method
result = subprocess.run(
    ["sudo", "sh", "-c", f"cat > {BACKUP1}"],
    input=content, text=True
)
if result.returncode == 0:
    print(f"OK {BACKUP1}")
else:
    print(f"WARNING: could not write {BACKUP1} — layout will apply but may revert on next "
          f"HelixScreen update", file=sys.stderr)
PYEOF

    if [ $? -ne 0 ]; then
        err "Dashboard layout patch failed"
        sudo systemctl start helixscreen
        return 1
    fi

    sudo systemctl start helixscreen
    ok "HelixScreen dashboard layout applied"
}

# ---------- install: BunnyBox (shared core + display choice) ---------
_install_bunnybox() {
    banner "Install: BunnyBox & HelixScreen (Q2 with Qidi Box)"

    preflight || { press_enter; return 1; }
    take_snapshot || { press_enter; return 1; }

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
            warn "BunnyBox did not finish installing — skipping BunnyBox macro step."
            warn "HelixScreen and KAMP will still be installed."
        fi
        ok "BunnyBox install step complete"

        # Write marker only after BunnyBox has confirmed installation —
        # the filament-removal prompt inside the BunnyBox sub-installer
        # runs before this point, so a cancel there leaves no marker.
        write_aoi_ini "BunnyBox" "${AIO_VERSION}" "${AIO_VERSION}"

        banner "Installing HelixScreen"
        run_remote_script "$HELIXSCREEN_INSTALLER"
        local hs_exit=$?
        if [ $hs_exit -ne 0 ]; then
            err "HelixScreen installer failed with exit ${hs_exit}"
            return 1
        fi
        ok "HelixScreen install step complete"
        banner "Installing unified gcode_macro.cfg & printer.cfg"
        banner "Installing unified gcode_macro.cfg & printer.cfg"
        fetch "${REPO_BASE}/macros/gcode_macro-BunnyBox.cfg" \
              "${CONFIG_DIR}/gcode_macro.cfg" || return 1
        fetch "${REPO_BASE}/macros/printer-BunnyBox.cfg" \
              "${CONFIG_DIR}/printer.cfg" || return 1

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

        banner "Applying KAMP settings"
        clean_kamp_dir
        fetch "${REPO_BASE}/KAMP/KAMP_settings.cfg"    "${CONFIG_DIR}/KAMP/KAMP_settings.cfg"    || return 1
        fetch "${REPO_BASE}/KAMP/Adaptive_Meshing.cfg" "${CONFIG_DIR}/KAMP/Adaptive_Meshing.cfg" || return 1
        fetch "${REPO_BASE}/KAMP/Line_Purge.cfg"       "${CONFIG_DIR}/KAMP/Line_Purge.cfg"       || return 1
        fetch "${REPO_BASE}/KAMP/Smart_Park.cfg"       "${CONFIG_DIR}/KAMP/Smart_Park.cfg"       || return 1
        ok "KAMP settings and sub-files applied to ${CONFIG_DIR}/KAMP/"

        switch_display_to_helixscreen
        info "HelixScreen is running its first-time setup wizard on the printer screen."
        info "Please walk to the printer, complete the wizard, then return here."
        printf '\n'
        while true; do
            printf '  Have you completed the HelixScreen startup wizard? [y/N]: '
            read -r _wizard_done
            case "$_wizard_done" in
                y|Y|yes|YES) break ;;
                *) info "Take your time — press y when done." ;;
            esac
        done
        if ! python3 - "${HELIX_CONFIG_DIR}/settings.json" 2>/dev/null <<'PYCHECK'
import json, sys
d = json.load(open(sys.argv[1]))
assert "panel_widgets" in d.get("printers", {}).get("default", {})
PYCHECK
        then
            warn "settings.json does not yet have panel_widgets — skipping dashboard layout patch"
            warn "Run Testing > option 10 after completing the HelixScreen wizard to apply the layout"
        else
            apply_helixscreen_dashboard_layout
        fi

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
  2. Verify:    systemctl status klipper
  3. First-time only - calibrate MMU gear steppers:
        ${C_CYAN}MMU_CALIBRATE_GEAR GATE=0 LENGTH=100${C_RESET}
     Mark filament, measure travel, re-run with MEASURED=<mm>

${C_YELLOW}Recommended:${C_RESET} Install Mainsail (option 7) for box controls. Qidi's
stock UI and Fluidd fork only recognize Qidi's own software talking to
the box — they will not detect or control the box when BunnyBox is
managing it. Mainsail's web interface provides the equivalent panel.

Install log:    ${INSTALL_LOG}
Config snapshot: ${SNAPSHOT_DIR}
EOF

    press_enter
}

install_bunnybox_helixscreen() { _install_bunnybox; }

# ---------- install: Just Faster Printer -----------------------------
install_just_faster() {
    banner "Install: Just Faster Printer (Q2 without Box)"

    preflight || { press_enter; return 1; }
    do_backup || { press_enter; return 1; }

    info "Updating gcode_macro.cfg..."
    fetch "${REPO_BASE}/macros/gcode_macro-JustFasterPrinter.cfg" \
          "${CONFIG_DIR}/gcode_macro.cfg" || { press_enter; return 1; }
    ok "gcode_macro.cfg installed"

    info "Updating printer.cfg..."
    fetch "${REPO_BASE}/macros/JustFasterPrinter.cfg" \
          "${CONFIG_DIR}/printer.cfg" || { press_enter; return 1; }
    ok "printer.cfg installed"

    info "Applying KAMP settings..."
    clean_kamp_dir
    fetch "${REPO_BASE}/KAMP/KAMP_settings.cfg"    "${CONFIG_DIR}/KAMP/KAMP_settings.cfg"    || { press_enter; return 1; }
    fetch "${REPO_BASE}/KAMP/Adaptive_Meshing.cfg" "${CONFIG_DIR}/KAMP/Adaptive_Meshing.cfg" || { press_enter; return 1; }
    fetch "${REPO_BASE}/KAMP/Line_Purge.cfg"       "${CONFIG_DIR}/KAMP/Line_Purge.cfg"       || { press_enter; return 1; }
    fetch "${REPO_BASE}/KAMP/Smart_Park.cfg"       "${CONFIG_DIR}/KAMP/Smart_Park.cfg"       || { press_enter; return 1; }
    ok "KAMP settings and sub-files applied to ${CONFIG_DIR}/KAMP/"
    write_aoi_ini "JustFasterPrinter" "${AIO_VERSION}" "${AIO_VERSION}"

    verify_jfp_install

    banner "Install complete"
    cat <<EOF
${C_BOLD}Your Q2 is now running the 'Just Faster' setup.${C_RESET}
  No Bunny Box, no HelixScreen - just cleaner macros and faster starts.

${C_BOLD}Next steps:${C_RESET}
  1. FIRMWARE_RESTART (Klipper console or stock screen)

Config snapshot: ${SNAPSHOT_DIR}
EOF

    press_enter
}

install_just_faster_box() {
    banner "Install: Just Faster Box (Q2 with Qidi Box)"

    preflight || { press_enter; return 1; }
    do_backup || { press_enter; return 1; }

    # Warn if BunnyBox/Happy Hare is already installed — JFB is incompatible
    # with BunnyBox. Running JFB on top of BunnyBox will leave the MMU config
    # in place but remove the macros that drive it, causing Klipper errors.
    if bunnybox_installed; then
        warn "BunnyBox / Happy Hare appears to be installed on this printer."
        warn "JFB (Just Faster Box) is incompatible with BunnyBox — it provides"
        warn "its own box macros without Happy Hare's MMU system."
        warn "Installing JFB on top of BunnyBox may cause Klipper errors."
        if ! confirm "Proceed with JFB install anyway?"; then
            info "JFB install cancelled. To remove BunnyBox, use the native BunnyBox uninstaller."
            press_enter
            return 0
        fi
    fi

    info "Updating gcode_macro.cfg..."
    fetch "${REPO_BASE}/macros/gcode_macro-JustFasterBox.cfg" \
          "${CONFIG_DIR}/gcode_macro.cfg" || { press_enter; return 1; }
    ok "gcode_macro.cfg installed"

    info "Updating printer.cfg..."
    fetch "${REPO_BASE}/macros/JustFasterPrinter.cfg" \
          "${CONFIG_DIR}/printer.cfg" || { press_enter; return 1; }
    ok "printer.cfg installed"

    info "Applying KAMP settings..."
    clean_kamp_dir
    fetch "${REPO_BASE}/KAMP/KAMP_settings.cfg"    "${CONFIG_DIR}/KAMP/KAMP_settings.cfg"    || { press_enter; return 1; }
    fetch "${REPO_BASE}/KAMP/Adaptive_Meshing.cfg" "${CONFIG_DIR}/KAMP/Adaptive_Meshing.cfg" || { press_enter; return 1; }
    fetch "${REPO_BASE}/KAMP/Line_Purge.cfg"       "${CONFIG_DIR}/KAMP/Line_Purge.cfg"       || { press_enter; return 1; }
    fetch "${REPO_BASE}/KAMP/Smart_Park.cfg"       "${CONFIG_DIR}/KAMP/Smart_Park.cfg"       || { press_enter; return 1; }
    ok "KAMP settings and sub-files applied to ${CONFIG_DIR}/KAMP/"
    write_aoi_ini "JustFasterBox" "${AIO_VERSION}" "${AIO_VERSION}"

    verify_jfb_install

    banner "Install complete"
    cat <<EOF
${C_BOLD}Your Q2 is now running the 'Just Faster Box' setup.${C_RESET}
  Stock Qidi Box controls, no BunnyBox, no HelixScreen — just cleaner macros and faster starts.

${C_BOLD}Next steps:${C_RESET}
  1. FIRMWARE_RESTART (Klipper console or stock screen)

Config snapshot: ${SNAPSHOT_DIR}
EOF

    press_enter
}

# ---------- about ----------------------------------------------------
show_about() {
    banner "About - Qidi Q2 Superuser AIO"
    cat <<EOF
${C_CYAN}Qidi Q2 Superuser - All-in-One Installer${C_RESET}
${C_BOLD}Version:${C_RESET} ${AIO_VERSION}
${C_BOLD}Detected layout:${C_RESET} ${AIO_LAYOUT_NAME} (${AIO_LAYOUT})
${C_BOLD}Mutation support:${C_RESET} ${AIO_LAYOUT_SUPPORTS_MUTATION}
${C_BOLD}AIO home/config:${C_RESET} ${AIO_HOME} / ${CONFIG_DIR}
${C_BOLD}Stock display stack:${C_RESET} $(stock_display_stack_label)
${C_BOLD}Macro/camera layout:${C_RESET} ${MACRO_LAYOUT} / ${CAMERA_STACK}

A community-built toolkit to unlock advanced features on the Qidi Q2
3D printer beyond stock Qidi firmware. This menu is the single entry
point for every supported install / uninstall path.

${C_BOLD}What it can install:${C_RESET}

  ${C_GREEN}BunnyBox, Happy Hare & HelixScreen${C_RESET}  (Q2 ${C_BOLD}with${C_RESET} the Qidi Box)
    - Happy Hare MMU firmware/macros for four-slot multi-material printing
    - HelixScreen replacement touchscreen UI
    - Unified printer.cfg + gcode_macro.cfg and KAMP adaptive meshing
    - ${C_CYAN}Strips the HELIX_QIDI_BOX_WRITE drop-in${C_RESET} if present so
      Happy Hare alone owns Qidi Box write commands and avoids contention
    - AMS spool style set to '3d' for Qidi Box slot visualization

  ${C_GREEN}Just Faster Printer${C_RESET}    (Q2 ${C_BOLD}without${C_RESET} the Box, stock screen)
    - Faster, cleaner PRINT_START / PRINT_END macros
    - KAMP adaptive meshing, screws_tilt_adjust, Spoolman hooks
    - No UI changes - stock Qidi screen stays

${C_BOLD}Optional addons:${C_RESET}
  - Mainsail: web UI on port ${MAINSAIL_PORT}, including camera proxy setup

${C_BOLD}Health Check / Run Verifiers:${C_RESET}
  - Reports Klipper, Moonraker, Happy Hare/MMU, HelixScreen, Qidi Box
    sensor/heater, Mainsail, and camera runtime health when applicable.
  - Scans active Klipper includes for duplicate macros, orphan includes,
    invalid options, and leftover MMU artifacts; prompts before repairs.
  - On unsupported layouts such as Q2 firmware 1.1.2, option 9 runs in
    read-only diagnostics mode: layout, services, Qidi Box objects,
    stock macro layout, active include graph, and config scans only.

${C_BOLD}1.1.2 compatibility round-trip probe:${C_RESET}
  - Option 9 installs one harmless no-op macro config and one include
    line after verifying the guarded stock baseline is safe.
  - It records exact before/after printer.cfg hashes and an original copy.
  - Running option 9 again restores the exact original printer.cfg,
    removes the probe config, and verifies the original hash.
  - Cleanup refuses to overwrite printer.cfg if unrelated changes were
    made after the probe was installed.

${C_BOLD}1.1.2 restore contract:${C_RESET}
  - Option 4 can atomically capture a verified restore contract after
    the guarded stock baseline passes.
  - The contract preserves the exact config tree, Klipper extras,
    Moonraker components, mapped display/runtime and system integration
    paths, their present/absent state, file hashes, metadata, symlink
    targets, service states, default boot target, and Debian package inventory.
  - Option 4 previews the exact contract-backed restore plan. Option 8
    verifies contract integrity without modifying active printer state.
  - Full install and general real revert remain blocked while the
    1.1.2 compatibility lane is tested.

${C_BOLD}1.1.2 isolated restore rehearsal:${C_RESET}
  - Option 10 reconstructs the sealed config and external recovery trees
    only under ${Q2_112_REHEARSAL_DIR}.
  - It verifies file hashes, ownership, permissions, timestamps, and
    symlink targets against the contract, then generates non-executing
    config/path/service/package restore plans.
  - Before and after guards verify the active config tree, service
    enablement, default target, and package inventory were untouched.
  - It never writes to active /home/qidi runtime trees, /etc, packages,
    or services. Full install and general real revert remain blocked.

${C_BOLD}1.1.2 controlled live restore proof:${C_RESET}
  - Option 11 requires a verified stock restore contract, a passed
    isolated rehearsal, and an active config tree exactly matching the
    sealed contract.
  - It creates one harmless non-included config marker and one marker
    under a path captured absent, then performs a real contract-backed
    config restore using rsync --delete.
  - It removes only the identified external proof path, verifies the
    exact stock config and guarded system state, and retains an emergency
    config snapshot if any verification fails.
  - Option 8 validates the sealed historical proof and stored guards
    without requiring stock processes to preserve active config metadata
    unchanged after a reboot.
  - Full install and general real revert remain blocked.

${C_BOLD}1.1.2 external restore audit:${C_RESET}
  - Option 12 compares every captured-present and captured-absent
    external path against the sealed stock contract.
  - It uses checksum-backed rsync --dry-run --itemize-changes to report
    exactly what a future restore would replace or remove.
  - It does not write files or change packages, services, or boot targets.

${C_BOLD}1.1.2 captured-present path restore proof:${C_RESET}
  - Option 13 requires every mapped external path to exactly match the
    sealed stock contract.
  - It creates one ignored marker without a .conf extension under
    ${Q2_112_PRESENT_PROOF_TARGET}, then restores only that directory
    from the sealed contract using rsync --delete.
  - It does not run daemon-reload or restart services, and verifies
    QIDIClient remains active plus all guarded printer state is unchanged.

${C_BOLD}1.1.2 loaded runtime-path restore proofs:${C_RESET}
  - Options 14 and 15 independently test sealed restoration of the stock
    Klipper extras and Moonraker components directories.
  - Each creates one hidden marker without a .py extension, permits only
    that marker in the final safety comparison, then restores one directory
    from the sealed contract using rsync --delete.
  - They do not reload Python or restart services. Klipper, Moonraker,
    QIDIClient, and Crowsnest must remain active, and all guarded config,
    service, boot-target, and package state must remain unchanged.

${C_BOLD}What it can uninstall:${C_RESET}
  - 'Revert to Backup' is the supported full restore path.
  - Revert removes HelixScreen, BunnyBox/Happy Hare source tree, klipper
    extras, and moonraker component, then restores ${CONFIG_DIR}/ from the
    AIO stock snapshot via rsync --delete (no manual file surgery).
  - Revert re-enables $(stock_display_stack_label) and sets graphical.target.
    Service logs are printed if the stock display stack fails to verify.
  - Config restore uses a single fixed snapshot at ${SNAPSHOT_DIR}/,
    captured once before the first install action. All AIO-written config
    files are absent from the snapshot and removed automatically by --delete.

${C_BOLD}Safety:${C_RESET}
  The first install action snapshots ${CONFIG_DIR}/ to ${SNAPSHOT_DIR}/
  before making any changes. Subsequent installs skip the snapshot so the
  pre-AIO state is preserved. A marker file (${AIO_MARKER}) gates this.
  Health-check repairs also call do_backup() before editing configs.
  Firmware layout detection resolves active home/config/service names.
  Option 8 read-only diagnostics is allowed on all layouts.
  Option 4 dry-run reporting is allowed on unsupported layouts.
  Option 4 guarded 1.1.2 baseline capture only writes under ${BACKUP_ROOT}/.
  Option 4 guarded 1.1.2 restore-contract capture only writes under ${BACKUP_ROOT}/.
  Run FIRMWARE_RESTART after an install or revert.
  Refuses to run as root.

${C_BOLD}Known limitations:${C_RESET}
  - ${C_YELLOW}MMU_CALIBRATE_GEAR${C_RESET} is required after clean installs.
  - Qidi Q2 firmware 1.1.2 / V01.01.02.01 uses a new /home/qidi
    layout and qidi-client stock UI. AIO currently detects the new
    paths/services and blocks mutating actions on that layout.
  - BunnyBox currently requires HelixScreen for MMU workflows; the
    stock Qidi screen does not yet expose the MMU UI.

${C_BOLD}Repo:${C_RESET}     ChanceVegas/Qidi-Q2-superuser_helpinghands
${C_BOLD}Upstream:${C_RESET} Camden-Winder/Qidi-Q2-superuser (uninstall lineage)
EOF
    press_enter
}

# ---------- main menu ------------------------------------------------
show_status_line() {
    local bb_status helixscreen_status box_write_status mainsail_status firmware_status just_faster_status
    if layout_supports_mutation; then
        firmware_status="${C_GREEN}$(q2_firmware_layout_label)${C_RESET}"
    else
        firmware_status="${C_RED}$(q2_firmware_layout_label)${C_RESET}"
    fi
    if just_faster_box_installed; then
        just_faster_status="${C_GREEN}Just Faster Box${C_RESET}"
    elif just_faster_printer_installed; then
        just_faster_status="${C_GREEN}Just Faster Printer${C_RESET}"
    else
        just_faster_status="${C_YELLOW}not found${C_RESET}"
    fi
    if bunnybox_installed; then
        bb_status="${C_GREEN}installed${C_RESET}"
    else
        bb_status="${C_YELLOW}not found${C_RESET}"
    fi
    if helixscreen_installed; then
        helixscreen_status="${C_GREEN}installed${C_RESET}"
    else
        helixscreen_status="${C_YELLOW}not found${C_RESET}"
    fi
    if mainsail_installed; then
        mainsail_status="${C_GREEN}installed${C_RESET}"
    else
        mainsail_status="${C_YELLOW}not found${C_RESET}"
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
    printf '  Just Faster: %b | BunnyBox: %b | Helixscreen: %b\n' \
           "$just_faster_status" "$bb_status" "$helixscreen_status"
    printf '  BoxWrite: %b | Mainsail: %b\n' \
           "$box_write_status" "$mainsail_status"
    printf '  Firmware: %b\n' "$firmware_status"
}

q2_112_submenu() {
    if [ "$AIO_LAYOUT" != "q2_112" ]; then
        err "This submenu is only available on firmware 01.01.02+ (qidi layout)."
        err "Detected layout: ${AIO_LAYOUT_NAME}"
        press_enter
        return 0
    fi
    while true; do
        clear 2>/dev/null || true
        printf '%s============================================%s\n' "$C_BOLD$C_MAGENTA" "$C_RESET"
        printf '%s   01.01.02+ / qidi firmware%s\n'                "$C_BOLD$C_MAGENTA" "$C_RESET"
        printf '%s============================================%s\n' "$C_BOLD$C_MAGENTA" "$C_RESET"
        printf '  Layout: %s\n' "$AIO_LAYOUT_NAME"
        printf '  Home:   %s\n' "$AIO_HOME"
        printf '%s--------------------------------------------%s\n' "$C_BOLD" "$C_RESET"
        printf '  %sINSTALL%s\n' "$C_BOLD$C_GREEN" "$C_RESET"
        printf '   %s1)%s Just Faster Printer   (no Box)\n'          "$C_CYAN" "$C_RESET"
        printf '   %s2)%s Just Faster Box        (with Qidi Box, no BunnyBox)\n' "$C_CYAN" "$C_RESET"
        printf '  %sUNINSTALL%s\n' "$C_BOLD$C_YELLOW" "$C_RESET"
        printf '   %s3)%s Revert to Backup       (full uninstall + restore stock)\n' "$C_CYAN" "$C_RESET"
        printf '  %sINFO%s\n' "$C_BOLD$C_CYAN" "$C_RESET"
        printf '   %s4)%s Show layout report\n'                       "$C_CYAN" "$C_RESET"
        printf '   %s0)%s Back\n'                                      "$C_CYAN" "$C_RESET"
        printf '%s============================================%s\n' "$C_BOLD$C_MAGENTA" "$C_RESET"
        printf '%sEnter selection:%s ' "$C_BOLD" "$C_RESET"
        local choice
        read -r choice </dev/tty || return 0
        case "$choice" in
            1) install_jfp_q2_112 ;;
            2) install_jfb_q2_112 ;;
            3)
                warn "Revert to Backup will restore configs from ${SNAPSHOT_DIR}/."
                if confirm "Proceed with full revert?"; then
                    revert_to_backup
                    press_enter
                fi
                ;;
            4) show_layout_report; press_enter ;;
            0|q|Q|back) return 0 ;;
            *) err "Invalid selection: '$choice'"; sleep 1 ;;
        esac
    done
}

draw_menu() {
    clear 2>/dev/null || true
    printf '%s============================================%s\n' "$C_BOLD$C_MAGENTA" "$C_RESET"
    printf '%s   Qidi Q2 Superuser - AIO Setup Menu (%s)%s\n'   "$C_BOLD$C_MAGENTA" "$AIO_VERSION" "$C_RESET"
    printf '%s============================================%s\n' "$C_BOLD$C_MAGENTA" "$C_RESET"
    show_status_line
    printf '%s--------------------------------------------%s\n' "$C_BOLD" "$C_RESET"
    printf '  %sINSTALL%s\n' "$C_BOLD$C_GREEN" "$C_RESET"
    printf '   %s1)%s Install BunnyBox & HelixScreen    (Q2 with Qidi Box)\n'              "$C_CYAN" "$C_RESET"
    printf '   %s2)%s Install Just Faster Printer       (Q2 without Box)\n'               "$C_CYAN" "$C_RESET"
    printf '   %s3)%s Install Just Faster Box           (Q2 with Qidi Box, no BunnyBox)\n' "$C_CYAN" "$C_RESET"
    printf '   %s4)%s Update Macros                     (re-fetch AOI macro files)\n'     "$C_CYAN" "$C_RESET"
    printf '  %sUNINSTALL%s\n' "$C_BOLD$C_YELLOW" "$C_RESET"
    printf '   %s5)%s Revert to Backup                  (full uninstall + restore stock)\n' "$C_CYAN" "$C_RESET"
    printf '   %s6)%s Uninstall Mainsail                 (remove web UI only)\n'            "$C_CYAN" "$C_RESET"
    printf '  %sADDONS%s\n' "$C_BOLD$C_MAGENTA" "$C_RESET"
    printf '   %s7)%s Mainsail                          (web UI on port 100)\n'            "$C_CYAN" "$C_RESET"
    printf '  %sINFO%s\n' "$C_BOLD$C_CYAN" "$C_RESET"
    printf '   %s8)%s About\n'                                                             "$C_CYAN" "$C_RESET"
    printf '   %s9)%s Health Check / Run Verifiers\n'                                      "$C_CYAN" "$C_RESET"
    printf '  %sTESTING%s\n' "$C_BOLD$C_YELLOW" "$C_RESET"
    printf '   %s10)%s Testing\n'                                                          "$C_CYAN" "$C_RESET"
    printf '  %sFIRMWARE%s\n' "$C_BOLD$C_YELLOW" "$C_RESET"
    printf '   %s11)%s 01.01.02+ / qidi firmware\n'                                       "$C_CYAN" "$C_RESET"
    printf '   %s0)%s Exit\n'                                                              "$C_CYAN" "$C_RESET"
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
    printf '  %sNote: This tool will make significant changes to your%s\n' "$C_BOLD" "$C_RESET"
    printf '  %sprinter'"'"'s configuration files. If you have made custom%s\n' "$C_BOLD" "$C_RESET"
    printf '  %smodifications to your configuration, they may be%s\n' "$C_BOLD" "$C_RESET"
    printf '  %soverwritten. Review your setup before proceeding.%s\n' "$C_BOLD" "$C_RESET"
    printf '\n'
    printf '%s============================================%s\n' "$C_BOLD$C_YELLOW" "$C_RESET"
    printf '\n'
    if ! confirm "I understand and wish to continue"; then
        info "Exiting."
        exit 0
    fi
}

testing_submenu() {
    while true; do
        clear 2>/dev/null || true
        printf '%s============================================%s\n' "$C_BOLD$C_YELLOW" "$C_RESET"
        printf '%s   Testing Tools%s\n' "$C_BOLD$C_YELLOW" "$C_RESET"
        printf '%s============================================%s\n' "$C_BOLD$C_YELLOW" "$C_RESET"
        printf '  %sSNAPSHOT%s\n' "$C_BOLD$C_GREEN" "$C_RESET"
        printf '   %s1)%s Force Snapshot Capture   (overwrites snapshot with current config)\n' "$C_CYAN" "$C_RESET"
        printf '   %s2)%s Force Config Restore     (rsync --delete from snapshot to config)\n' "$C_CYAN" "$C_RESET"
        printf '  %s1.1.2 PROBES%s\n' "$C_BOLD$C_CYAN" "$C_RESET"
        printf '   %s3)%s 1.1.2 Compatibility Probe          (reversible round trip)\n' "$C_CYAN" "$C_RESET"
        printf '   %s4)%s 1.1.2 Restore Rehearsal             (isolated, no live changes)\n' "$C_CYAN" "$C_RESET"
        printf '   %s5)%s 1.1.2 Live Restore Proof            (controlled contract restore)\n' "$C_CYAN" "$C_RESET"
        printf '   %s6)%s 1.1.2 External Restore Audit         (read-only drift report)\n' "$C_CYAN" "$C_RESET"
        printf '   %s7)%s 1.1.2 Present-Path Restore Proof     (controlled systemd path)\n' "$C_CYAN" "$C_RESET"
        printf '   %s8)%s 1.1.2 Klipper Extras Restore Proof    (controlled runtime path)\n' "$C_CYAN" "$C_RESET"
        printf '   %s9)%s 1.1.2 Moonraker Components Proof      (controlled runtime path)\n' "$C_CYAN" "$C_RESET"
        printf '  %sHELIXSCREEN%s\n' "$C_BOLD$C_CYAN" "$C_RESET"
        printf '   %s10)%s Patch HelixScreen Dashboard Layout  (patches panel_widgets in live settings.json)\n' "$C_CYAN" "$C_RESET"
        printf '   %s0)%s Back\n' "$C_CYAN" "$C_RESET"
        printf '%s============================================%s\n' "$C_BOLD$C_YELLOW" "$C_RESET"
        printf '%sEnter selection:%s ' "$C_BOLD" "$C_RESET"
        local choice
        read -r choice </dev/tty || return 0
        case "$choice" in
            1)
                warn "Force Snapshot Capture will overwrite any existing snapshot."
                if confirm "Capture current config as snapshot now?"; then
                    banner "Force Snapshot Capture"
                    mkdir -p "${SNAPSHOT_DIR}" 2>/dev/null || sudo mkdir -p "${SNAPSHOT_DIR}"
                    if rsync -a "${CONFIG_DIR}/" "${SNAPSHOT_DIR}/" 2>/dev/null || \
                       sudo rsync -a "${CONFIG_DIR}/" "${SNAPSHOT_DIR}/"; then
                        ok "Snapshot written to ${SNAPSHOT_DIR}"
                    else
                        err "Snapshot failed"
                    fi
                    press_enter
                fi
                ;;
            2)
                if [ ! -d "${SNAPSHOT_DIR}" ] || [ -z "$(ls -A "${SNAPSHOT_DIR}" 2>/dev/null)" ]; then
                    err "No snapshot found at ${SNAPSHOT_DIR} — nothing to restore."
                    press_enter
                    continue
                fi
                warn "Force Config Restore will overwrite ${CONFIG_DIR} from snapshot."
                if confirm "Restore config from snapshot now?"; then
                    banner "Force Config Restore"
                    if rsync -a --delete --no-owner --no-group "${SNAPSHOT_DIR}/" "${CONFIG_DIR}/" 2>/dev/null || \
                       sudo rsync -a --delete --no-owner --no-group "${SNAPSHOT_DIR}/" "${CONFIG_DIR}/"; then
                        ok "Config restored from ${SNAPSHOT_DIR}"
                    else
                        err "Restore failed"
                    fi
                    press_enter
                fi
                ;;
            3) menu_q2_112_roundtrip_probe ;;
            4) menu_q2_112_restore_rehearsal ;;
            5) menu_q2_112_live_restore_proof ;;
            6) menu_q2_112_external_restore_audit ;;
            7) menu_q2_112_present_path_restore_proof ;;
            8) menu_q2_112_klipper_extras_restore_proof ;;
            9) menu_q2_112_moonraker_components_restore_proof ;;
            10) apply_helixscreen_dashboard_layout; press_enter ;;
            0|q|Q|back) return 0 ;;
            *) err "Invalid selection: '$choice'"; sleep 1 ;;
        esac
    done
}

main_loop() {
    while true; do
        draw_menu
        local choice
        read -r choice </dev/tty || exit 0
        case "$choice" in
            1) install_bunnybox_helixscreen ;;
            2) install_just_faster ;;
            3) install_just_faster_box ;;
            4)
                if require_supported_firmware_layout "Update Macros"; then
                    update_macros
                else
                    press_enter
                fi
                ;;
            5)
                warn "Revert to Backup will uninstall AIO display/MMU changes,"
                warn "restore configs from ${SNAPSHOT_DIR}/, and re-enable stock $(stock_display_stack_label)."
                if confirm "Proceed with full revert?"; then
                    revert_to_backup
                    press_enter
                fi
                ;;
            6)
                if mainsail_installed; then
                    if confirm "Uninstall Mainsail?"; then
                        uninstall_mainsail
                        press_enter
                    fi
                else
                    info "Mainsail is not installed."
                    press_enter
                fi
                ;;
            7)
                if require_supported_firmware_layout "Mainsail addon"; then
                    menu_mainsail
                else
                    press_enter
                fi
                ;;
            8) show_about ;;
            9)
                if layout_supports_mutation; then
                    run_all_verifiers
                else
                    run_readonly_diagnostics
                fi
                ;;
            10) testing_submenu ;;
            11) q2_112_submenu ;;
            0|q|Q|exit) info "Bye."; exit 0 ;;
            *) err "Invalid selection: '$choice'"; sleep 1 ;;
        esac
    done
}

show_disclaimer
main_loop
