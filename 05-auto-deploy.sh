#!/bin/bash
set -euo pipefail

# =====================================================================
# 05-auto-deploy.sh — Lightweight Git Auto Deploy (backend only)
# =====================================================================

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <GitHubRepoURL>"
  exit 1
fi

REPO_URL="$1"

# Convert HTTPS GitHub URL to SSH if needed (for private repos)
ORIG_REPO_URL="$REPO_URL"
if [[ "$REPO_URL" =~ ^https://github.com/(.*)\.git$ ]]; then
    REPO_URL="git@github.com:${BASH_REMATCH[1]}.git"
    echo "Converted repo URL:"
    echo "  Original: $ORIG_REPO_URL"
    echo "  SSH:      $REPO_URL"
fi

PROJECT_DIR=$(basename "$REPO_URL" .git)
APP_NAME="express-app"

echo ""
echo "=============================================="
echo "   Auto Deploy Script"
echo "   Repo:    $REPO_URL"
echo "   Project: $PROJECT_DIR"
echo "=============================================="

cd /root/LWS-Scripts

# Clone repo if missing
if [ ! -d "$PROJECT_DIR" ]; then
  echo "==> Cloning repository (first-time)"
  git clone "$REPO_URL"
fi

cd "$PROJECT_DIR"

echo "==> Fetching latest changes"
git fetch --all
git reset --hard origin/main || git reset --hard origin/master

# ---------------------------------------------------------
# Detect backend folder
# ---------------------------------------------------------
if [ -d "server" ]; then
  SERVER_DIR="server"
elif [ -d "backend" ]; then
  SERVER_DIR="backend"
else
  echo "❌ No server/backend directory found"
  exit 1
fi

# ---------------------------------------------------------
# Backend: install deps
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
    echo "❌ No entry file found (server.js / index.js / app.js)"
    exit 1
fi

# ---------------------------------------------------------
# Reload backend with PM2
# ---------------------------------------------------------
echo "==> Reloading PM2 app: $APP_NAME"

pm2 reload "$APP_NAME" --update-env || pm2 start "$ENTRY" --name "$APP_NAME"
pm2 save

echo ""
echo "=============================================="
echo " ✅ Auto deploy complete (backend only)"
echo "   (React build must be uploaded separately)"
echo "=============================================="
