#!/bin/bash
set -euo pipefail

# ======================================================================
#  run-full-setup.sh  (LitWebs Deployment Engine – Automated)
# ======================================================================

# Colors
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
RESET="\e[0m"

LOGFILE="/var/log/lws-deploy.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo -e "${GREEN}====================================================="
echo -e " 🔥  LITWEBS — FULL SERVER DEPLOYMENT ENGINE"
echo -e " Log: $LOGFILE"
echo -e "=====================================================${RESET}"

# ======================================================================
# 1. VALIDATE ARGUMENTS
# ======================================================================
if [ "$#" -ne 4 ]; then
    echo -e "${RED}Usage:${RESET} $0 <GitHubRepoURL> <Domain> <Port> \"<AllowedOrigins>\""
    exit 1
fi

REPO_URL="$1"
DOMAIN="$2"
PORT="$3"
ALLOWED_ORIGINS="$4"

# Check numeric port
if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}Error: PORT must be numeric.${RESET}"
    exit 1
fi

# ======================================================================
# 2. OS DETECTION
# ======================================================================
OS=$(lsb_release -is 2>/dev/null || echo "Unknown")
OS_VER=$(lsb_release -rs 2>/dev/null || echo "0")

echo -e "${YELLOW}Detected OS:${RESET} $OS $OS_VER"

if [[ "$OS" != "Ubuntu" ]]; then
    echo -e "${RED}❌ Only Ubuntu is supported.${RESET}"
    exit 1
fi

if [[ "$OS_VER" != "20.04" && "$OS_VER" != "22.04" && "$OS_VER" != "24.04" ]]; then
    echo -e "${RED}❌ Unsupported Ubuntu version.${RESET}"
    exit 1
fi

# ======================================================================
# 3. ROLLBACK HANDLER
# ======================================================================
rollback() {
    echo -e "${RED}❌ ERROR DETECTED — ROLLING BACK${RESET}"

    # Restore previous Nginx config if backup exists
    if [ -f "/etc/nginx/sites-available/$DOMAIN.bak" ]; then
        sudo mv "/etc/nginx/sites-available/$DOMAIN.bak" "/etc/nginx/sites-available/$DOMAIN"
        sudo nginx -t && sudo systemctl reload nginx
        echo "Restored Nginx config."
    fi

    # Stop PM2 app
    pm2 delete express-app >/dev/null 2>&1 || true

    echo -e "${RED}💥 Deployment aborted. Check logs: $LOGFILE${RESET}"
    exit 1
}

trap rollback ERR

# ======================================================================
# 4. STEP 1 — Node.js + Base Setup
# ======================================================================
echo -e "${GREEN}==> STEP 1: Installing Node.js & initial app setup${RESET}"

chmod +x 01-setup-node.sh
./01-setup-node.sh "$REPO_URL" "mongodb://placeholder:placeholder@localhost:27017/db?authSource=admin"

# ======================================================================
# 5. STEP 2 — MongoDB Installation
# ======================================================================
echo -e "${GREEN}==> STEP 2: Installing MongoDB${RESET}"

chmod +x 02-install-mongodb.sh
./02-install-mongodb.sh

echo -e "${GREEN}==> Loading Mongo Credentials${RESET}"
source /etc/lws-mongo.env

MONGO_URI="mongodb://${APP_USER}:${APP_PASS}@localhost:27017/${APP_DB}?authSource=admin"

echo -e "${YELLOW}Mongo URI:${RESET} $MONGO_URI"

# ======================================================================
# 6. STEP 3 — Re-run Node setup with REAL Mongo URI
# ======================================================================
echo -e "${GREEN}==> STEP 3: Configuring Node.js with real Mongo URI${RESET}"

./01-setup-node.sh "$REPO_URL" "$MONGO_URI"

# ======================================================================
# 7. STEP 4 — Deploy / Update Node App
# ======================================================================
echo -e "${GREEN}==> STEP 4: Deploying Node.js App${RESET}"

chmod +x 03-install-node-app.sh
./03-install-node-app.sh "$REPO_URL"

# ======================================================================
# 8. STEP 5 — Install Nginx + SSL
# ======================================================================
echo -e "${GREEN}==> STEP 5: Installing Nginx + SSL${RESET}"

chmod +x 04-install_nginx_and_ssl.sh
./04-install_nginx_and_ssl.sh "$DOMAIN"

# ======================================================================
# 9. STEP 6 — Generate Nginx Config
# ======================================================================
echo -e "${GREEN}==> STEP 6: Generating Nginx Config${RESET}"

chmod +x generate-nginx.sh
./generate-nginx.sh "$DOMAIN" "$PORT" "$ALLOWED_ORIGINS"

# ======================================================================
# 10. SUCCESS OUTPUT
# ======================================================================
echo ""
echo -e "${GREEN}====================================================="
echo -e " 🎉 DEPLOYMENT COMPLETE!"
echo -e "=====================================================${RESET}"
echo " Domain:       https://$DOMAIN"
echo " App Port:     $PORT"
echo " Mongo URI:    $MONGO_URI"
echo " Nginx Config: /etc/nginx/sites-available/$DOMAIN"
echo " PM2 Status:   pm2 status"
echo -e "=====================================================${RESET}"
