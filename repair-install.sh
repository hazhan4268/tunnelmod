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
[[ -r /etc/tunnel-panel/panel.env ]] || {
  echo "TunnelMod is not partially installed. Run the normal installer instead." >&2
  exit 1
}

env TUNNELMOD_UPDATE_APPLY=1 TUNNELMOD_SOURCE_DIR="$SOURCE_DIR" bash ./update.sh
/usr/local/sbin/tunnelmod-render-nginx /etc/tunnel-panel/panel.env
nginx -t
systemctl daemon-reload
systemctl restart tunnel-panel
systemctl restart nginx

for _ in {1..20}; do
  if ss -lnt '( sport = :8443 )' 2>/dev/null | grep -q ':8443'; then
    if curl -kfsS --max-time 3 https://127.0.0.1:8443/login -o /dev/null; then
      echo "Repair completed. Panel responds on https://127.0.0.1:8443/login"
      exit 0
    fi
  fi
  sleep 1
done

echo "Repair failed. Diagnostic output:" >&2
bash ./diagnose.sh || true
exit 1
