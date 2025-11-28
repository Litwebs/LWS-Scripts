#!/bin/bash
set -euo pipefail

# =====================================================================
# 04-install_nginx_and_ssl.sh (PRODUCTION, AUTOMATED)
# =====================================================================

LOGFILE="/var/log/lws-nginx-install.log"
exec > >(tee -a "$LOGFILE") 2>&1

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <domain>"
    exit 1
fi

DOMAIN="$1"
CONFIG_PATH="/etc/nginx/sites-available/$DOMAIN"
ENABLED_PATH="/etc/nginx/sites-enabled/$DOMAIN"

echo ""
echo "==========================================="
echo " 🚀 NGINX + SSL Installation Script"
echo " Domain: $DOMAIN"
echo " Log: $LOGFILE"
echo "==========================================="

# ---------------------------------------------------------
# Step 1: Install Nginx
# ---------------------------------------------------------
echo "==> Installing Nginx"
sudo apt update -y
sudo apt install -y nginx

# ---------------------------------------------------------
# Step 2: Ensure Firewall Rules (safe)
# ---------------------------------------------------------
echo "==> Allowing Nginx through firewall (safe mode)"

if sudo ufw status | grep -q "inactive"; then
    echo "UFW is inactive — keeping it disabled for safety."
else
    sudo ufw allow 'Nginx Full'
fi

# ---------------------------------------------------------
# Step 3: Preliminary server block
# (required BEFORE certbot)
# ---------------------------------------------------------
echo "==> Creating temporary Nginx server block for $DOMAIN"

sudo bash -c "cat > $CONFIG_PATH" <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    root /var/www/html;
}
EOF

sudo ln -sf "$CONFIG_PATH" "$ENABLED_PATH"

# ---------------------------------------------------------
# Step 4: Test Nginx config
# ---------------------------------------------------------
echo "==> Testing Nginx configuration"
sudo nginx -t

# Reload before certbot
sudo systemctl reload nginx

# ---------------------------------------------------------
# Step 5: Install Certbot
# ---------------------------------------------------------
echo "==> Installing Certbot"
sudo apt install -y certbot python3-certbot-nginx

# ---------------------------------------------------------
# Step 6: Generate SSL Certificate
# ---------------------------------------------------------
echo "==> Requesting SSL certificate for $DOMAIN"

sudo certbot --nginx \
  --non-interactive \
  --agree-tos \
  -m admin@$DOMAIN \
  -d "$DOMAIN"

echo "==> SSL applied successfully"

# ---------------------------------------------------------
# Step 7: Final reload
# ---------------------------------------------------------
sudo nginx -t
sudo systemctl reload nginx

echo ""
echo "==========================================="
echo " ✅ NGINX + SSL installation complete!"
echo " 🔐 HTTPS enabled for: https://$DOMAIN"
echo "==========================================="
