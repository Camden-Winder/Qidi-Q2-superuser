#!/usr/bin/env bash
# =====================================================================
# Build a patched Happier Hare HelixScreen Pi archive locally with Docker.
#
# Output:
#   Happier_Hare/dist/helixscreen-pi.zip
#   Happier_Hare/dist/helixscreen-pi-happier-hare-RC2.11.zip
# =====================================================================

set -euo pipefail

HAPPIER_HARE_VERSION='RC2.11'
HELIXSCREEN_PIN="${HELIXSCREEN_PIN:-v0.99.70}"
HELIXSCREEN_REPO="${HELIXSCREEN_REPO:-https://github.com/prestonbrown/helixscreen.git}"
HELIXSCREEN_BUILD_JOBS="${HELIXSCREEN_BUILD_JOBS:-1}"
HELIXSCREEN_TOOLCHAIN_IMAGE="${HELIXSCREEN_TOOLCHAIN_IMAGE:-helixscreen/toolchain-pi-happier-hare}"
WORK_ROOT="${HAPPIER_HARE_BUILD_ROOT:-/private/tmp/happier-hare-helixscreen-build}"
SOURCE_DIR="${WORK_ROOT}/helixscreen-${HELIXSCREEN_PIN}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_FILE="${SCRIPT_DIR}/patches/helixscreen-v0.99.70-happier-hare.patch"
OUT_DIR="${SCRIPT_DIR}/dist"
OUT_ZIP="${OUT_DIR}/helixscreen-pi-happier-hare-${HAPPIER_HARE_VERSION}.zip"
PLAIN_ZIP="${OUT_DIR}/helixscreen-pi.zip"

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

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        err "Missing required command: $1"
        return 1
    }
}

docker_build() {
    if docker buildx version >/dev/null 2>&1; then
        docker buildx build --load "$@"
    else
        docker build "$@"
    fi
}

