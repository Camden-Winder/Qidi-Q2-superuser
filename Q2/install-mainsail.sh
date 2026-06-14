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

# warn: non-fatal notice (stderr only)
warn()   { echo "[WARN]  $*" >&2; }

# ok: success confirmation
ok()     { echo "[ OK ]  $*"; }

# err: fatal error — print message then exit 1
err()    { echo "[ERR ]  $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# ERR trap — fires on any command that exits non-zero.
# Prints the failing line number and the exact command for debugging.
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
# Existing install check — exit early if Mainsail is already running
# ---------------------------------------------------------------------------

# Check for mainsail files AND a matching nginx config serving them.
# If only the files exist (no nginx config) we fall through to a full install.
if [[ -f "${MAINSAIL_DIR}/index.html" ]]; then
    EXISTING_CONF=$(grep -rl "root.*mainsail" /etc/nginx/sites-enabled/ 2>/dev/null | head -1)
    if [[ -n "${EXISTING_CONF}" ]]; then
        EXISTING_PORT=$(grep -m1 "^\s*listen" "${EXISTING_CONF}" | awk '{print $2}' | tr -d ';')
        PRINTER_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
        echo "Mainsail is already installed — http://${PRINTER_IP}:${EXISTING_PORT}"
        exit 0
    fi
fi

echo "Installing Mainsail..."

# ---------------------------------------------------------------------------
# Step 1: Install dependencies (nginx + unzip)
# ---------------------------------------------------------------------------

# DEBIAN_FRONTEND=noninteractive prevents apt from raising interactive prompts on Debian 10.
# apt-get update is expected to partially fail on the Q2 (broken bullseye-backports mirror);
# we silence it entirely and only fail hard if the package install itself fails.
DEBIAN_FRONTEND=noninteractive sudo apt-get update -qq \
  -o Acquire::Check-Valid-Until=false \
  --allow-releaseinfo-change \
  > /dev/null 2>&1 || true

DEBIAN_FRONTEND=noninteractive sudo apt-get install -y nginx unzip curl \
  > /dev/null 2>&1 \
  || err "apt-get install failed — run 'sudo apt-get install -y nginx unzip curl' manually to see the full error"

# ---------------------------------------------------------------------------
# Step 2: Download the latest Mainsail release zip
# ---------------------------------------------------------------------------

MAINSAIL_URL="https://github.com/mainsail-crew/mainsail/releases/latest/download/mainsail.zip"

# -sSL: silent, show errors, follow redirects (GitHub releases use a 302 redirect)
curl -sSL -o "${MAINSAIL_ZIP}" "${MAINSAIL_URL}" \
  || err "Download failed — verify network connectivity and that GitHub is reachable"

# Confirm the download is a valid ZIP (not an HTML error page saved to disk)
unzip -t "${MAINSAIL_ZIP}" > /dev/null 2>&1 \
  || err "Downloaded file is not a valid ZIP archive — it may be an HTML error page. Check network/proxy."

# ---------------------------------------------------------------------------
# Step 3: Extract Mainsail files
# ---------------------------------------------------------------------------

mkdir -p "${MAINSAIL_DIR}"

# -q quiet, -o overwrite without prompting (idempotent re-runs)
unzip -qo "${MAINSAIL_ZIP}" -d "${MAINSAIL_DIR}/" \
  || err "unzip failed — zip may be corrupt; delete ${MAINSAIL_ZIP} and re-run"

rm -f "${MAINSAIL_ZIP}"

# ---------------------------------------------------------------------------
# Step 4: Write nginx configuration (port 100, proxy to Moonraker :7125)
# ---------------------------------------------------------------------------

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
    sudo rm -f /etc/nginx/sites-enabled/default
fi

# -sf: force re-create symlink (idempotent)
sudo ln -sf "${NGINX_CONF_SRC}" "${NGINX_CONF_DST}" \
  || err "Failed to create nginx site symlink — check permissions on /etc/nginx/sites-enabled/"

# ---------------------------------------------------------------------------
# Step 5: Update moonraker.conf CORS / trusted clients
# ---------------------------------------------------------------------------

if [[ ! -f "${MOONRAKER_CONF}" ]]; then
    warn "moonraker.conf not found at ${MOONRAKER_CONF} — skipping CORS update."
    warn "If Moonraker rejects connections from Mainsail, add cors_domains manually."
else
    # Append cors_domains block only if not already present (idempotent)
    if ! grep -qF "cors_domains" "${MOONRAKER_CONF}"; then
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
    fi
fi

# ---------------------------------------------------------------------------
# Step 6: Validate nginx config syntax
# ---------------------------------------------------------------------------

# Capture nginx -t output; only print it if validation fails
NGINX_OUT=$(sudo nginx -t 2>&1) \
  || { printf '%s\n' "${NGINX_OUT}" >&2; err "nginx config invalid — see above"; }

# ---------------------------------------------------------------------------
# Step 7: Enable and restart nginx
# ---------------------------------------------------------------------------

sudo systemctl enable nginx > /dev/null 2>&1 \
  || err "systemctl enable nginx failed — run 'sudo systemctl status nginx' for details"

sudo systemctl restart nginx > /dev/null 2>&1 \
  || err "nginx failed to restart — run 'sudo journalctl -xe -u nginx' for details"

# ---------------------------------------------------------------------------
# Step 8: Verify Mainsail is reachable and print access URL
# ---------------------------------------------------------------------------

# Give nginx a moment to fully bind the port after restart
sleep 2

PRINTER_IP=$(hostname -I 2>/dev/null | awk '{print $1}')

if curl -sf --max-time 5 "http://localhost:${MAINSAIL_PORT}/" -o /dev/null; then
    ok "Mainsail installed — http://${PRINTER_IP}:${MAINSAIL_PORT}"
else
    warn "Mainsail did not respond on port ${MAINSAIL_PORT} — nginx may need a moment."
    warn "Check logs: sudo journalctl -u nginx -n 50"
    warn "Access URL: http://${PRINTER_IP}:${MAINSAIL_PORT}"
fi
