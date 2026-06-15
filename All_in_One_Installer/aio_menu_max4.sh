#!/bin/bash
# =====================================================================
# Qidi Max 4 Superuser - All-in-One (AIO) Installer / Manager
#
# Sibling to aio_menu.sh (Q2). All Max 4 specific — do not confuse
# the two. The Q2 script is unchanged by this file.
#
# Install paths:
#   1) Just Faster Printer  — optimised macros, no Qidi Box
#   2) Just Faster Box      — same + enables Qidi Box at runtime
#   3) System Optimizations — DNS fix, APT, service hardening, GIFs
#   4) Revert to Backup     — full uninstall + restore stock configs
#   5) About
#   6) Run all verifiers
#   0) Exit
#
# Target: Qidi Max 4, ARM Linux Debian Bullseye, user 'qidi'.
# Do NOT run as root.
# =====================================================================

set -uo pipefail

# ---------- version --------------------------------------------------
AIO_VERSION='Max4-RC1.01'

# ---------- constants ------------------------------------------------
AIO_USER='qidi'
AIO_HOME='/home/qidi'
CONFIG_DIR="${AIO_HOME}/printer_data/config"
BACKUP_ROOT="${AIO_HOME}/mudstockbackups"
STOCK_MACRO_DIR="${CONFIG_DIR}/klipper-macros-qd"
QIDI_CLIENT_DIR="${AIO_HOME}/QIDI_Client"

REPO_REF="${AIO_REPO_REF:-main}"
REPO_BASE="https://raw.githubusercontent.com/Camden-Winder/Qidi-Q2-superuser/refs/heads/${REPO_REF}/Max4"

# AIO marker files
SYSOPTS_MARKER="${BACKUP_ROOT}/.aio_max4_sysopts_applied"

# GIF backup/detection
GIF_DIR="${QIDI_CLIENT_DIR}/access"
GIF_ARCHIVE_URL='https://github.com/thelegendtubaguy/Qidi-Max-4-Optimized/raw/main/system/qidiclient-static-gifs.tar.gz'
GIF_ARCHIVE_SHA256='616c11226addbc09c9d4dc83b0e1d359f15e2f4c1d84c1d8bb008f841d616fce'

# ---------- safety: refuse root --------------------------------------
if [ "$(id -u)" -eq 0 ]; then
    printf '[ERR]  Do not run this script as root.\n' >&2
    printf '[ERR]  Run as the printer user (qidi). It will sudo only where needed.\n' >&2
    exit 1
fi

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

fetch() {
    local url="$1"
    local dest="$2"
    local dest_dir
    dest_dir=$(dirname "$dest")

    if [ ! -d "$dest_dir" ]; then
        mkdir -p "$dest_dir" 2>/dev/null || sudo mkdir -p "$dest_dir" 2>/dev/null
    fi

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

    if install -m 0644 "$tmp" "$dest" 2>/dev/null || \
       sudo install -m 0644 "$tmp" "$dest" 2>/dev/null; then
        rm -f "$tmp"
        return 0
    fi

    rm -f "$tmp"
    err "Failed to write $dest (tried as user and via sudo)"
    return 1
}

# ---------- backup ---------------------------------------------------
do_backup() {
    banner "Backing up current configs"
    mkdir -p "$BACKUP_ROOT"
    local ts
    ts=$(date +%Y%m%d_%H%M%S)
    local backup_dir="${BACKUP_ROOT}/${ts}"
    mkdir -p "$backup_dir"
    if ! rsync -a "${CONFIG_DIR}/" "${backup_dir}/"; then
        err "Backup failed"
        return 1
    fi
    ok "Backup written to ${backup_dir}"

    if [ ! -d "${BACKUP_ROOT}/_FIRST_STOCK" ]; then
        mkdir -p "${BACKUP_ROOT}/_FIRST_STOCK"
        if rsync -a "${CONFIG_DIR}/" "${BACKUP_ROOT}/_FIRST_STOCK/"; then
            ok "First-run stock snapshot saved to ${BACKUP_ROOT}/_FIRST_STOCK"
        else
            warn "Could not write _FIRST_STOCK snapshot (revert will fall back to oldest timestamped backup)"
        fi
    fi
    return 0
}

