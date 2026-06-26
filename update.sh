#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Run with sudo: sudo tunnelmod-update" >&2
  exit 1
fi

SOURCE_FILE=/etc/tunnel-panel/source.path
SOURCE_DIR="${TUNNELMOD_SOURCE_DIR:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "$SOURCE_DIR" && -r "$SOURCE_FILE" ]]; then
  SOURCE_DIR="$(<"$SOURCE_FILE")"
fi
if [[ -z "$SOURCE_DIR" && -d "$SCRIPT_DIR/.git" ]]; then
  SOURCE_DIR="$SCRIPT_DIR"
fi
[[ -n "$SOURCE_DIR" && -d "$SOURCE_DIR/.git" ]] || {
  echo "TunnelMod source repository was not found. Clone the repository and run sudo ./install.sh once." >&2
  exit 1
}
SOURCE_DIR="$(readlink -f "$SOURCE_DIR")"
cd "$SOURCE_DIR"
SOURCE_OWNER="$(stat -c %U "$SOURCE_DIR")"
git_source() {
  if [[ "$SOURCE_OWNER" == root ]]; then
    git -C "$SOURCE_DIR" "$@"
  else
    runuser -u "$SOURCE_OWNER" -- git -C "$SOURCE_DIR" "$@"
  fi
}

if [[ "${TUNNELMOD_UPDATE_APPLY:-0}" != 1 ]]; then
  [[ "$(git_source symbolic-ref --short HEAD)" == main ]] || {
    echo "Update stopped: the source repository must be on the main branch." >&2
    exit 1
  }
  if [[ -n "$(git_source status --porcelain --untracked-files=no)" ]]; then
    echo "Update stopped: the source repository contains local modifications." >&2
    echo "Commit or discard those changes before updating." >&2
    exit 1
  fi
  current="$(git_source rev-parse --short HEAD)"
  echo "Checking GitHub for updates..."
  git_source fetch --prune origin main
  git_source merge --ff-only origin/main
  target="$(git_source rev-parse --short HEAD)"
  echo "Source: ${current} -> ${target}"
  exec env TUNNELMOD_UPDATE_APPLY=1 TUNNELMOD_SOURCE_DIR="$SOURCE_DIR" bash "$SOURCE_DIR/update.sh"
fi

bash -n install.sh update.sh diagnose.sh uninstall.sh scripts/tunnel-panel-helper
python3 -m compileall -q tunnel_panel tests
if ! command -v curl >/dev/null; then
  apt-get update
  apt-get install -y curl
fi

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup="/var/backups/tunnelmod/${timestamp}"
install -d -o root -g root -m 700 "$backup"

[[ -d /opt/tunnel-panel ]] && cp -a /opt/tunnel-panel "$backup/opt-tunnel-panel"
[[ -d /var/lib/tunnel-panel ]] && cp -a /var/lib/tunnel-panel "$backup/var-lib-tunnel-panel"
[[ -d /etc/tunnel-panel ]] && cp -a /etc/tunnel-panel "$backup/etc-tunnel-panel"
[[ -f /usr/local/sbin/tunnel-panel-helper ]] && cp -a /usr/local/sbin/tunnel-panel-helper "$backup/tunnel-panel-helper"
[[ -f /usr/local/sbin/tunnelmod-update ]] && cp -a /usr/local/sbin/tunnelmod-update "$backup/tunnelmod-update"
[[ -f /usr/local/sbin/tunnelmod-diagnose ]] && cp -a /usr/local/sbin/tunnelmod-diagnose "$backup/tunnelmod-diagnose"
[[ -f /etc/systemd/system/tunnel-panel.service ]] && cp -a /etc/systemd/system/tunnel-panel.service "$backup/tunnel-panel.service"
[[ -f /etc/systemd/system/tunnel-panel-haproxy.service ]] && cp -a /etc/systemd/system/tunnel-panel-haproxy.service "$backup/tunnel-panel-haproxy.service"
[[ -f /etc/nginx/sites-available/tunnel-panel ]] && cp -a /etc/nginx/sites-available/tunnel-panel "$backup/nginx-tunnel-panel"

