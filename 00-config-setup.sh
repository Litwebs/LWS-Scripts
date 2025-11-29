#!/bin/bash
set -euo pipefail

echo "=============================================="
echo " 🔧 00-CONFIG-SETUP — Generic ENV Preparation"
echo "=============================================="

# ------------------------------
# Expect exactly 1 argument: DOMAIN
# ------------------------------
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <DOMAIN>"
    echo "Example: $0 api.litwebs.co.uk"
    exit 1
fi

DOMAIN="$1"

ENV_DIR="/etc/lws-env"
ENV_FILE="$ENV_DIR/$DOMAIN.env"

echo "📁 Checking environment root directory..."

# ------------------------------
# Create secure directory
# ------------------------------
if [ ! -d "$ENV_DIR" ]; then
    echo "➡️  Creating secure directory: $ENV_DIR"
    sudo mkdir -p "$ENV_DIR"
    sudo chmod 700 "$ENV_DIR"
else
    echo "✔ Directory exists: $ENV_DIR"
fi

# ------------------------------
# Create env file if missing
# ------------------------------
if [ ! -f "$ENV_FILE" ]; then
    echo ""
    echo "⚠️  No environment file found for domain:"
    echo "    $ENV_FILE"
    echo "➡️  Creating a new blank template .env..."

    sudo bash -c "cat > \"$ENV_FILE\"" <<EOF
# ====================================================
# ENVIRONMENT FILE FOR $DOMAIN 
# Fill in your variables below.
# This file is PRIVATE and is NOT stored in Git.
# ====================================================

EOF

    sudo chmod 600 "$ENV_FILE"

    echo ""
    echo "🚫 SETUP HALTED"
    echo "👉 Fill in your environment variables inside:"
    echo "   $ENV_FILE"
    echo ""
    echo "Then run the deployment scripts again."
    echo "=============================================="
    exit 1
fi

echo ""
echo "✔ Environment file exists: $ENV_FILE"
echo "✔ No validation performed (generic mode)"
echo "=============================================="
echo " ✅ 00-CONFIG-SETUP COMPLETE"
echo "=============================================="
