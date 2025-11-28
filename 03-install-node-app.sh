#!/bin/bash
set -euo pipefail

# =====================================================================
# 03-install-node-app.sh (FINAL VERSION — MATCHES YOUR PROJECT STRUCTURE)
# Deploys or updates a Node.js app with PM2 + Git + backend/frontend install.
# =====================================================================

LOGFILE="/var/log/lws-node-deploy.log"
exec > >(tee -a "$LOGFILE") 2>&1

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <GitHubRepoURL>"
    exit 1
fi

REPO_URL="$1"

# Determine real project folder name
PROJECT_DIR=$(basename "$REPO_URL" .git)
APP_NAME="express-app"

echo ""
echo "=============================================="
echo "   Node.js Deployment Script"
echo "   Log: $LOGFILE"
echo "   Project: $PROJECT_DIR"
echo "=============================================="

# ---------------------------------------------------------
# 1. Validate repo
# ---------------------------------------------------------
if ! git ls-remote "$REPO_URL" &>/dev/null; then
    echo "❌ Invalid GitHub repository URL"
    exit 1
fi

# ---------------------------------------------------------
# 2. Clone or update repo
# ---------------------------------------------------------
if [ ! -d "$PROJECT_DIR" ]; then
    echo "==> Cloning repository into: $PROJECT_DIR"
    git clone "$REPO_URL"
else
    echo "==> Repo exists — pulling latest changes"
    cd "$PROJECT_DIR"
    git fetch --all
    git reset --hard origin/main || git reset --hard origin/master
    cd ..
fi

cd "$PROJECT_DIR"

# ---------------------------------------------------------
# 3. Detect server directory
# ---------------------------------------------------------
if [ -d "server" ]; then
    SERVER_DIR="server"
elif [ -d "backend" ]; then
    SERVER_DIR="backend"
else
    echo "❌ No server or backend folder found."
    exit 1
fi

# ---------------------------------------------------------
# 4. Detect client directory
# ---------------------------------------------------------
if [ -d "client" ]; then
    CLIENT_DIR="client"
elif [ -d "frontend" ]; then
    CLIENT_DIR="frontend"
else
    echo "❌ No client or frontend folder found."
    exit 1
fi

# ---------------------------------------------------------
# 5. Install backend dependencies
# ---------------------------------------------------------
echo "==> Installing backend dependencies"
cd "$SERVER_DIR"
npm install --legacy-peer-deps

# Detect entry file
if [ -f "server.js" ]; then
    ENTRY="server.js"
elif [ -f "index.js" ]; then
    ENTRY="index.js"
elif [ -f "app.js" ]; then
    ENTRY="app.js"
else
    echo "❌ No valid backend entry file found"
    exit 1
fi

cd ..

# ---------------------------------------------------------
# 6. Install frontend dependencies
# ---------------------------------------------------------
echo "==> Installing frontend dependencies"
cd "$CLIENT_DIR"
npm install --legacy-peer-deps
cd ..

# ---------------------------------------------------------
# 7. PM2 setup
# ---------------------------------------------------------
echo "==> Ensuring PM2 installed"
if ! command -v pm2 >/dev/null 2>&1; then
    sudo npm install -g pm2
fi

echo "==> Starting/Reloading backend via PM2"
cd "$SERVER_DIR"

pm2 delete "$APP_NAME" >/dev/null 2>&1 || true
pm2 start "$ENTRY" --name "$APP_NAME"
pm2 save

echo ""
echo "=============================================="
echo " 🚀 Deployment Complete!"
echo " Backend started with PM2: $APP_NAME"
echo " PM2 status: pm2 status"
echo "=============================================="