# ---------- preflight ------------------------------------------------
preflight() {
    banner "Pre-flight checks"

    if [ "$(whoami)" != "$AIO_USER" ]; then
        err "Must run as ${AIO_USER} (got: $(whoami))"
        err "SSH in as ${AIO_USER} and re-run."
        return 1
    fi
    ok "Running as ${AIO_USER}"

    if [ ! -f "${CONFIG_DIR}/printer.cfg" ]; then
        err "Config not found: ${CONFIG_DIR}/printer.cfg"
        err "Is this a Qidi Max 4 running Klipper?"
        return 1
    fi
    ok "printer.cfg found"

    if ! grep -q '\[include klipper-macros-qd/\*\.cfg\]' "${CONFIG_DIR}/printer.cfg" 2>/dev/null; then
        err "printer.cfg does not contain [include klipper-macros-qd/*.cfg]"
        err "Stock Max 4 firmware is required. This config looks non-standard."
        return 1
    fi
    ok "[include klipper-macros-qd/*.cfg] present"

    if ! grep -q '\[gcode_macro g29\]' "${STOCK_MACRO_DIR}/bed_mesh.cfg" 2>/dev/null; then
        err "${STOCK_MACRO_DIR}/bed_mesh.cfg does not contain [gcode_macro g29]"
        err "Expected stock Max 4 firmware. klipper-macros-qd/ looks non-standard."
        return 1
    fi
    ok "klipper-macros-qd/bed_mesh.cfg looks stock"

    if ! grep -q '\[gcode_macro CUT_FILAMENT_1\]' "${STOCK_MACRO_DIR}/filament.cfg" 2>/dev/null; then
        err "${STOCK_MACRO_DIR}/filament.cfg does not contain [gcode_macro CUT_FILAMENT_1]"
        return 1
    fi
    ok "klipper-macros-qd/filament.cfg looks stock"

    if ! grep -q '\[gcode_macro print_start\]' "${STOCK_MACRO_DIR}/start_end.cfg" 2>/dev/null; then
        err "${STOCK_MACRO_DIR}/start_end.cfg does not contain [gcode_macro print_start]"
        return 1
    fi
    ok "klipper-macros-qd/start_end.cfg looks stock"

    # KAMP presence check — BED_MESH_CALIBRATE PROFILE=kamp requires KAMP
    if ! grep -rq 'BED_MESH_CALIBRATE' "${CONFIG_DIR}" 2>/dev/null; then
        err "BED_MESH_CALIBRATE not referenced anywhere in ${CONFIG_DIR}"
        err "KAMP may not be installed. Stock Max 4 firmware ships with KAMP."
        return 1
    fi
    ok "BED_MESH_CALIBRATE referenced in config tree (KAMP present)"

    if ! curl --fail --silent --head --max-time 10 \
         'https://raw.githubusercontent.com' >/dev/null 2>&1; then
        err "Cannot reach raw.githubusercontent.com"
        err "Check network connection and try again."
        return 1
    fi
    ok "Network connectivity"

    ok "Pre-flight complete"
    return 0
}

preflight_jfb_extra() {
    # Additional preflight for Just Faster Box — saved_variables.cfg must exist
    if [ ! -f "${CONFIG_DIR}/saved_variables.cfg" ]; then
        err "${CONFIG_DIR}/saved_variables.cfg not found"
        err "This file is required for Qidi Box support. Restore it from a factory backup."
        err "Minimum content: [Variables]\\nbox_count = 4\\nenable_box = 0\\nz_offset = 0.0"
        return 1
    fi
    local box_count
    box_count=$(grep -E '^box_count\s*=' "${CONFIG_DIR}/saved_variables.cfg" 2>/dev/null \
                | sed 's/.*=\s*//' | tr -d '[:space:]')
    if [ -z "$box_count" ]; then
        err "saved_variables.cfg exists but box_count is not readable"
        return 1
    fi
    ok "saved_variables.cfg: box_count=${box_count}"
    return 0
}

# ---------- config patch helpers -------------------------------------

