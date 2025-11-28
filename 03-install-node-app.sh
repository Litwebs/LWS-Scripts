#!/bin/bash
set -euo pipefail

# =====================================================================
# 03-install-node-app.sh (IMPROVED VERSION)
# Deploys or updates a Node.js app with PM2 + Git + production build.
# =====================================================================

### Logging
LOGFILE="/var/log/lws-node-deploy.log"
exec > >(tee -a "$LOGFILE") 2>&1

### Validate Arguments
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <GitHubRepoURL>"
    exit 1
fi

REPO_URL="$1"
APP_DIR="app"
APP_NAME="express-app"
SYSTEM_USER=$(logname || echo "$USER")

echo ""
echo "=============================================="
echo "   Node.js Deployment Script"
echo "   Log: $LOGFILE"
echo "=============================================="

# ---------------------------------------------------------
# 1. Validate repo
# ---------------------------------------------------------
echo "==> Checking GitHub repository"
if ! git ls-remote "$REPO_URL" &>/dev/null; then
    echo "❌ Invalid GitHub repository URL"
    exit 1
fi

# ---------------------------------------------------------
# 2. Ensure Node.js exists
# ---------------------------------------------------------
if ! command -v node >/dev/null 2>&1; then
    echo "❌ Node.js not installed. Run 01-setup-node.sh first."
    exit 1
fi

# ---------------------------------------------------------
# 3. Clone or update repository
# ---------------------------------------------------------
if [ ! -d "$APP_DIR" ]; then
    echo "==> Cloning project for the first time"
    git clone "$REPO_URL" "$APP_DIR"
    cd "$APP_DIR"
else
    echo "==> Project exists — pulling latest code"
    cd "$APP_DIR"
    git fetch --all
    git reset --hard origin/main || git reset --hard origin/master
fi

# ---------------------------------------------------------
# 4. Install dependencies (production)
# ---------------------------------------------------------
echo "==> Installing dependencies"
npm install --omit=dev --legacy-peer-deps

# ---------------------------------------------------------
# 5. Detect app entry file
# ---------------------------------------------------------
echo "==> Detecting app entry point"

START_FILE=""
for file in index.js server.js app.js dist/server.js build/server.js; do
    if [ -f "$file" ]; then
        START_FILE="$file"
        break
    fi
done

if [ -z "$START_FILE" ]; then
    echo "❌ Error: Could not find a valid startup file."
    echo "Looked for: index.js, server.js, app.js, dist/server.js"
    exit 1
fi

echo "Using entry file: $START_FILE"

# ---------------------------------------------------------
# 6. Ensure PM2 installed
# ---------------------------------------------------------
if ! command -v pm2 >/dev/null 2>&1; then
    echo "==> Installing PM2 globally"
    sudo npm install -g pm2
else
    echo "PM2 already installed: $(pm2 -v)"
fi

# ---------------------------------------------------------
# 7. Start or reload app with PM2
# ---------------------------------------------------------
if pm2 list | grep -q "$APP_NAME"; then
    echo "==> Reloading existing app (zero downtime)"
    pm2 reload "$APP_NAME" --update-env
else
    echo "==> Starting app via PM2"
    pm2 start "$START_FILE" --name "$APP_NAME"
fi

# ---------------------------------------------------------
# 8. Enable PM2 startup
# ---------------------------------------------------------
echo "==> Configuring PM2 autostart"
sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u "$SYSTEM_USER" --hp "/home/$SYSTEM_USER"
pm2 save

# ---------------------------------------------------------
# 9. Done
# ---------------------------------------------------------
echo ""
echo "=============================================="
echo " Deployment Complete!"
echo " App name: $APP_NAME"
echo " PM2 status: pm2 status"
echo "=============================================="
