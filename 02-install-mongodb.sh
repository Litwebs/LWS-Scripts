#!/bin/bash
set -e

### CONFIG (edit if needed)
ADMIN_USER="Admin"
ADMIN_PASS="StrongAdminPassword123!"
APP_DB="T3DB"
APP_USER="T3AppUser"
APP_PASS="AppUserPassword123!"
SWAP_SIZE="2G"

echo "==========================================="
echo "   MongoDB 8.0 Automated Install Script"
echo "==========================================="


### 1. CLEAN OLD REPOS ------------------------------------
echo "==> Removing old MongoDB sources"
sudo rm -f /etc/apt/sources.list.d/mongodb-org-*


### 2. INSTALL DEPENDENCIES --------------------------------
echo "==> Installing dependencies"
sudo apt-get update -y
sudo apt-get install -y gnupg curl


### 3. ADD MONGO GPG KEY -----------------------------------
if [ ! -f /usr/share/keyrings/mongodb-server-8.0.gpg ]; then
    echo "==> Adding MongoDB GPG key"
    curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc \
        | sudo gpg --dearmor -o /usr/share/keyrings/mongodb-server-8.0.gpg
else
    echo "==> GPG key already exists — skipping"
fi


### 4. ADD MONGO REPO --------------------------------------
echo "==> Adding MongoDB repository"
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] \
https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/8.0 multiverse" \
    | sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list >/dev/null


### 5. INSTALL MONGO ---------------------------------------
echo "==> Installing MongoDB"
sudo apt-get update -y
sudo apt-get install -y mongodb-org


### 6. ENABLE SERVICE ---------------------------------------
echo "==> Starting & enabling MongoDB"
sudo systemctl enable --now mongod


### 7. SYSTEMD AUTO-RESTART ---------------------------------
echo "==> Applying systemd restart policy"
sudo sed -i '/^\[Service\]/a Restart=on-failure\nRestartSec=3s' /lib/systemd/system/mongod.service || true
sudo systemctl daemon-reload
sudo systemctl restart mongod


### 8. CREATE SWAP -----------------------------------------
echo "==> Creating swap ($SWAP_SIZE)"
if [ ! -f /swapfile ]; then
    sudo fallocate -l $SWAP_SIZE /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab
else
    echo "Swap already exists — skipping"
fi


### 9. ENABLE AUTH ------------------------------------------
echo "==> Enabling authentication"
if ! grep -q "authorization: enabled" /etc/mongod.conf; then
    sudo tee -a /etc/mongod.conf >/dev/null <<EOF
security:
  authorization: enabled
EOF
fi

sudo systemctl restart mongod
sleep 3


### 10. CREATE ADMIN USER -----------------------------------
echo "==> Creating MongoDB Admin user"
mongosh --eval "
use admin;
db.createUser({
  user: '$ADMIN_USER',
  pwd: '$ADMIN_PASS',
  roles: [{ role: 'root', db: 'admin' }]
});
" || echo "Admin user may already exist — skipping"


### 11. CREATE APP USER -------------------------------------
echo "==> Creating MongoDB App user"
mongosh -u $ADMIN_USER -p "$ADMIN_PASS" --authenticationDatabase admin --eval "
use $APP_DB;
db.createUser({
  user: '$APP_USER',
  pwd: '$APP_PASS',
  roles: [{ role: 'readWrite', db: '$APP_DB' }]
});
" || echo "Application user already exists — skipping"


### DONE -----------------------------------------------------
echo ""
echo "==========================================="
echo " MongoDB installation completed successfully!"
echo " Admin User: $ADMIN_USER"
echo " App User:   $APP_USER"
echo " Database:   $APP_DB"
echo ""
echo " Connection string:"
echo " mongodb://$APP_USER:$APP_PASS@localhost:27017/$APP_DB?authSource=admin"
echo "==========================================="
