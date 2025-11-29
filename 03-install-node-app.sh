#!/bin/bash
set -euo pipefail

# =====================================================================
# 03-install-node-app.sh — LitWebs Node App Deployment (PM2 + .env)
# =====================================================================

LOGFILE="/var/log/lws-node-deploy.log"
exec > >(tee -a "$LOGFILE") 2>&1

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <GitHubRepoURL> <Domain> <Port>"
    exit 1
fi

REPO_URL="$1"
DOMAIN="$2"
PORT="$3"

ENV_SOURCE="/etc/lws-env/$DOMAIN.env"
MONGO_ENV="/etc/lws-mongo.env"
APP_NAME="express-app"
PROJECT_DIR=$(basename "$REPO_URL" .git)

echo ""
echo "=============================================="
echo "   Node.js Deployment Script"
echo "   Project: $PROJECT_DIR"
echo "   Domain:  $DOMAIN"
echo "   Port:    $PORT"
echo "=============================================="

# ---------------------------------------------------------
# 0. Sanity check Node version
# ---------------------------------------------------------
NODE_VER=$(node -v || echo "none")

if [[ "$NODE_VER" != v18* ]]; then
    echo "❌ ERROR: Unsupported Node version: $NODE_VER"
    echo "   Expected: Node 18 LTS"
    echo "   Fix: Run 01-setup-node.sh again"
    exit 1
fi

echo "✔ Node version OK: $NODE_VER"

# ---------------------------------------------------------
# 1. Validate repository
# ---------------------------------------------------------
if ! git ls-remote "$REPO_URL" &>/dev/null; then
    echo "❌ Invalid GitHub repository URL"
    exit 1
fi

# ---------------------------------------------------------
# 2. Clone or update repo
# ---------------------------------------------------------
if [ ! -d "$PROJECT_DIR" ]; then
    echo "==> Cloning repository"
    git clone "$REPO_URL"
else
    echo "==> Updating repository"
    cd "$PROJECT_DIR"
    git fetch --all
    git reset --hard origin/main || git reset --hard origin/master
    cd ..
fi

cd "$PROJECT_DIR"

# ---------------------------------------------------------
# 3. Detect backend folder
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
# 4. Detect client folder
# ---------------------------------------------------------
if [ -d "client" ]; then
    CLIENT_DIR="client"
elif [ -d "frontend" ]; then
    CLIENT_DIR="frontend"
else
    echo "❌ No client/frontend directory found"
    exit 1
fi

# ---------------------------------------------------------
# 5. Build final .env for backend
# ---------------------------------------------------------
echo "==> Building backend .env"

if [ ! -f "$ENV_SOURCE" ]; then
    echo "❌ Env file missing: $ENV_SOURCE"
    echo "   Create it with your user-defined secrets (JWT, STRIPE, etc.)"
    exit 1
fi

if [ ! -f "$MONGO_ENV" ]; then
    echo "❌ Mongo credentials file missing: $MONGO_ENV"
    echo "   This should be created by 02-install-mongodb.sh"
    exit 1
fi

# Load MongoDB APP_USER, APP_PASS, APP_DB
# shellcheck disable=SC1091
source "$MONGO_ENV"

if [ -z "${APP_USER:-}" ] || [ -z "${APP_PASS:-}" ] || [ -z "${APP_DB:-}" ]; then
    echo "❌ APP_USER, APP_PASS or APP_DB not set in $MONGO_ENV"
    exit 1
fi

MONGO_URI="mongodb://${APP_USER}:${APP_PASS}@localhost:27017/${APP_DB}?authSource=admin"

FINAL_ENV_PATH="$SERVER_DIR/.env"

# Create final .env: script-managed vars + user vars (excluding conflicts)
{
    echo "NODE_ENV=production"
    echo "PORT=$PORT"
    echo "MONGO_URI=$MONGO_URI"
    # Append all user vars except ones we manage ourselves
    grep -vE '^(MONGO_URI|NODE_ENV|PORT)=' "$ENV_SOURCE" || true
} > "$FINAL_ENV_PATH"

chmod 600 "$FINAL_ENV_PATH"

echo "✔ Backend .env written to $FINAL_ENV_PATH"
echo "   (MONGO_URI, NODE_ENV, PORT managed by script)"

# ---------------------------------------------------------
# 6. Install backend dependencies
# ---------------------------------------------------------
echo "==> Installing backend dependencies"
cd "$SERVER_DIR"
rm -rf node_modules package-lock.json || true
npm install --legacy-peer-deps

# Detect entry point
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

cd ..

# ---------------------------------------------------------
# 7. Install frontend dependencies
# ---------------------------------------------------------
echo "==> Installing frontend dependencies"
cd "$CLIENT_DIR"
rm -rf node_modules package-lock.json || true
npm install --legacy-peer-deps
cd ..

# ---------------------------------------------------------
# 8. PM2 Process Management
# ---------------------------------------------------------
echo "==> Starting backend using PM2"
cd "$SERVER_DIR"

pm2 delete "$APP_NAME" >/dev/null 2>&1 || true
pm2 start "$ENTRY" --name "$APP_NAME"
pm2 save

# Optionally ensure PM2 starts on reboot
pm2 startup systemd -u root --hp /root >/dev/null 2>&1 || true

echo ""
echo "=============================================="
echo " 🚀 Backend deployed & running"
echo "=============================================="