completed=0
rollback() {
  status=$?
  trap - ERR
  if [[ $completed -eq 0 ]]; then
    echo "Update failed; restoring the previous installed version..." >&2
    if [[ -d "$backup/opt-tunnel-panel" ]]; then
      rm -rf /opt/tunnel-panel
      cp -a "$backup/opt-tunnel-panel" /opt/tunnel-panel
    fi
    if [[ -d "$backup/var-lib-tunnel-panel" ]]; then
      rm -rf /var/lib/tunnel-panel
      cp -a "$backup/var-lib-tunnel-panel" /var/lib/tunnel-panel
    fi
    if [[ -d "$backup/etc-tunnel-panel" ]]; then
      rm -rf /etc/tunnel-panel
      cp -a "$backup/etc-tunnel-panel" /etc/tunnel-panel
    fi
    [[ -f "$backup/tunnel-panel-helper" ]] && cp -a "$backup/tunnel-panel-helper" /usr/local/sbin/tunnel-panel-helper
    [[ -f "$backup/tunnelmod-update" ]] && cp -a "$backup/tunnelmod-update" /usr/local/sbin/tunnelmod-update
    [[ -f "$backup/tunnelmod-diagnose" ]] && cp -a "$backup/tunnelmod-diagnose" /usr/local/sbin/tunnelmod-diagnose
    [[ -f "$backup/tunnel-panel.service" ]] && cp -a "$backup/tunnel-panel.service" /etc/systemd/system/tunnel-panel.service
    [[ -f "$backup/tunnel-panel-haproxy.service" ]] && cp -a "$backup/tunnel-panel-haproxy.service" /etc/systemd/system/tunnel-panel-haproxy.service
    [[ -f "$backup/nginx-tunnel-panel" ]] && cp -a "$backup/nginx-tunnel-panel" /etc/nginx/sites-available/tunnel-panel
    systemctl daemon-reload || true
    systemctl restart tunnel-panel nginx || true
    echo "Rollback completed. Backup: $backup" >&2
  fi
  exit "$status"
}
trap rollback ERR

rm -rf /opt/tunnel-panel/tunnel_panel
cp -a "$SOURCE_DIR/tunnel_panel" /opt/tunnel-panel/
install -o root -g root -m 644 "$SOURCE_DIR/requirements.txt" /opt/tunnel-panel/requirements.txt
[[ -x /opt/tunnel-panel/venv/bin/pip ]] || python3 -m venv /opt/tunnel-panel/venv
/opt/tunnel-panel/venv/bin/pip install --no-cache-dir -r /opt/tunnel-panel/requirements.txt

install -o root -g root -m 750 "$SOURCE_DIR/scripts/tunnel-panel-helper" /usr/local/sbin/tunnel-panel-helper
install -o root -g root -m 755 "$SOURCE_DIR/update.sh" /usr/local/sbin/tunnelmod-update
install -o root -g root -m 755 "$SOURCE_DIR/diagnose.sh" /usr/local/sbin/tunnelmod-diagnose
install -o root -g root -m 644 "$SOURCE_DIR/scripts/tunnel-panel.service" /etc/systemd/system/tunnel-panel.service
install -o root -g root -m 644 "$SOURCE_DIR/scripts/tunnel-panel-haproxy.service" /etc/systemd/system/tunnel-panel-haproxy.service
install -o root -g root -m 644 "$SOURCE_DIR/scripts/nginx.conf.template" /etc/nginx/sites-available/tunnel-panel
printf '%s\n' "$SOURCE_DIR" >"$SOURCE_FILE"
chmod 600 "$SOURCE_FILE"

nginx -t
systemctl daemon-reload
systemctl restart tunnel-panel nginx

healthy=0
for _attempt in {1..10}; do
  if curl -kfsS --max-time 3 https://127.0.0.1:8443/login -o /dev/null; then
    healthy=1
    break
  fi
  sleep 1
done
[[ $healthy -eq 1 ]]

completed=1
trap - ERR
version="$(<"$SOURCE_DIR/VERSION")"
echo "TunnelMod ${version} is installed and healthy."
echo "Backup: $backup"
