#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $EUID -ne 0 ]]; then
  exec sudo -E bash "$0" "$@"
fi

REPO_URL="${TUNNELMOD_REPO_URL:-https://github.com/hazhan4268/tunnelmod.git}"
SOURCE_DIR="${TUNNELMOD_SOURCE_DIR:-/opt/tunnelmod-src}"
DOMAIN="${PANEL_DOMAIN:-}"
EMAIL="${LETSENCRYPT_EMAIL:-${PANEL_LETSENCRYPT_EMAIL:-}}"

if [[ -z "$DOMAIN" ]]; then
  read -rp "Panel domain for initial SSL setup (optional, press Enter for self-signed): " DOMAIN
fi
if [[ -n "$DOMAIN" ]]; then
  [[ "$DOMAIN" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$ ]] || {
    echo "Invalid domain name." >&2
    exit 1
  }
  if [[ -z "$EMAIL" ]]; then
    read -rp "Email for Let's Encrypt notices (optional): " EMAIL
  fi
fi

export PANEL_DOMAIN="$DOMAIN"
export PANEL_LETSENCRYPT_EMAIL="$EMAIL"
export LETSENCRYPT_EMAIL="$EMAIL"
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y git ca-certificates curl

if [[ -d "$SOURCE_DIR/.git" ]]; then
  git -C "$SOURCE_DIR" fetch --prune origin main
  git -C "$SOURCE_DIR" checkout main
  git -C "$SOURCE_DIR" merge --ff-only origin/main
else
  rm -rf "$SOURCE_DIR"
  git clone "$REPO_URL" "$SOURCE_DIR"
fi

cd "$SOURCE_DIR"

# Base install first, then update stage installs the latest helper, renderer and Go agent.
bash ./install.sh "$@"
env TUNNELMOD_UPDATE_APPLY=1 TUNNELMOD_SOURCE_DIR="$SOURCE_DIR" bash ./update.sh

# Domain SSL is part of the initial installer flow, not a separate user step.
if [[ -n "$DOMAIN" ]]; then
  echo "Configuring Let's Encrypt SSL during installation: $DOMAIN"
  bash ./domain.sh "$DOMAIN" "$EMAIL"
fi

if ! curl -kfsS --max-time 5 https://127.0.0.1:8443/login -o /dev/null; then
  echo "Installation health check failed. Run: sudo tunnelmod-diagnose" >&2
  exit 1
fi

echo
echo "TunnelMod installation finished."
if [[ -n "$DOMAIN" ]]; then
  echo "Panel URL: https://${DOMAIN}:8443"
else
  echo "Panel URL: https://YOUR_SERVER_IP:8443"
fi
echo "Updates: sudo tunnelmod-update or use System and Update inside the panel."
