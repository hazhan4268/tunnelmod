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
  read -rp "Panel domain for Let's Encrypt SSL (optional, press Enter to skip): " DOMAIN
fi
if [[ -n "$DOMAIN" && -z "$EMAIL" ]]; then
  read -rp "Email for Let's Encrypt notices (optional): " EMAIL
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
bash ./install.sh "$@"
env TUNNELMOD_UPDATE_APPLY=1 TUNNELMOD_SOURCE_DIR="$SOURCE_DIR" bash ./update.sh

if [[ -n "$DOMAIN" ]]; then
  echo "Activating domain SSL for: $DOMAIN"
  bash ./domain.sh "$DOMAIN" "$EMAIL"
fi
