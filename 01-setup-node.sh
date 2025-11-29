#!/bin/bash
set -euo pipefail

# =====================================================================
# 01-setup-node.sh — LitWebs Universal Node Setup (Node 18 LTS)
# Supports structure:
#   project-name/
#     server/
#     client/
# =====================================================================

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <GitHubRepoURL> <MongoDBConnectionString>"
    exit 1
fi

REPO_URL="$1"
MONGO_URI="$2"

# Detect repo folder name
PROJECT_DIR=$(basename "$REPO_URL" .git)

echo "======================================="
echo "🚀 Starting Node.js setup for project: $PROJECT_DIR"
echo "======================================="

# --------------------------------------------------------
# Install system packages
# --------------------------------------------------------
sudo apt update -y
sudo apt upgrade -y
sudo apt install -y curl ca-certificates git build-essential

# --------------------------------------------------------
# REMOVE any previous Node versions
# --------------------------------------------------------
echo "== Removing old Node.js versions =="
sudo apt purge -y nodejs npm || true
sudo rm -rf /etc/apt/sources.list.d/nodesource.list || true

# --------------------------------------------------------
# Install Node 18 LTS (SAFE & SUPPORTED)
# --------------------------------------------------------
echo "== Installing Node.js 18 LTS =="
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

echo "Node version: $(node -v)"
echo "NPM version:  $(npm -v)"

# --------------------------------------------------------
# Trust github.com host key (auto-answer yes)
# --------------------------------------------------------
SSH_DIR="/root/.ssh"
KNOWN_HOSTS="$SSH_DIR/known_hosts"

echo "== Ensuring github.com is trusted for SSH =="

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

touch "$KNOWN_HOSTS"
chmod 644 "$KNOWN_HOSTS"

if ! ssh-keygen -F github.com -f "$KNOWN_HOSTS" >/dev/null 2>&1; then
  ssh-keyscan -H github.com >> "$KNOWN_HOSTS" 2>/dev/null
  echo "✔ Added github.com to $KNOWN_HOSTS"
else
  echo "✔ github.com already in $KNOWN_HOSTS"
fi

# --------------------------------------------------------
# Clone repo if missing
# --------------------------------------------------------
if [ -d "$PROJECT_DIR" ]; then
    echo "'$PROJECT_DIR' already exists — skipping clone."
else
    echo "== Cloning project =="
    git clone "$REPO_URL"
fi

cd "$PROJECT_DIR"

# --------------------------------------------------------
# Detect server folder
# --------------------------------------------------------
if [ -d "server" ]; then
    SERVER_DIR="server"
elif [ -d "backend" ]; then
    SERVER_DIR="backend"
else
    echo "❌ ERROR: No server or backend folder found."
    exit 1
fi

# --------------------------------------------------------
# Detect client folder
# --------------------------------------------------------
if [ -d "client" ]; then
    CLIENT_DIR="client"
elif [ -d "frontend" ]; then
    CLIENT_DIR="frontend"
else
    echo "❌ ERROR: No client or frontend folder found."
    exit 1
fi

# --------------------------------------------------------
# Install backend dependencies
# --------------------------------------------------------
echo "== Installing backend dependencies =="
cd "$SERVER_DIR"
rm -rf node_modules package-lock.json || true
npm install --legacy-peer-deps

echo "== Writing backend .env file =="
cat <<EOF > .env
MONGO_URI="$MONGO_URI"
NODE_ENV=production
PORT=5001
EOF

# Detect backend entry file
if [ -f "server.js" ]; then
    ENTRY="server.js"
elif [ -f "index.js" ]; then
    ENTRY="index.js"
elif [ -f "app.js" ]; then
    ENTRY="app.js"
else
    echo "❌ ERROR: No entry file found (server.js/index.js/app.js)"
    exit 1
fi

# --------------------------------------------------------
# Install frontend dependencies
# --------------------------------------------------------
echo "== Installing frontend dependencies =="
cd "../$CLIENT_DIR"
rm -rf node_modules package-lock.json || true
npm install --legacy-peer-deps

# --------------------------------------------------------
# Start backend with PM2
# --------------------------------------------------------
echo "== Installing PM2 =="
sudo npm install -g pm2

echo "== Starting backend =="
cd "../$SERVER_DIR"
pm2 delete express-app >/dev/null 2>&1 || true
pm2 start "$ENTRY" --name express-app
pm2 save

echo ""
echo "======================================="
echo " ✅ Setup complete for: $PROJECT_DIR!"
echo "======================================="
