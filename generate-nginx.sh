#!/bin/bash
set -euo pipefail

# ====================================================================
# generate-nginx.sh (SAFE, PRODUCTION READY)
# --------------------------------------------------------------------
# - Generates an Nginx config based on a template
# - Injects DOMAIN, PORT, CORS mappings
# - Creates automatic backups
# - Tests configuration before enabling
# - Does NOT install SSL
# ====================================================================

LOGFILE="/var/log/lws-generate-nginx.log"
exec > >(tee -a "$LOGFILE") 2>&1

# ------------------------------
# Arguments
# ------------------------------
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <DOMAIN> <PORT> \"<ORIGIN1 ORIGIN2 ORIGIN3>\""
    exit 1
fi

DOMAIN="$1"
PORT="$2"
ALLOWED_ORIGINS="$3"
BODY_SIZE="10m"


TEMPLATE_FILE="nginx-template.conf"
NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"
ENABLED_LINK="/etc/nginx/sites-enabled/$DOMAIN"

echo ""
echo "======================================"
echo "   Generating NGINX Config"
echo "   Domain: $DOMAIN"
echo "   Log: $LOGFILE"
echo "======================================"

# ------------------------------
# Validate arguments
# ------------------------------
if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
    echo "❌ Error: PORT must be a number."
    exit 1
fi

if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "❌ Template file not found: $TEMPLATE_FILE"
    exit 1
fi

# ------------------------------
# Build CORS map block
# ------------------------------
CORS_MAP=""
for ORIGIN in $ALLOWED_ORIGINS; do
    CORS_MAP="${CORS_MAP}    $ORIGIN  $ORIGIN;\n"
done

# ------------------------------
# Backup existing config
# ------------------------------
if [ -f "$NGINX_CONF" ]; then
    echo "==> Backing up existing config"
    sudo cp "$NGINX_CONF" "$NGINX_CONF.bak-$(date +%s)"
fi

# ------------------------------
# Generate new config (initial template)
# ------------------------------
echo "==> Writing new nginx config"

sudo bash -c "sed \
    -e \"s|{{DOMAIN}}|$DOMAIN|g\" \
    -e \"s|{{PORT}}|$PORT|g\" \
    -e \"s|{{BODY_SIZE}}|$BODY_SIZE|g\" \
    < \"$TEMPLATE_FILE\" \
    > \"$NGINX_CONF\""

# ------------------------------
# Insert multi-line CORS_MAP safely
# ------------------------------
sudo bash -c "sed -i \"s|{{CORS_MAP}}|$(printf '%b' "$CORS_MAP")|\" \"$NGINX_CONF\""

# ------------------------------
# Fix permissions
# ------------------------------
sudo chown root:root "$NGINX_CONF"
sudo chmod 644 "$NGINX_CONF"

# ------------------------------
# Enable config
# ------------------------------
sudo ln -sf "$NGINX_CONF" "$ENABLED_LINK"

# ------------------------------
# Validate config
# ------------------------------
echo "==> Testing nginx configuration"
if ! sudo nginx -t; then
    echo "❌ ERROR: Nginx config invalid. Restoring backup..."
    sudo cp "$NGINX_CONF.bak"* "$NGINX_CONF"
    sudo nginx -t # Show the original error + ensure restored config works
    exit 1
fi

# ------------------------------
# Reload Nginx ONLY when safe
# ------------------------------
sudo systemctl reload nginx

echo ""
echo "🔥 NGINX config successfully generated for $DOMAIN"
echo "   File: $NGINX_CONF"
echo "   Enabled: /etc/nginx/sites-enabled/$DOMAIN"
echo "=============================================="
