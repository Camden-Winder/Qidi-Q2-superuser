#!/usr/bin/env bash
# =====================================================================
# Happier Hare - HelixScreen Happy Hare backend patch installer
#
# Applies the Qidi Q2/BunnyBox native dryer patch set to HelixScreen.
# The preferred path is installing a prebuilt patched HelixScreen archive.
# Source patch/build mode is provided for development and CI.
# =====================================================================

set -euo pipefail

HAPPIER_HARE_VERSION='RC2.11'
HELIXSCREEN_PIN='v0.99.70'
HELIXSCREEN_INSTALLER="https://raw.githubusercontent.com/prestonbrown/helixscreen/${HELIXSCREEN_PIN}/scripts/install.sh"
HELIXSCREEN_REPO='https://github.com/prestonbrown/helixscreen.git'
HAPPIER_HARE_REPO_REF="${HAPPIER_HARE_REPO_REF:-main}"
PATCH_URL="${HAPPIER_HARE_PATCH_URL:-https://raw.githubusercontent.com/Camden-Winder/Qidi-Q2-superuser/refs/heads/${HAPPIER_HARE_REPO_REF}/Happier_Hare/patches/helixscreen-v0.99.70-happier-hare.patch}"
PATCHED_ZIP_URL="${HAPPIER_HARE_ZIP_URL:-}"
WORK_ROOT="${HAPPIER_HARE_WORK_ROOT:-/home/mks/happier-hare}"
SOURCE_DIR="${WORK_ROOT}/helixscreen-${HELIXSCREEN_PIN}"
HELIX_DIR='/home/mks/helixscreen'

C_RESET='\033[0m'
C_BOLD='\033[1m'
C_GREEN='\033[32m'
C_YELLOW='\033[33m'
C_RED='\033[31m'
C_CYAN='\033[36m'

banner() { printf '\n%b=================================================================%b\n%b  %s%b\n%b=================================================================%b\n' "$C_BOLD" "$C_RESET" "$C_BOLD" "$*" "$C_RESET" "$C_BOLD" "$C_RESET"; }
info() { printf '%b[INFO]%b %s\n' "$C_CYAN" "$C_RESET" "$*"; }
ok() { printf '%b[OK]%b   %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf '%b[WARN]%b %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
err() { printf '%b[ERR]%b  %s\n' "$C_RED" "$C_RESET" "$*" >&2; }

usage() {
    cat <<EOF
Happier Hare ${HAPPIER_HARE_VERSION}

Usage:
  install_happier_hare.sh [mode]

Modes:
  --install-zip URL|PATH  Install a prebuilt patched HelixScreen zip
  --patch-installed-binary
                          Patch installed HelixScreen command strings in place
  --patch-source          Clone/update HelixScreen ${HELIXSCREEN_PIN} and apply the patch
  --build-source          Patch source, build Pi DRM, and install rebuilt binary
  --verify                Verify the installed HelixScreen binary carries known patches

Environment:
  HAPPIER_HARE_ZIP_URL    Default patched zip URL/path for no-argument install
  HAPPIER_HARE_PATCH_URL  Override source patch URL
  HAPPIER_HARE_REPO_REF   Repo branch/tag used for default patch URL
  HAPPIER_HARE_WORK_ROOT  Override source/build directory
EOF
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        err "Missing required command: $1"
        return 1
    }
}

fetch() {
    local url="$1" dest="$2"
    curl --fail --silent --show-error --location "$url" --output "$dest"
}

run_remote_script() {
    local url="$1"
    shift
    local tmp
    tmp=$(mktemp /tmp/happier-hare-script.XXXXXX) || return 1
    fetch "$url" "$tmp" || { rm -f "$tmp"; return 1; }
    chmod +x "$tmp"
    "$tmp" "$@"
    local rc=$?
    rm -f "$tmp"
    return "$rc"
}

install_zip() {
    local url="$1"
    [ -n "$url" ] || { err "No patched zip URL provided"; return 1; }
    require_cmd curl

    banner "Installing patched HelixScreen archive"
    local tmp base
    base=$(mktemp /tmp/happier-hare-helixscreen.XXXXXX) || return 1
    tmp="${base}.zip"
    mv "$base" "$tmp"
    if [ -f "$url" ]; then
        cp "$url" "$tmp" || { rm -f "$tmp"; return 1; }
        info "Using local patched archive: $url"
    else
        fetch "$url" "$tmp" || { rm -f "$tmp"; return 1; }
        info "Using patched archive: $url"
    fi
    run_remote_script "$HELIXSCREEN_INSTALLER" --local "$tmp"
    rm -f "$tmp"
    verify_installed
}

prepare_source() {
    require_cmd git
    require_cmd curl
    require_cmd patch

    banner "Preparing HelixScreen source"
    mkdir -p "$WORK_ROOT"
    if [ -d "${SOURCE_DIR}/.git" ]; then
        info "Updating existing source tree: ${SOURCE_DIR}"
        git -C "$SOURCE_DIR" fetch --tags origin
        git -C "$SOURCE_DIR" checkout "$HELIXSCREEN_PIN"
        git -C "$SOURCE_DIR" submodule update --init --recursive
    else
        info "Cloning ${HELIXSCREEN_REPO} (${HELIXSCREEN_PIN})"
        git clone --branch "$HELIXSCREEN_PIN" --recurse-submodules "$HELIXSCREEN_REPO" "$SOURCE_DIR"
    fi
}

