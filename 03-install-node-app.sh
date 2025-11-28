#!/bin/bash
set -e

# === VALIDATION ===
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <GitHubRepoURL>"
    exit 1
fi

REPO_URL=$1

echo "=============================================="
echo "   Node.js + PM2 + Express Deployment Script"
echo "=============================================="

# 1. Update system
echo "==> Updating system"
sudo apt update && sudo apt upgrade -y

# 2. Install base tools
echo "==> Installing curl, certificates, and Git"
sudo apt install -y curl ca-certificates git

# 3. Enable NodeSource repo
echo "==> Adding NodeSource repo"
curl -fsSL https://deb.nodesource.com/setup_current.x | sudo -E bash -


# 5. Clone the project
echo "==> Cloning project: $REPO_URL"
if [ -d "app" ]; then
    echo "Directory 'app' exists — skipping clone."
else
    git clone $REPO_URL app
fi

cd app

# 6. Install dependencies
echo "==> Installing dependencies"
npm install

# 7. Install PM2 globally
echo "==> Installing PM2"
sudo npm install -g pm2

# 8. Start app with PM2
echo "==> Starting Express app with PM2"
pm2 start index.js --name express-app

# 9. Enable PM2 startup
echo "==> Saving PM2 process"
pm2 save

echo "==> Enabling PM2 startup on boot"
pm2 startup systemd -u $USER --hp $HOME | sudo bash

# 10. Display connection instructions
echo ""
echo "=============================================="
echo " Deployment Complete!"
echo " App Name: express-app"
echo " PM2 Status: pm2 status"
echo ""
echo " MongoDB Example Connection (use your real values):"
echo ' mongodb://username:password@localhost:27017/db_name?authSource=admin'
echo "=============================================="