# Apply a sed substitution to a file only if the old value is present.
# Usage: patch_cfg FILE SECTION OLD_VALUE NEW_VALUE
# Matches the first occurrence of OLD_VALUE after the section header.
patch_cfg_value() {
    local file="$1"
    local section="$2"
    local old_val="$3"
    local new_val="$4"

    if ! grep -q "^\[${section}\]" "$file" 2>/dev/null; then
        warn "patch_cfg_value: section [${section}] not found in ${file}"
        return 0
    fi

    # Only patch if the old value is still present (guard idempotency)
    if ! grep -A 30 "^\[${section}\]" "$file" | grep -q "${old_val}"; then
        info "patch_cfg_value: [${section}] ${old_val} not found — skipping (already patched?)"
        return 0
    fi

    # Use awk to replace the value only within the target section
    local tmp
    tmp=$(mktemp /tmp/aio_patch.XXXXXX) || { err "mktemp failed"; return 1; }
    awk -v section="${section}" -v old="${old_val}" -v new="${new_val}" '
        /^\[/ { in_section = ($0 == "[" section "]") }
        in_section && index($0, old) { sub(old, new) }
        { print }
    ' "$file" > "$tmp" && mv "$tmp" "$file" || { rm -f "$tmp"; return 1; }
    ok "Patched [${section}]: ${old_val} → ${new_val} in ${file}"
}

# Comment out a Klipper section block with ## AIO_DISABLED: prefix
# Matches from the [section header] line to the next [section] or EOF.
comment_out_section() {
    local file="$1"
    local section_header="$2"   # e.g. "[homing_override]"

    if ! grep -qF "$section_header" "$file" 2>/dev/null; then
        info "comment_out_section: '${section_header}' not found in ${file} — skipping"
        return 0
    fi

    # Already disabled?
    if grep -qF "## AIO_DISABLED: ${section_header}" "$file" 2>/dev/null; then
        info "comment_out_section: '${section_header}' already disabled in ${file}"
        return 0
    fi

    local tmp
    tmp=$(mktemp /tmp/aio_patch.XXXXXX) || { err "mktemp failed"; return 1; }
    awk -v hdr="$section_header" '
        $0 == hdr { in_block=1 }
        in_block && /^\[/ && $0 != hdr { in_block=0 }
        in_block { print "## AIO_DISABLED: " $0; next }
        { print }
    ' "$file" > "$tmp" && mv "$tmp" "$file" || { rm -f "$tmp"; return 1; }
    ok "Commented out ${section_header} in ${file}"
}

# Add [include gcode_macro.cfg] to printer.cfg if not already present
ensure_gcode_macro_include() {
    local pcfg="${CONFIG_DIR}/printer.cfg"
    if grep -q '^\[include gcode_macro\.cfg\]' "$pcfg" 2>/dev/null; then
        info "[include gcode_macro.cfg] already present in printer.cfg"
        return 0
    fi
    # Insert after [include klipper-macros-qd/*.cfg]
    local tmp
    tmp=$(mktemp /tmp/aio_patch.XXXXXX) || { err "mktemp failed"; return 1; }
    awk '/^\[include klipper-macros-qd\/\*\.cfg\]/ { print; print "[include gcode_macro.cfg]"; next } { print }' \
        "$pcfg" > "$tmp" && mv "$tmp" "$pcfg" || { rm -f "$tmp"; return 1; }
    ok "Added [include gcode_macro.cfg] to printer.cfg"
}

remove_gcode_macro_include() {
    local pcfg="${CONFIG_DIR}/printer.cfg"
    if ! grep -q '^\[include gcode_macro\.cfg\]' "$pcfg" 2>/dev/null; then
        return 0
    fi
    local tmp
    tmp=$(mktemp /tmp/aio_patch.XXXXXX) || { err "mktemp failed"; return 1; }
    grep -v '^\[include gcode_macro\.cfg\]' "$pcfg" > "$tmp" && mv "$tmp" "$pcfg" || { rm -f "$tmp"; return 1; }
    ok "Removed [include gcode_macro.cfg] from printer.cfg"
}

# Apply all TLTG-equivalent printer.cfg + timelapse.cfg config patches
apply_config_patches() {
    local pcfg="${CONFIG_DIR}/printer.cfg"
    local tcfg="${CONFIG_DIR}/timelapse.cfg"

    info "Applying config patches..."

    patch_cfg_value "$pcfg" "stepper_x" "homing_speed: 50"             "homing_speed: 65"
    patch_cfg_value "$pcfg" "stepper_x" "second_homing_speed: 50.0"    "second_homing_speed: 55.0"
    patch_cfg_value "$pcfg" "stepper_x" "homing_retract_dist: 50.0"    "homing_retract_dist: 20.0"
    patch_cfg_value "$pcfg" "stepper_x" "homing_retract_speed: 200.0"  "homing_retract_speed: 1000.0"

    patch_cfg_value "$pcfg" "stepper_y" "homing_speed: 50"             "homing_speed: 65"
    patch_cfg_value "$pcfg" "stepper_y" "second_homing_speed: 50.0"    "second_homing_speed: 55.0"
    patch_cfg_value "$pcfg" "stepper_y" "homing_retract_dist: 50.0"    "homing_retract_dist: 20.0"
    patch_cfg_value "$pcfg" "stepper_y" "homing_retract_speed: 200.0"  "homing_retract_speed: 1000.0"

    patch_cfg_value "$pcfg" "stepper_z" "homing_retract_dist: 10.0"    "homing_retract_dist: 5.0"
    patch_cfg_value "$pcfg" "z_tilt"   "speed: 150"                    "speed: 600"
    patch_cfg_value "$pcfg" "bed_mesh" "speed: 150"                    "speed: 600"

    # Patch on_error_gcode in virtual_sdcard to call our cancel macro
    patch_cfg_value "$pcfg" "virtual_sdcard" "on_error_gcode: CANCEL_PRINT" \
                    "on_error_gcode: MAX4_CANCEL_PRINT_ON_ERROR"

    # Silence timelapse verbose output if timelapse.cfg exists
    if [ -f "$tcfg" ]; then
        patch_cfg_value "$tcfg" "gcode_macro TIMELAPSE_TAKE_FRAME" \
                        "variable_verbose: True" "variable_verbose: False"
    fi
}

# Comment out stock sections that our macros replace
apply_stock_section_comments() {
    comment_out_section "${STOCK_MACRO_DIR}/kinematics.cfg" "[homing_override]"
    comment_out_section "${STOCK_MACRO_DIR}/start_end.cfg"  "[gcode_macro _km_apply_print_offset]"
}

# Restore stock section comments (undo ## AIO_DISABLED: prefix)
restore_stock_sections() {
    local file
    for file in "${STOCK_MACRO_DIR}/kinematics.cfg" "${STOCK_MACRO_DIR}/start_end.cfg"; do
        if grep -q '## AIO_DISABLED:' "$file" 2>/dev/null; then
            local tmp
            tmp=$(mktemp /tmp/aio_patch.XXXXXX) || { err "mktemp failed"; return 1; }
            sed 's/^## AIO_DISABLED: //' "$file" > "$tmp" && mv "$tmp" "$file" || { rm -f "$tmp"; return 1; }
            ok "Restored stock sections in ${file}"
        fi
    done
}

# ---------- detection helpers ----------------------------------------

just_faster_printer_installed() {
    [ -f "${CONFIG_DIR}/gcode_macro.cfg" ] && \
    grep -q '_km_globals_max4' "${CONFIG_DIR}/gcode_macro.cfg" 2>/dev/null && \
    grep -q '^\[include gcode_macro\.cfg\]' "${CONFIG_DIR}/printer.cfg" 2>/dev/null
}

just_faster_box_installed() {
    just_faster_printer_installed && \
    grep -q 'Just Faster Box' "${CONFIG_DIR}/gcode_macro.cfg" 2>/dev/null
}

system_optimizations_applied() {
    [ -f "$SYSOPTS_MARKER" ]
}

dns_fix_applied() {
    [ -L /etc/resolv.conf ] && \
    [ "$(readlink /etc/resolv.conf)" = "/run/resolvconf/resolv.conf" ]
}

apt_sources_fixed() {
    grep -q 'deb.debian.org' /etc/apt/sources.list 2>/dev/null
}

xl2tpd_disabled() {
    systemctl is-enabled xl2tpd &>/dev/null && \
    [ "$(systemctl is-enabled xl2tpd 2>/dev/null)" = "disabled" ]
}

algo_app_disabled() {
    [ "$(systemctl is-enabled algo_app.service 2>/dev/null)" = "disabled" ]
}

static_gifs_applied() {
    ls "${GIF_DIR}"/.gif-backup-* 2>/dev/null | grep -q '.'
}

# ---------- Just Faster Printer install ------------------------------

install_just_faster_printer() {
    banner "Installing Just Faster Printer"
    info "Fetching macro file..."
    fetch "${REPO_BASE}/macros/gcode_macro-JustFasterPrinter.cfg" \
          "${CONFIG_DIR}/gcode_macro.cfg" || return 1
    ok "gcode_macro.cfg written"

    ensure_gcode_macro_include || return 1
    apply_config_patches
    apply_stock_section_comments

    ok "Just Faster Printer installed"
    verify_just_faster_printer
}

uninstall_just_faster_printer() {
    banner "Removing Just Faster Printer"
    rm -f "${CONFIG_DIR}/gcode_macro.cfg" 2>/dev/null || \
        sudo rm -f "${CONFIG_DIR}/gcode_macro.cfg" 2>/dev/null || true
    remove_gcode_macro_include
    restore_stock_sections
    ok "Just Faster Printer removed"
}

verify_just_faster_printer() {
    just_faster_printer_installed || return 0
    banner "Verifying Just Faster Printer"

    if grep -q '_km_globals_max4' "${CONFIG_DIR}/gcode_macro.cfg" 2>/dev/null; then
        ok "gcode_macro.cfg contains _km_globals_max4"
    else
        warn "gcode_macro.cfg missing _km_globals_max4 — macro may not have been written correctly"
    fi

    if grep -q '^\[include gcode_macro\.cfg\]' "${CONFIG_DIR}/printer.cfg" 2>/dev/null; then
        ok "printer.cfg includes gcode_macro.cfg"
    else
        warn "printer.cfg does not include gcode_macro.cfg"
    fi

    if grep -q '## AIO_DISABLED:.*\[homing_override\]' \
             "${STOCK_MACRO_DIR}/kinematics.cfg" 2>/dev/null; then
        ok "Stock [homing_override] is disabled (replaced by MAX4 macro)"
    else
        warn "Stock [homing_override] may still be active — could conflict with AIO homing macro"
    fi

    if grep -q '## AIO_DISABLED:.*\[gcode_macro _km_apply_print_offset\]' \
             "${STOCK_MACRO_DIR}/start_end.cfg" 2>/dev/null; then
        ok "Stock [gcode_macro _km_apply_print_offset] is disabled (replaced by AIO)"
    else
        warn "Stock [gcode_macro _km_apply_print_offset] may still be active — could conflict"
    fi
}

# ---------- Just Faster Box install ----------------------------------

install_just_faster_box() {
    banner "Installing Just Faster Box"

    # Extra preflight for box
    preflight_jfb_extra || return 1

    info "Fetching macro file..."
    fetch "${REPO_BASE}/macros/gcode_macro-JustFasterBox.cfg" \
          "${CONFIG_DIR}/gcode_macro.cfg" || return 1
    ok "gcode_macro.cfg written"

    ensure_gcode_macro_include || return 1
    apply_config_patches
    apply_stock_section_comments

    # Enable box in saved_variables.cfg if box_count > 0 and enable_box = 0
    _enable_box_in_saved_variables

    ok "Just Faster Box installed"
    verify_just_faster_box
}

_enable_box_in_saved_variables() {
    local svv="${CONFIG_DIR}/saved_variables.cfg"
    local box_count enable_box

    box_count=$(grep -E '^box_count\s*=' "$svv" 2>/dev/null \
                | sed 's/.*=\s*//' | tr -d '[:space:]')
    enable_box=$(grep -E '^enable_box\s*=' "$svv" 2>/dev/null \
                 | sed 's/.*=\s*//' | tr -d '[:space:]')

    if [ "${box_count:-0}" -gt 0 ] 2>/dev/null && [ "${enable_box:-1}" = "0" ]; then
        info "Setting enable_box = 1 in saved_variables.cfg (box_count=${box_count})"
        local tmp
        tmp=$(mktemp /tmp/aio_patch.XXXXXX) || { err "mktemp failed"; return 1; }
        sed 's/^enable_box\s*=.*/enable_box = 1/' "$svv" > "$tmp" && mv "$tmp" "$svv" || { rm -f "$tmp"; return 1; }
        ok "enable_box set to 1 in saved_variables.cfg"
    elif [ "${enable_box:-0}" = "1" ]; then
        ok "enable_box is already 1 in saved_variables.cfg"
    else
        warn "box_count=${box_count:-unknown} — not enabling box automatically (check saved_variables.cfg manually)"
    fi
}

uninstall_just_faster_box() {
    banner "Removing Just Faster Box"
    # Note: we intentionally do NOT touch saved_variables.cfg box_count/enable_box
    # on uninstall. The user may want to re-enable the box path themselves.
    rm -f "${CONFIG_DIR}/gcode_macro.cfg" 2>/dev/null || \
        sudo rm -f "${CONFIG_DIR}/gcode_macro.cfg" 2>/dev/null || true
    remove_gcode_macro_include
    restore_stock_sections
    ok "Just Faster Box removed"
    info "Note: saved_variables.cfg enable_box was not modified on uninstall."
}

verify_just_faster_box() {
    just_faster_box_installed || return 0
    banner "Verifying Just Faster Box"

    verify_just_faster_printer   # reuse common checks

    local svv="${CONFIG_DIR}/saved_variables.cfg"
    if [ -f "$svv" ]; then
        local enable_box
        enable_box=$(grep -E '^enable_box\s*=' "$svv" 2>/dev/null \
                     | sed 's/.*=\s*//' | tr -d '[:space:]')
        if [ "${enable_box:-0}" = "1" ]; then
            ok "saved_variables.cfg: enable_box=1 (box macros active)"
        else
            warn "saved_variables.cfg: enable_box=${enable_box:-not set} — box branches will not fire at runtime"
            warn "  → set enable_box = 1 in ${svv} to activate box features"
        fi
    else
        warn "saved_variables.cfg not found — box runtime state cannot be verified"
    fi
}

# ---------- System Optimizations -------------------------------------

# --- DNS fix ---

install_dns_fix() {
    banner "DNS Fix"
    info "Current /etc/resolv.conf:"
    cat /etc/resolv.conf | head -5 || true

    # Back up existing files
    sudo cp -a /etc/resolvconf/resolv.conf.d/head \
               "${BACKUP_ROOT}/.aio_dns_head.bak" 2>/dev/null || true
    sudo cp -a /etc/resolvconf/resolv.conf.d/tail \
               "${BACKUP_ROOT}/.aio_dns_tail.bak" 2>/dev/null || true
    sudo cp -aL /etc/resolv.conf "${BACKUP_ROOT}/.aio_resolv.conf.bak" 2>/dev/null || true

    # Clear the head file (don't prepend static DNS before DHCP)
    sudo sh -c ': > /etc/resolvconf/resolv.conf.d/head' || { err "Could not clear resolv.conf.d/head"; return 1; }

    # Add public fallbacks to tail
    printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' | \
        sudo tee /etc/resolvconf/resolv.conf.d/tail >/dev/null

    sudo resolvconf -u 2>/dev/null || true
    sudo ln -sfn /run/resolvconf/resolv.conf /etc/resolv.conf
    ok "DNS fix applied — /etc/resolv.conf now points to resolvconf with Cloudflare/Google fallbacks"
}

uninstall_dns_fix() {
    if [ -f "${BACKUP_ROOT}/.aio_resolv.conf.bak" ]; then
        sudo cp -a "${BACKUP_ROOT}/.aio_resolv.conf.bak" /etc/resolv.conf 2>/dev/null && \
            ok "DNS: restored original /etc/resolv.conf" || \
            warn "DNS: could not restore /etc/resolv.conf"
    fi
    if [ -f "${BACKUP_ROOT}/.aio_dns_head.bak" ]; then
        sudo cp -a "${BACKUP_ROOT}/.aio_dns_head.bak" /etc/resolvconf/resolv.conf.d/head 2>/dev/null || true
    fi
    if [ -f "${BACKUP_ROOT}/.aio_dns_tail.bak" ]; then
        sudo cp -a "${BACKUP_ROOT}/.aio_dns_tail.bak" /etc/resolvconf/resolv.conf.d/tail 2>/dev/null || true
    fi
    sudo resolvconf -u 2>/dev/null || true
}

# --- APT sources fix ---

install_apt_sources_fix() {
    banner "APT Sources Fix"
    sudo cp -a /etc/apt/sources.list "${BACKUP_ROOT}/.aio_sources.list.bak" 2>/dev/null || true

    sudo tee /etc/apt/sources.list >/dev/null <<'EOF'
deb http://deb.debian.org/debian bullseye main contrib
deb-src http://deb.debian.org/debian bullseye main contrib
deb http://security.debian.org/debian-security bullseye-security main contrib
deb-src http://security.debian.org/debian-security bullseye-security main contrib
deb http://deb.debian.org/debian bullseye-updates main contrib
deb-src http://deb.debian.org/debian bullseye-updates main contrib
EOF
    ok "APT sources switched to deb.debian.org (standard Debian Bullseye mirrors)"
}

uninstall_apt_sources_fix() {
    if [ -f "${BACKUP_ROOT}/.aio_sources.list.bak" ]; then
        sudo cp -a "${BACKUP_ROOT}/.aio_sources.list.bak" /etc/apt/sources.list && \
            ok "APT: restored original sources.list" || \
            warn "APT: could not restore sources.list"
    fi
}

# --- xl2tpd disable ---

install_disable_xl2tpd() {
    banner "Disable xl2tpd (L2TP VPN daemon)"
    sudo systemctl disable --now xl2tpd 2>/dev/null || true
    ok "xl2tpd disabled"
}

uninstall_disable_xl2tpd() {
    sudo systemctl enable --now xl2tpd 2>/dev/null || true
    ok "xl2tpd re-enabled"
}

# --- algo_app disable ---

install_disable_algo_app() {
    banner "Disable algo_app (AI detection service)"
    warn "This stops the QIDI AI detection features in the touchscreen UI."
    warn "Stock credentials: user=qidi password=qiditech — API on port 9010 will be closed."
    if confirm "Disable algo_app.service?"; then
        sudo systemctl disable --now algo_app.service 2>/dev/null || true
        ok "algo_app disabled"
    else
        info "Skipped algo_app"
    fi
}

uninstall_disable_algo_app() {
    sudo systemctl enable --now algo_app.service 2>/dev/null || true
    ok "algo_app re-enabled"
}

# --- Static qidiclient GIFs ---

install_static_gifs() {
    banner "Static qidiclient GIFs"
    info "Replaces animated UI spinner GIFs with single-frame statics."
    info "This drops touchscreen idle CPU from ~55% to ~3%."
    warn "Spinner animations in the touchscreen UI will freeze on frame 1."

    if [ ! -d "$GIF_DIR" ]; then
        err "GIF directory not found: ${GIF_DIR}"
        err "Is qidiclient installed at ${QIDI_CLIENT_DIR}?"
        return 1
    fi

    local ts gif_backup
    ts=$(date +%Y%m%d_%H%M%S)
    gif_backup="${GIF_DIR}/.gif-backup-${ts}"
    mkdir -p "$gif_backup"

    info "Backing up existing GIFs to ${gif_backup}..."
    find "$GIF_DIR" -maxdepth 1 -name '*.gif' -exec cp -a {} "$gif_backup/" \; 2>/dev/null || true
    ok "GIF backup written to ${gif_backup}"

    info "Downloading static GIF archive..."
    local tmp_archive
    tmp_archive=$(mktemp /tmp/aio_gifs.XXXXXX.tar.gz) || { err "mktemp failed"; return 1; }
    if ! curl --fail --silent --show-error --location \
              "$GIF_ARCHIVE_URL" --output "$tmp_archive"; then
        rm -f "$tmp_archive"
        err "Failed to download GIF archive"
        return 1
    fi

    info "Verifying SHA256..."
    local actual_sha
    actual_sha=$(sha256sum "$tmp_archive" | awk '{print $1}')
    if [ "$actual_sha" != "$GIF_ARCHIVE_SHA256" ]; then
        rm -f "$tmp_archive"
        err "SHA256 mismatch! Expected: ${GIF_ARCHIVE_SHA256}"
        err "Got: ${actual_sha}"
        err "Archive may be corrupt or tampered. Aborting."
        return 1
    fi
    ok "SHA256 verified"

    info "Extracting static GIFs..."
    sudo tar -xzf "$tmp_archive" -C "$GIF_DIR" --no-same-owner 2>/dev/null || \
        tar -xzf "$tmp_archive" -C "$GIF_DIR" --no-same-owner 2>/dev/null || \
        { rm -f "$tmp_archive"; err "Extraction failed"; return 1; }
    rm -f "$tmp_archive"

    # Fix ownership and remove macOS artifacts
    sudo chown -R qidi:netdev "$GIF_DIR"/*.gif 2>/dev/null || true
    sudo chmod 755 "$GIF_DIR"/*.gif 2>/dev/null || true
    find "$GIF_DIR" -maxdepth 1 -name '._*.gif' -delete 2>/dev/null || true

    sudo systemctl restart qidi-client.service 2>/dev/null || true
    ok "Static GIFs installed and qidi-client restarted"
}

uninstall_static_gifs() {
    local gif_backup
    gif_backup=$(ls -1d "${GIF_DIR}"/.gif-backup-* 2>/dev/null | tail -n 1)
    if [ -z "$gif_backup" ]; then
        warn "No GIF backup found under ${GIF_DIR}/.gif-backup-* — cannot restore"
        return 0
    fi
    info "Restoring GIFs from ${gif_backup}..."
    sudo cp -a "${gif_backup}/"*.gif "$GIF_DIR/" 2>/dev/null || \
        cp -a "${gif_backup}/"*.gif "$GIF_DIR/" 2>/dev/null || true
    sudo chown -R qidi:netdev "$GIF_DIR"/*.gif 2>/dev/null || true
    sudo systemctl restart qidi-client.service 2>/dev/null || true
    ok "Original GIFs restored and qidi-client restarted"
}

# --- System optimizations sub-menu ---

install_system_optimizations() {
    banner "System Optimizations"
    info "Each optimization is confirmed individually."
    info "All can be reversed via Revert to Backup."
    echo ""

    if confirm "1) DNS Fix — switch to Cloudflare/Google DNS with proper DHCP integration?"; then
        install_dns_fix || warn "DNS fix encountered a problem"
    else
        info "Skipped DNS fix"
    fi

    if confirm "2) APT Sources Fix — switch from Chinese USTC mirrors to deb.debian.org?"; then
        install_apt_sources_fix || warn "APT sources fix encountered a problem"
    else
        info "Skipped APT sources fix"
    fi

    if confirm "3) Disable xl2tpd — remove unused L2TP VPN daemon?"; then
        install_disable_xl2tpd || warn "xl2tpd disable encountered a problem"
    else
        info "Skipped xl2tpd"
    fi

    install_disable_algo_app || true   # has its own internal confirm

    if confirm "5) Static qidiclient GIFs — freeze UI spinners to reduce idle CPU to ~3%?"; then
        install_static_gifs || warn "Static GIF install encountered a problem"
    else
        info "Skipped static GIFs"
    fi

    touch "$SYSOPTS_MARKER" 2>/dev/null || true
    ok "System optimizations complete"
    verify_system_optimizations
}

uninstall_system_optimizations() {
    banner "Removing system optimizations"
    uninstall_dns_fix
    uninstall_apt_sources_fix
    uninstall_disable_xl2tpd
    uninstall_disable_algo_app
    uninstall_static_gifs
    rm -f "$SYSOPTS_MARKER" 2>/dev/null || true
    ok "System optimizations removed"
}

verify_system_optimizations() {
    system_optimizations_applied || return 0
    banner "Verifying system optimizations"

    if dns_fix_applied; then
        ok "DNS: /etc/resolv.conf is a symlink to resolvconf output"
    else
        warn "DNS: /etc/resolv.conf is not a symlink — DNS fix may not be applied"
    fi

    if apt_sources_fixed; then
        ok "APT: sources.list uses deb.debian.org"
    else
        warn "APT: sources.list does not reference deb.debian.org"
    fi

    if xl2tpd_disabled; then
        ok "xl2tpd: disabled"
    else
        info "xl2tpd: enabled or not installed"
    fi

    if algo_app_disabled; then
        ok "algo_app: disabled"
    else
        info "algo_app: enabled (AI detection features active)"
    fi

    if static_gifs_applied; then
        ok "Static GIFs: backup directory present"
    else
        warn "Static GIFs: no backup directory found — may not be applied"
    fi
}

# ---------- Revert to Backup -----------------------------------------

revert_to_backup() {
    banner "Revert to Backup"

    local restore_src
    if [ -d "${BACKUP_ROOT}/_FIRST_STOCK" ]; then
        restore_src="${BACKUP_ROOT}/_FIRST_STOCK"
        info "Restoring from _FIRST_STOCK snapshot"
    else
        # Fall back to oldest timestamped backup
        restore_src=$(ls -1d "${BACKUP_ROOT}"/[0-9]* 2>/dev/null | sort | head -n 1 || true)
        if [ -z "$restore_src" ]; then
            err "No backup found under ${BACKUP_ROOT}/"
            err "Nothing to restore."
            return 1
        fi
        info "Restoring from oldest timestamped backup: ${restore_src}"
    fi

    # Uninstall everything AIO installed
    if just_faster_box_installed; then
        uninstall_just_faster_box
    elif just_faster_printer_installed; then
        uninstall_just_faster_printer
    fi
    if system_optimizations_applied; then
        uninstall_system_optimizations
    fi

    info "Restoring config from ${restore_src}..."
    if ! rsync -a --delete "${restore_src}/" "${CONFIG_DIR}/"; then
        err "rsync restore failed"
        return 1
    fi
    ok "Config restored from ${restore_src}"

    # Post-revert verifier sweep
    _run_verifiers_core

    ok "Revert complete. Klipper will reload on next restart."
}

# ---------- Verifiers ------------------------------------------------

_run_verifiers_core() {
    verify_just_faster_printer
    verify_just_faster_box
    verify_system_optimizations
}

run_all_verifiers() {
    _run_verifiers_core
    press_enter
}

# ---------- Status line & menu ---------------------------------------

show_status_line() {
    local jfp_status jfb_status sysopts_status

    if just_faster_box_installed; then
        jfb_status="${C_GREEN}installed${C_RESET}"
        jfp_status="${C_YELLOW}(see JFB)${C_RESET}"
    elif just_faster_printer_installed; then
        jfp_status="${C_GREEN}installed${C_RESET}"
        jfb_status="${C_YELLOW}not found${C_RESET}"
    else
        jfp_status="${C_YELLOW}not found${C_RESET}"
        jfb_status="${C_YELLOW}not found${C_RESET}"
    fi

    if system_optimizations_applied; then
        sysopts_status="${C_GREEN}applied${C_RESET}"
    else
        sysopts_status="${C_YELLOW}not applied${C_RESET}"
    fi

    printf '  JFP: %b | JFB: %b | SysOpts: %b\n' \
           "$jfp_status" "$jfb_status" "$sysopts_status"
}

draw_menu() {
    clear 2>/dev/null || true
    printf '%s============================================%s\n' "$C_BOLD$C_MAGENTA" "$C_RESET"
    printf '%s   Qidi Max 4 Superuser - AIO Setup Menu (%s)%s\n' "$C_BOLD$C_MAGENTA" "$AIO_VERSION" "$C_RESET"
    printf '%s============================================%s\n' "$C_BOLD$C_MAGENTA" "$C_RESET"
    show_status_line
    printf '%s--------------------------------------------%s\n' "$C_BOLD" "$C_RESET"
    printf '  %sINSTALL%s\n' "$C_BOLD$C_GREEN" "$C_RESET"
    printf '   %s1)%s Install Just Faster Printer       (Max 4, no Qidi Box)\n' "$C_CYAN" "$C_RESET"
    printf '   %s2)%s Install Just Faster Box           (Max 4 with Qidi Box)\n' "$C_CYAN" "$C_RESET"
    printf '   %s3)%s System Optimizations              (DNS, APT, services, GIFs)\n' "$C_CYAN" "$C_RESET"
    printf '  %sUNINSTALL%s\n' "$C_BOLD$C_YELLOW" "$C_RESET"
    printf '   %s4)%s Revert to Backup                  (full uninstall + restore stock)\n' "$C_CYAN" "$C_RESET"
    printf '  %sINFO%s\n' "$C_BOLD$C_CYAN" "$C_RESET"
    printf '   %s5)%s About\n' "$C_CYAN" "$C_RESET"
    printf '   %s6)%s Run all verifiers\n' "$C_CYAN" "$C_RESET"
    printf '   %s0)%s Exit\n' "$C_CYAN" "$C_RESET"
    printf '%s============================================%s\n' "$C_BOLD$C_MAGENTA" "$C_RESET"
    printf '%sEnter selection:%s ' "$C_BOLD" "$C_RESET"
}

show_about() {
    banner "About"
    cat <<EOF

  ${C_BOLD}Qidi Max 4 AIO Installer${C_RESET}
  Version: ${AIO_VERSION}

  ${C_BOLD}Install paths:${C_RESET}
    Just Faster Printer — optimised macros, no Qidi Box
    Just Faster Box     — same + Qidi Box filament prep enabled

  ${C_BOLD}What gets installed:${C_RESET}
    config/gcode_macro.cfg    — Klipper macro file
    printer.cfg patches       — homing/mesh speed optimisations
    klipper-macros-qd/ edits  — stock [homing_override] and
                                [_km_apply_print_offset] commented out

  ${C_BOLD}Backups:${C_RESET}   ${BACKUP_ROOT}/
  ${C_BOLD}Repo:${C_RESET}      Camden-Winder/Qidi-Q2-superuser
  ${C_BOLD}Upstream:${C_RESET}  thelegendtubaguy/Qidi-Max-4-Optimized (macro source)

  ${C_BOLD}Three install paths (Q2 + Max 4 canon):${C_RESET}
    Just Faster Printer  — stock experience, faster macros, no box
    Just Faster Box      — stock experience, faster macros, box-aware
    BunnyBox+HelixScreen — Happy Hare MMU + LVGL UI (Q2 only, not Max 4)

EOF
    press_enter
}

show_disclaimer() {
    clear 2>/dev/null || true
    printf '%s============================================%s\n' "$C_BOLD$C_YELLOW" "$C_RESET"
    printf '%s   DISCLAIMER%s\n' "$C_BOLD$C_YELLOW" "$C_RESET"
    printf '%s============================================%s\n' "$C_BOLD$C_YELLOW" "$C_RESET"
    printf '\n'
    printf '  This tool modifies Klipper configuration files on your\n'
    printf '  Qidi Max 4 printer. %sUse it at your own risk.%s\n' "$C_BOLD" "$C_RESET"
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
            1)
                if confirm "Install Just Faster Printer?"; then
                    preflight || { press_enter; continue; }
                    do_backup || { press_enter; continue; }
                    install_just_faster_printer || warn "Install had problems (see above)"
                fi
                press_enter
                ;;
            2)
                if confirm "Install Just Faster Box (requires Qidi Box)?"; then
                    preflight || { press_enter; continue; }
                    do_backup || { press_enter; continue; }
                    install_just_faster_box || warn "Install had problems (see above)"
                fi
                press_enter
                ;;
            3)
                install_system_optimizations || warn "System optimizations had problems (see above)"
                press_enter
                ;;
            4)
                warn "Revert to Backup will uninstall AIO changes and restore configs"
                warn "from ${BACKUP_ROOT}/_FIRST_STOCK (or oldest timestamped backup)."
                if confirm "Proceed with full revert?"; then
                    revert_to_backup || warn "Revert had problems (see above)"
                fi
                press_enter
                ;;
            5) show_about ;;
            6) run_all_verifiers ;;
            0|q|Q|exit) info "Bye."; exit 0 ;;
            *) err "Invalid selection: '$choice'"; sleep 1 ;;
        esac
    done
}

show_disclaimer
main_loop