apply_patchset() {
    prepare_source

    banner "Applying Happier Hare patch set"
    local patch_file
    patch_file=$(mktemp /tmp/happier-hare-patch.XXXXXX) || return 1
    fetch "$PATCH_URL" "$patch_file" || { rm -f "$patch_file"; return 1; }

    if patch -d "$SOURCE_DIR" -p1 --forward --dry-run < "$patch_file" >/dev/null 2>&1; then
        patch -d "$SOURCE_DIR" -p1 --forward < "$patch_file"
        ok "Patch set applied"
    elif patch -d "$SOURCE_DIR" -p1 --reverse --dry-run < "$patch_file" >/dev/null 2>&1; then
        ok "Patch set already applied"
    else
        err "Patch set does not apply cleanly to ${SOURCE_DIR}"
        rm -f "$patch_file"
        return 1
    fi
    rm -f "$patch_file"
}

build_source() {
    apply_patchset
    require_cmd make

    banner "Building patched HelixScreen"
    if ! command -v aarch64-linux-gnu-g++ >/dev/null 2>&1; then
        err "aarch64-linux-gnu-g++ not found; cannot build Pi DRM locally"
        warn "Use the GitHub Happier Hare build workflow or provide HAPPIER_HARE_ZIP_URL"
        return 1
    fi

    make -C "$SOURCE_DIR" PLATFORM_TARGET=pi SKIP_OPTIONAL_DEPS=1 -j"$(nproc 2>/dev/null || printf '2')"

    banner "Installing patched binaries"
    sudo systemctl stop helixscreen 2>/dev/null || true
    sudo install -m 0755 "${SOURCE_DIR}/build/pi/bin/helix-screen" "${HELIX_DIR}/bin/helix-screen"
    sudo systemctl restart helixscreen 2>/dev/null || true
    verify_installed
}

verify_installed() {
    banner "Verifying Happier Hare install"

    local bin_dir="${HELIX_DIR}/bin"
    if [ ! -d "$bin_dir" ]; then
        err "HelixScreen binary directory not found: $bin_dir"
        return 1
    fi

    local seen=0 timer_bin="" stop_bin="" env_bin="" stock_env_bin="" target
    while IFS= read -r target; do
        [ -f "$target" ] || continue
        seen=1
        if LC_ALL=C grep -aFq 'MMU_HEATER DRY=1 TEMP={:.0f} TIMER={}' "$target"; then
            timer_bin="$target"
        fi
        if LC_ALL=C grep -aFq 'MMU_HEATER STOP=1' "$target"; then
            stop_bin="$target"
        fi
        if LC_ALL=C grep -aFq 'temperature_sensor box' "$target" && \
           LC_ALL=C grep -aFq 'heater_generic box' "$target"; then
            env_bin="$target"
        fi
        if LC_ALL=C grep -aFq 'aht20_f heater_box' "$target"; then
            stock_env_bin="$target"
        fi
    done < <(find "$bin_dir" -maxdepth 1 -type f -name 'helix-screen*' -print 2>/dev/null)

    if [ "$seen" -eq 0 ]; then
        err "No HelixScreen binaries found under ${bin_dir}"
        return 1
    fi

    if [ -n "$timer_bin" ] && [ -n "$stop_bin" ]; then
        ok "Happy Hare dryer command strings are patched"
        info "Dryer start string found in $(basename "$timer_bin")"
        info "Dryer stop string found in $(basename "$stop_bin")"
    else
        warn "Known dryer command strings were not found in helix-screen* binaries"
        warn "Installed files under ${bin_dir}:"
        while IFS= read -r target; do
            warn "  $(basename "$target")"
        done < <(find "$bin_dir" -maxdepth 1 -type f -name 'helix-screen*' -print 2>/dev/null)
        warn "Source/UI patch may not be installed"
        return 1
    fi

    if [ -n "$env_bin" ]; then
        ok "Qidi Box Happy Hare environment sensor paths are patched"
        info "Happy Hare sensor paths found in $(basename "$env_bin")"
    elif [ -n "$stock_env_bin" ]; then
        ok "Qidi Box stock AHT20 environment sensor path is patched"
        info "Stock AHT20 path found in $(basename "$stock_env_bin")"
    else
        warn "Qidi Box environment sensor paths were not found; native temperature/humidity may stay blank"
    fi
}

patch_installed_binary() {
    banner "Patching installed HelixScreen binary commands"
    require_cmd python3

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
                warn "$(basename "$target"): timer command patch failed"
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
                failed=1
                ;;
            4)
                warn "$(basename "$target"): DRY=0 found, but no safe padding for in-place STOP=1 patch"
                failed=1
                ;;
            *)
                warn "$(basename "$target"): stop command patch failed"
                failed=1
                ;;
        esac
    done

    if [ "$seen" -eq 0 ]; then
        err "No HelixScreen binary found under ${HELIX_DIR}/bin"
        return 1
    fi
    if [ "$failed" -ne 0 ] && [ "$patched" -eq 0 ] && [ "$already" -eq 0 ]; then
        err "Installed HelixScreen binary command patch could not be verified"
        return 1
    fi

    verify_installed
}

main() {
    local mode="${1:-}"
    case "$mode" in
        --help|-h)
            usage
            ;;
        --install-zip)
            install_zip "${2:-}"
            ;;
        --patch-installed-binary)
            patch_installed_binary
            ;;
        --patch-source)
            apply_patchset
            ;;
        --build-source)
            build_source
            ;;
        --verify)
            verify_installed
            ;;
        "")
            if [ -n "$PATCHED_ZIP_URL" ]; then
                install_zip "$PATCHED_ZIP_URL"
            else
                warn "No HAPPIER_HARE_ZIP_URL set; preparing patched source only"
                apply_patchset
                warn "Patched source is ready at ${SOURCE_DIR}"
                warn "Build/install requires --build-source or a prebuilt patched zip"
            fi
            ;;
        *)
            err "Unknown mode: $mode"
            usage
            return 1
            ;;
    esac
}

main "$@"
