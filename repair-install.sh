#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $EUID -ne 0 ]]; then
  exec sudo -E bash "$0" "$@"
fi

SOURCE_DIR="${TUNNELMOD_SOURCE_DIR:-/opt/tunnelmod-src}"
REPO_URL="${TUNNELMOD_REPO_URL:-https://github.com/hazhan4268/tunnelmod.git}"

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y git curl ca-certificates nginx

if [[ -d "$SOURCE_DIR/.git" ]]; then
  git -C "$SOURCE_DIR" fetch --prune origin main
  git -C "$SOURCE_DIR" checkout main
  git -C "$SOURCE_DIR" merge --ff-only origin/main
else
  rm -rf "$SOURCE_DIR"
  git clone "$REPO_URL" "$SOURCE_DIR"
fi

cd "$SOURCE_DIR"
if [[ -r /etc/tunnel-panel/panel.env ]]; then
  env TUNNELMOD_UPDATE_APPLY=1 TUNNELMOD_SOURCE_DIR="$SOURCE_DIR" bash ./update.sh
else
  echo "TunnelMod is not partially installed. Run the normal installer instead:" >&2
  echo "sudo bash install-online.sh" >&2
  exit 1
fi

/usr/local/sbin/tunnelmod-render-nginx /etc/tunnel-panel/panel.env
nginx -t
systemctl restart nginx
systemctl restart tunnel-panel

for _ in {1..15}; do
  if curl -kfsS --max-time 3 https://127.0.0.1:8443/login -o /dev/null; then
    echo "Repair completed. Panel responds on https://127.0.0.1:8443/login"
    exit 0
  fi
  sleep 1
done

echo "Repair failed. Diagnostic output:" >&2
bash ./diagnose.sh || true
exit 1
