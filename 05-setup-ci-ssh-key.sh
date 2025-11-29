#!/bin/bash
set -euo pipefail

# =====================================================================
# 05-setup-ci-ssh-key.sh — SSH key for:
#   - GitHub Actions → VPS (authorized_keys)
#   - VPS → GitHub (private repo via SSH)
# =====================================================================

KEY_PATH="${1:-/root/.ssh/github-deploy}"
SSH_DIR="/root/.ssh"
AUTH_KEYS="$SSH_DIR/authorized_keys"
SSH_CONFIG="$SSH_DIR/config"

echo ""
echo "=============================================="
echo "   GitHub CI SSH Key Setup"
echo "   Key path: $KEY_PATH"
echo "=============================================="

# Ensure .ssh directory exists with correct perms
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

# Generate keypair if missing
if [ -f "$KEY_PATH" ] && [ -f "$KEY_PATH.pub" ]; then
  echo "✔ SSH key already exists at:"
  echo "   $KEY_PATH"
  echo "   $KEY_PATH.pub"
else
  echo "==> Generating new SSH keypair for CI + GitHub access"

  ssh-keygen \
    -t ed25519 \
    -f "$KEY_PATH" \
    -N "" \
    -C "github-deploy-$(hostname)"

  echo "✔ Keypair generated:"
  echo "   Private: $KEY_PATH"
  echo "   Public:  $KEY_PATH.pub"
fi

PUB_KEY_CONTENT=$(cat "$KEY_PATH.pub")

# Ensure public key is allowed for SSH (Actions → VPS)
if grep -qF "$PUB_KEY_CONTENT" "$AUTH_KEYS" 2>/dev/null; then
  echo "✔ Public key already present in $AUTH_KEYS"
else
  echo "==> Adding public key to $AUTH_KEYS"
  touch "$AUTH_KEYS"
  chmod 600 "$AUTH_KEYS"
  echo "$PUB_KEY_CONTENT" >> "$AUTH_KEYS"
  echo "✔ Public key added."
fi

# Configure SSH for github.com (VPS → GitHub)
if [ -f "$SSH_CONFIG" ] && grep -q "Host github.com" "$SSH_CONFIG"; then
  echo "✔ SSH config for github.com already exists in $SSH_CONFIG"
else
  echo "==> Updating SSH config for github.com"

  {
    echo ""
    echo "Host github.com"
    echo "  HostName github.com"
    echo "  User git"
    echo "  IdentityFile $KEY_PATH"
    echo "  IdentitiesOnly yes"
  } >> "$SSH_CONFIG"

  chmod 600 "$SSH_CONFIG"
  echo "✔ SSH config updated."
fi

echo ""
echo "=============================================="
echo " NEXT STEPS (one-time manual GitHub setup):"
echo ""
echo " 1) Show the *public* key with:"
echo "       cat $KEY_PATH.pub"
echo ""
echo " 2) In GitHub → Your Repo → Settings → Deploy keys:"
echo "      - Click 'Add deploy key'"
echo "      - Paste the public key"
echo "      - Allow 'Read access' (no need for write)"
echo ""
echo " 3) GitHub Actions → Settings → Secrets → Actions:"
echo "      - VPS_HOST  → your server IP or domain"
echo "      - VPS_USER  → root"
echo "      - VPS_PORT  → 22 (or your SSH port)"
echo "      - VPS_SSH_KEY → contents of: cat $KEY_PATH"
echo "=============================================="
