#!/bin/bash
set -e

# === VALIDATE ARGUMENTS ===
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <GitHubRepoURL> <MongoDBConnectionString>"
    exit 1
fi

REPO_URL=$1
MONGO_CONN_STRING=$2

# === INSTALL SYSTEM DEPENDENCIES ===
echo "== Updating System =="
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl ca-certificates git

# === INSTALL NODE.JS ===
echo "== Installing Node.js =="
curl -fsSL https://deb.nodesource.com/setup_current.x | sudo -E bash -
sudo apt install -y nodejs

echo "Node version: $(node -v)"
echo "NPM version: $(npm -v)"

# === CLONE APP ===
if [ -d "app" ]; then
    echo "Directory 'app' already exists — skipping git clone."
else
    echo "== Cloning App Repo =="
    git clone $REPO_URL app
fi

cd app

# === INSTALL DEPENDENCIES ===
echo "== Installing NPM Packages =="
npm install

# === CREATE .env WITH MONGO CONNECTION ===
echo "== Writing MongoDB Connection String =="
echo "MONGO_URI=\"$MONGO_CONN_STRING\"" > .env

# === INSTALL PM2 ===
echo "== Installing PM2 =="
sudo npm install -g pm2

# === START APP ===
echo "== Starting App with PM2 =="
pm2 start index.js --name express-app

# === PM2 STARTUP ===
echo "== Enabling PM2 Startup =="
pm2 save
pm2 startup systemd -u $USER --hp $HOME | sudo bash

echo "======================================="
echo "✅ Node.js environment setup complete!"
echo "📦 App deployed using PM2"
echo "🔗 MongoDB connection saved in .env"
echo "======================================="