build_toolchain_image() {
    local dockerfile="${WORK_ROOT}/Dockerfile.toolchain-pi-happier-hare"

    banner "Building HelixScreen Pi toolchain image"
    docker_build \
        -t helixscreen/toolchain-pi \
        -f "${SOURCE_DIR}/docker/Dockerfile.pi" \
        "${SOURCE_DIR}/docker"

    info "Adding release packaging tools to ${HELIXSCREEN_TOOLCHAIN_IMAGE}"
    cat > "$dockerfile" <<'EOF'
FROM helixscreen/toolchain-pi
RUN apt-get update \
    && apt-get install -y --no-install-recommends zip \
    && rm -rf /var/lib/apt/lists/*
EOF
    docker_build \
        -t "$HELIXSCREEN_TOOLCHAIN_IMAGE" \
        -f "$dockerfile" \
        "$WORK_ROOT"
}

prepare_source() {
    require_cmd git
    require_cmd patch

    banner "Preparing HelixScreen source"
    mkdir -p "$WORK_ROOT"
    if [ -d "${SOURCE_DIR}/.git" ]; then
        info "Updating existing source tree: ${SOURCE_DIR}"
        git -C "$SOURCE_DIR" fetch --tags origin
        git -C "$SOURCE_DIR" checkout "$HELIXSCREEN_PIN"
        git -C "$SOURCE_DIR" reset --hard "$HELIXSCREEN_PIN"
        git -C "$SOURCE_DIR" submodule update --init --recursive
    else
        info "Cloning ${HELIXSCREEN_REPO} (${HELIXSCREEN_PIN})"
        git clone --branch "$HELIXSCREEN_PIN" --depth 1 "$HELIXSCREEN_REPO" "$SOURCE_DIR"
        git -C "$SOURCE_DIR" submodule update --init --recursive
    fi
}

apply_patchset() {
    banner "Applying Happier Hare patch set"
    if patch -d "$SOURCE_DIR" -p1 --forward --dry-run < "$PATCH_FILE" >/dev/null 2>&1; then
        patch -d "$SOURCE_DIR" -p1 --forward < "$PATCH_FILE"
        ok "Patch set applied"
    elif patch -d "$SOURCE_DIR" -p1 --reverse --dry-run < "$PATCH_FILE" >/dev/null 2>&1; then
        ok "Patch set already applied"
    else
        err "Patch set does not apply cleanly to ${SOURCE_DIR}"
        return 1
    fi
}

build_zip() {
    require_cmd docker
    if ! [[ "$HELIXSCREEN_BUILD_JOBS" =~ ^[1-9][0-9]*$ ]]; then
        err "HELIXSCREEN_BUILD_JOBS must be a positive integer"
        return 1
    fi

    build_toolchain_image

    banner "Building patched Pi binaries"
    info "Using ${HELIXSCREEN_BUILD_JOBS} compile job(s)"
    docker run --rm \
        -v "${SOURCE_DIR}:/src" \
        -w /src \
        "$HELIXSCREEN_TOOLCHAIN_IMAGE" \
        make _PARALLEL_CHECKED=1 PLATFORM_TARGET=pi-both SKIP_OPTIONAL_DEPS=1 -j"${HELIXSCREEN_BUILD_JOBS}"

    banner "Packaging patched Pi archive"
    docker run --rm \
        -v "${SOURCE_DIR}:/src" \
        -w /src \
        "$HELIXSCREEN_TOOLCHAIN_IMAGE" \
        make _PARALLEL_CHECKED=1 release-pi

    mkdir -p "$OUT_DIR"
    cp "${SOURCE_DIR}/releases/helixscreen-pi.zip" "$OUT_ZIP"
    cp "$OUT_ZIP" "$PLAIN_ZIP"
    ok "Wrote ${OUT_ZIP}"
    ok "Wrote ${PLAIN_ZIP}"
}

verify_zip() {
    banner "Verifying patched archive"
    require_cmd unzip
    require_cmd strings

    local checks=0
    local strings_file="${WORK_ROOT}/helix-screen.strings"
    unzip -p "$PLAIN_ZIP" bin/helix-screen | LC_ALL=C strings > "$strings_file"

    if grep -Fq 'MMU_HEATER DRY=1 TEMP={:.0f} TIMER={}' "$strings_file"; then
        ok "helix-screen uses TIMER= for Happy Hare dryer start"
        checks=$((checks + 1))
    else
        warn "Could not verify TIMER= in helix-screen"
    fi

    if grep -Fq 'MMU_HEATER STOP=1' "$strings_file"; then
        ok "helix-screen uses STOP=1 for Happy Hare dryer stop"
        checks=$((checks + 1))
    else
        warn "Could not verify STOP=1 in helix-screen"
    fi

    if grep -Fq 'temperature_sensor box' "$strings_file" && \
       grep -Fq 'heater_generic box' "$strings_file"; then
        ok "helix-screen contains Happy Hare Qidi Box sensor paths"
        checks=$((checks + 1))
    elif grep -Fq 'aht20_f heater_box' "$strings_file"; then
        ok "helix-screen contains stock Qidi Box AHT20 humidity path"
        checks=$((checks + 1))
    else
        warn "Could not verify Qidi Box environment sensor paths in helix-screen"
    fi

    if [ "$checks" -lt 2 ]; then
        err "Patched archive verification failed"
        return 1
    fi
}

main() {
    prepare_source
    apply_patchset
    build_zip
    verify_zip

    banner "Next printer test"
    cat <<EOF
Copy the archive to the Q2:
  scp "${PLAIN_ZIP}" mks@<printer-ip>:/home/mks/helixscreen-pi-happier-hare.zip

Then run the AIO branch with the local patched zip:
  curl -fsSL https://raw.githubusercontent.com/Camden-Winder/Qidi-Q2-superuser/main/All_in_One_Installer/aio_menu.sh | \\
  HAPPIER_HARE_ZIP_URL=/home/mks/helixscreen-pi-happier-hare.zip \\
  AIO_REPO_REF=main \\
  bash
EOF
}

main "$@"
