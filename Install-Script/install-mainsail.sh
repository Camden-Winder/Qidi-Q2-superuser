#!/bin/bash

# Standalone Mainsail installer for the Qidi Q2 (ARM Linux, user mks).
# Installs Mainsail on port 100 to avoid conflict with the stock Qidi
# lighttpd instance on port 80, and proxies Moonraker at 127.0.0.1:7125.
#
# Designed to be run standalone by previous users of the Whole 9 Yards
# preset, and re-used (sourced or called) by the AIO installer later.
#
# Verbose ERR trap retained intentionally — this branch is for testing.

set -e
set -o pipefail

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------

# banner: large section header
banner() { echo; echo "=========================================================="; echo "  $*"; echo "=========================================================="; echo; }

# info: general progress message
info()   { echo "[INFO]  $*"; }

# warn: non-fatal notice
warn()   { echo "[WARN]  $*" >&2; }

# ok: success confirmation
ok()     { echo "[ OK ]  $*"; }

# err: fatal error — print message then exit 1
err()    { echo "[ERR ]  $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# ERR trap — fires on any command that exits non-zero.
# Prints the failing line number and the exact command for easier debugging.
# ---------------------------------------------------------------------------
trap 'echo; echo "[ERR ] Script aborted at line ${LINENO} — failed command: ${BASH_COMMAND}" >&2' ERR

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

MAINSAIL_DIR="/home/mks/mainsail"
MAINSAIL_ZIP="/tmp/mainsail.zip"
MOONRAKER_CONF="/home/mks/printer_data/config/moonraker.conf"
NGINX_CONF_SRC="/etc/nginx/sites-available/mainsail"
NGINX_CONF_DST="/etc/nginx/sites-enabled/mainsail"
MAINSAIL_PORT=100
MOONRAKER_PORT=7125

# ---------------------------------------------------------------------------
# Step 1: Install dependencies (nginx + unzip)
# ---------------------------------------------------------------------------

banner "Step 1 — Installing dependencies"

info "Running apt-get update..."
# Allow-releaseinfo-change tolerates repos where the Release file has changed (e.g. stale
# Qidi bullseye-backports mirror). We capture but do not hard-fail on update errors;
# the install step below will fail explicitly if a required package is missing.
sudo apt-get update -qq \
  -o Acquire::Check-Valid-Until=false \
  --allow-releaseinfo-change \
  2>&1 || warn "apt-get update had errors (possibly stale mirror) — attempting install anyway"

info "Installing nginx and unzip..."
# -y answers yes automatically (no prompts), satisfying the hands-off requirement
sudo apt-get install -y nginx unzip curl \
  || err "apt-get install failed — run 'sudo apt-get install -y nginx unzip curl' manually to see the full error"

ok "Dependencies installed."

# ---------------------------------------------------------------------------
# Step 2: Download the latest Mainsail release zip
# ---------------------------------------------------------------------------

banner "Step 2 — Downloading Mainsail"

MAINSAIL_URL="https://github.com/mainsail-crew/mainsail/releases/latest/download/mainsail.zip"

info "Downloading from: ${MAINSAIL_URL}"

# -sSL: silent, show errors, follow redirects (GitHub releases use a 302 redirect)
# -o: save body to file; failure exits non-zero and the err handler fires
curl -sSL -o "${MAINSAIL_ZIP}" "${MAINSAIL_URL}" \
  || err "Download failed — verify network connectivity and that GitHub is reachable"

# Confirm the zip is a valid ZIP file (not an error HTML page saved to disk)
file "${MAINSAIL_ZIP}" | grep -q "Zip archive" \
  || err "Downloaded file is not a valid ZIP — got: $(file "${MAINSAIL_ZIP}"). URL may have changed."

ok "Mainsail downloaded to ${MAINSAIL_ZIP}."

# ---------------------------------------------------------------------------
# Step 3: Extract Mainsail files
# ---------------------------------------------------------------------------

banner "Step 3 — Extracting Mainsail"

info "Creating install directory: ${MAINSAIL_DIR}"
mkdir -p "${MAINSAIL_DIR}"

info "Extracting zip..."
# -q quiet, -o overwrite without prompting (idempotent re-runs)
unzip -qo "${MAINSAIL_ZIP}" -d "${MAINSAIL_DIR}/" \
  || err "unzip failed — zip may be corrupt; delete ${MAINSAIL_ZIP} and re-run"

rm -f "${MAINSAIL_ZIP}"
ok "Mainsail extracted to ${MAINSAIL_DIR}."

# ---------------------------------------------------------------------------
# Step 4: Write nginx configuration
# ---------------------------------------------------------------------------

banner "Step 4 — Configuring nginx"

info "Writing nginx site config to ${NGINX_CONF_SRC}..."

# sudo tee pattern for writing a file that requires elevated permissions.
# The heredoc is written to tee's stdin; tee writes to the privileged path.
sudo tee "${NGINX_CONF_SRC}" > /dev/null << 'NGINX_CONF'
# Mainsail nginx config — generated by install-mainsail.sh
# Port 100 is used to avoid conflict with the stock Qidi lighttpd on port 80.

# Map HTTP upgrade headers for WebSocket support
map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      close;
}

