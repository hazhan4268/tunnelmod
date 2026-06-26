#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $EUID -ne 0 ]]; then
  exec sudo -E bash "$0" "$@"
fi

REPO_URL="${TUNNELMOD_REPO_URL:-https://github.com/hazhan4268/tunnelmod.git}"
SOURCE_DIR="${TUNNELMOD_SOURCE_DIR:-/opt/tunnelmod-src}"
ENV_FILE="/etc/tunnel-panel/panel.env"

export DEBIAN_FRONTEND=noninteractive
export PANEL_TLS_MODE=off
export PANEL_DOMAIN=
export PANEL_LETSENCRYPT_EMAIL=
export LETSENCRYPT_EMAIL=

echo "TunnelMod online installer"
echo "Default panel mode: HTTP on port 8443"
echo "No domain, SSL, IP certificate, or self-signed certificate is required."

apt-get update
apt-get install -y git curl ca-certificates whiptail

if [[ -d "$SOURCE_DIR/.git" ]]; then
  git -C "$SOURCE_DIR" fetch --prune origin main
  git -C "$SOURCE_DIR" checkout main
  git -C "$SOURCE_DIR" reset --hard origin/main
else
  rm -rf "$SOURCE_DIR"
  git clone "$REPO_URL" "$SOURCE_DIR"
fi

cd "$SOURCE_DIR"

set +e
bash ./install.sh "$@"
set -e

if [[ -f "$ENV_FILE" ]]; then
  tmp="$(mktemp)"
  grep -v '^PANEL_TLS_MODE=' "$ENV_FILE" | grep -v '^PANEL_DOMAIN=' | grep -v '^PANEL_LETSENCRYPT_EMAIL=' >"$tmp" || true
  printf 'PANEL_TLS_MODE=off\nPANEL_DOMAIN=\nPANEL_LETSENCRYPT_EMAIL=\n' >>"$tmp"
  install -o root -g tunnelpanel -m 640 "$tmp" "$ENV_FILE"
  rm -f "$tmp"
fi

env TUNNELMOD_UPDATE_APPLY=1 TUNNELMOD_SOURCE_DIR="$SOURCE_DIR" bash ./update.sh

for _ in {1..20}; do
  if curl -fsS --max-time 3 http://127.0.0.1:8443/login -o /dev/null; then
    echo "TunnelMod installed successfully."
    echo "Panel URL: http://YOUR_SERVER_IP:8443"
    exit 0
  fi
  sleep 1
done

echo "Installation failed. Diagnostic output:" >&2
bash ./diagnose.sh || true
exit 1
