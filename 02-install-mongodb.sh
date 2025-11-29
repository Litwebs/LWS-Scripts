#!/bin/bash
set -euo pipefail

# =====================================================================
# 02-install-mongodb.sh (HARDENED & IMPROVED)
# =====================================================================

LOGFILE="/var/log/lws-mongo-install.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo ""
echo "==========================================="
echo "   MongoDB 8.0 Automated Install Script"
echo " Log: $LOGFILE"
echo "==========================================="

# -------------------------
# CONFIG (CUSTOMIZABLE)
# -------------------------
ADMIN_USER="Admin"
ADMIN_PASS="StrongAdminPassword123!"
APP_DB="T3DB"
APP_USER="T3AppUser"
APP_PASS="AppUserPassword123!"
SWAP_SIZE="2G"

# -------------------------
# Helper: wait for MongoDB to be ready
# -------------------------
wait_for_mongo() {
  echo "==> Waiting for MongoDB to be ready on 127.0.0.1:27017..."

  # Try up to 30 times (~60 seconds total)
  for i in {1..30}; do
    if mongosh --quiet --eval "db.adminCommand('ping')" >/dev/null 2>&1; then
      echo "✔ MongoDB is up and responding."
      return 0
    fi
    echo "   ...still starting (attempt $i/30)"
    sleep 2
  done

  echo "❌ MongoDB did not become ready in time."
  echo "   Check: systemctl status mongod && journalctl -u mongod -n 40"
  return 1
}

# -------------------------
# Detect OS
# -------------------------
UBUNTU_CODENAME=$(lsb_release -cs)

echo "Detected Ubuntu version: $UBUNTU_CODENAME"

# -------------------------
# Clean old sources
# -------------------------
echo "==> Removing old MongoDB sources"
sudo rm -f /etc/apt/sources.list.d/mongodb-org-*

# -------------------------
# Install dependencies
# -------------------------
echo "==> Installing dependencies"
sudo apt update -y
sudo apt install -y gnupg curl ca-certificates lsb-release

# -------------------------
# Add GPG Key
# -------------------------
if [ ! -f /usr/share/keyrings/mongodb-server-8.0.gpg ]; then
    echo "==> Adding MongoDB GPG key"
    curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc \
        | sudo gpg --dearmor -o /usr/share/keyrings/mongodb-server-8.0.gpg
else
    echo "MongoDB GPG key already installed"
fi

# -------------------------
# Add Repo (Dynamic Ubuntu version)
# -------------------------
echo "==> Adding MongoDB repository"
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] \
https://repo.mongodb.org/apt/ubuntu $UBUNTU_CODENAME/mongodb-org/8.0 multiverse" \
    | sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list >/dev/null

# -------------------------
# Install MongoDB
# -------------------------
echo "==> Installing MongoDB"
sudo apt update -y
sudo apt install -y mongodb-org

sudo systemctl enable --now mongod

# -------------------------
# Setup Swap (only if missing)
# -------------------------
echo "==> Setting up swap"
if ! swapon --show | grep -q "swap"; then
    sudo fallocate -l "$SWAP_SIZE" /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab
else
    echo "Swap already exists"
fi

# -------------------------
# Wait for Mongo before creating admin user
# -------------------------
wait_for_mongo

# -------------------------
# Create Admin User (auth DISABLED)
# -------------------------
echo "==> Creating admin user (before enabling auth)"

mongosh --quiet --eval "
db = db.getSiblingDB('admin');
if (!db.getUser('$ADMIN_USER')) {
  db.createUser({
    user: '$ADMIN_USER',
    pwd: '$ADMIN_PASS',
    roles: [{ role: 'root', db: 'admin' }]
  });
  print('Admin user created.');
} else {
  print('Admin user already exists.');
}
"

# -------------------------
# Enable Authentication
# -------------------------
echo "==> Enabling authentication"

if ! grep -q "authorization: enabled" /etc/mongod.conf; then
    sudo tee -a /etc/mongod.conf >/dev/null <<EOF
security:
  authorization: enabled
EOF
fi

sudo systemctl restart mongod
sleep 5

# -------------------------
# Create App User (Requires Admin Login Now)
# -------------------------
echo "==> Creating App user"

mongosh --quiet -u "$ADMIN_USER" -p "$ADMIN_PASS" --authenticationDatabase admin --eval "
db = db.getSiblingDB('$APP_DB');
if (!db.getUser('$APP_USER')) {
  db.createUser({
    user: '$APP_USER',
    pwd: '$APP_PASS',
    roles: [{ role: 'readWrite', db: '$APP_DB' }]
  });
  print('App user created.');
} else {
  print('App user already exists.');
}
"

# -------------------------
# Export credentials securely
# -------------------------
echo "==> Saving MongoDB credentials to /etc/lws-mongo.env"

sudo bash -c "cat > /etc/lws-mongo.env" <<EOF
APP_DB="$APP_DB"
APP_USER="$APP_USER"
APP_PASS="$APP_PASS"
EOF

sudo chmod 600 /etc/lws-mongo.env

# -------------------------
# Final Output
# -------------------------
echo ""
echo "==========================================="
echo " MongoDB installation completed successfully!"
echo " Admin User: $ADMIN_USER"
echo " App User:   $APP_USER"
echo " Database:   $APP_DB"
echo ""
echo " Local Mongo URI:"
echo " mongodb://$APP_USER:$APP_PASS@localhost:27017/$APP_DB?authSource=admin"
echo "==========================================="