server {
    listen 100;

    # Logging paths — helpful for debugging connection issues
    access_log /var/log/nginx/mainsail-access.log;
    error_log  /var/log/nginx/mainsail-error.log;

    # Serve Mainsail static files
    root  /home/mks/mainsail;
    index index.html;

    # Match all host headers (single-machine setup)
    server_name _;

    # gzip compression for faster UI loads on slower connections
    gzip            on;
    gzip_vary       on;
    gzip_proxied    any;
    gzip_comp_level 4;
    gzip_buffers    16 8k;
    gzip_http_version 1.0;
    gzip_types text/plain text/css text/xml text/javascript
               application/x-javascript application/json application/xml;

    # Serve the SPA — fall back to index.html for client-side routing
    location / {
        try_files $uri $uri/ /index.html;
    }

    # WebSocket endpoint — required for live Klipper/Moonraker data
    location /websocket {
        proxy_pass         http://127.0.0.1:7125;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade    $http_upgrade;
        proxy_set_header   Connection $connection_upgrade;
        proxy_set_header   Host       $http_host;
        proxy_set_header   X-Real-IP  $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        # Long timeout keeps the WebSocket alive during idle periods
        proxy_read_timeout 86400;
    }

    # Moonraker REST API endpoints proxied through to port 7125
    location ~ ^/(printer|api|access|machine|server)/ {
        proxy_pass         http://127.0.0.1:7125;
        proxy_http_version 1.1;
        proxy_set_header   Host            $http_host;
        proxy_set_header   X-Real-IP       $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    # Cache static assets aggressively — Mainsail versioned bundles change on update
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        expires     max;
        log_not_found off;
    }
}
NGINX_CONF

# Disable the default nginx site to avoid conflicts on port 80 (if still enabled)
if [[ -f /etc/nginx/sites-enabled/default ]]; then
    info "Removing default nginx site to avoid port conflicts..."
    sudo rm -f /etc/nginx/sites-enabled/default
fi

info "Enabling Mainsail nginx site..."
# -sf: force re-create symlink (idempotent)
sudo ln -sf "${NGINX_CONF_SRC}" "${NGINX_CONF_DST}" \
  || err "Failed to create nginx site symlink — check permissions on /etc/nginx/sites-enabled/"

ok "nginx config written and site enabled."

# ---------------------------------------------------------------------------
# Step 5: Update moonraker.conf CORS / trusted clients
# ---------------------------------------------------------------------------

banner "Step 5 — Updating Moonraker CORS config"

if [[ ! -f "${MOONRAKER_CONF}" ]]; then
    warn "moonraker.conf not found at ${MOONRAKER_CONF} — skipping CORS update."
    warn "If Moonraker rejects connections from Mainsail, add cors_domains manually."
else
    # Append cors_domains block only if it is not already present.
    # grep -qF exits 0 if found, 1 if not — we add only when missing.
    if grep -qF "cors_domains" "${MOONRAKER_CONF}"; then
        info "cors_domains already present in moonraker.conf — skipping."
    else
        info "Appending cors_domains to ${MOONRAKER_CONF}..."
        # tee -a appends; redirect stdout to /dev/null to keep output clean
        tee -a "${MOONRAKER_CONF}" > /dev/null << 'CORS_BLOCK'

# Added by install-mainsail.sh — allows Mainsail on port 100 to connect
[authorization]
cors_domains:
    *://localhost
    *://localhost:*
    *://*.local
    *://*.local:*
    *://*.lan
trusted_clients:
    127.0.0.1
    ::1
CORS_BLOCK
        ok "cors_domains appended to moonraker.conf."
    fi
fi

# ---------------------------------------------------------------------------
# Step 6: Validate nginx config syntax
# ---------------------------------------------------------------------------

banner "Step 6 — Validating nginx config"

info "Running nginx -t..."
# 2>&1 ensures nginx's stderr (where it writes test output) is visible to user
sudo nginx -t 2>&1 \
  || err "nginx config validation failed — review the output above for syntax errors in ${NGINX_CONF_SRC}"

ok "nginx config syntax is valid."

# ---------------------------------------------------------------------------
# Step 7: Enable and restart nginx
# ---------------------------------------------------------------------------

banner "Step 7 — Starting nginx"

info "Enabling nginx to start on boot..."
sudo systemctl enable nginx \
  || err "systemctl enable nginx failed — systemd may not be available or nginx unit is missing"

info "Restarting nginx..."
sudo systemctl restart nginx \
  || err "nginx failed to restart — run 'sudo journalctl -xe -u nginx' for details"

ok "nginx started and enabled."

# ---------------------------------------------------------------------------
# Step 8: Verify Mainsail is reachable
# ---------------------------------------------------------------------------

banner "Step 8 — Verifying installation"

info "Checking Mainsail responds on port ${MAINSAIL_PORT}..."
# Give nginx a moment to fully bind the port after restart
sleep 2

# -sf: silent + show errors; -o /dev/null: discard body; --max-time 5: don't hang
if curl -sf --max-time 5 "http://localhost:${MAINSAIL_PORT}/" -o /dev/null; then
    PRINTER_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    ok "Mainsail is running."
    echo
    echo "  Access Mainsail at:  http://${PRINTER_IP}:${MAINSAIL_PORT}"
    echo
else
    warn "Mainsail did not respond on port ${MAINSAIL_PORT}."
    warn "Check nginx logs: sudo journalctl -u nginx -n 50"
    warn "Check error log:  sudo tail -n 30 /var/log/nginx/mainsail-error.log"
    warn "Check port in use: sudo ss -tlnp | grep :${MAINSAIL_PORT}"
fi

banner "Mainsail install complete"
