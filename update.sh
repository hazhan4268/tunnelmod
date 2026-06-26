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
  echo "TunnelMod source repository was not found. Clone the repository and run the online installer once." >&2
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

bash -n install.sh update.sh domain.sh diagnose.sh uninstall.sh scripts/tunnel-panel-helper scripts/render-nginx.sh scripts/install-agent.sh
python3 -m compileall -q tunnel_panel tests
if ! command -v curl >/dev/null; then
  apt-get update
  apt-get install -y curl
fi

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup="/var/backups/tunnelmod/${timestamp}"
install -d -o root -g root -m 700 "$backup"

copy_if_exists() { [[ -e "$1" ]] && cp -a "$1" "$2" || true; }
copy_if_exists /opt/tunnel-panel "$backup/opt-tunnel-panel"
copy_if_exists /var/lib/tunnel-panel "$backup/var-lib-tunnel-panel"
copy_if_exists /etc/tunnel-panel "$backup/etc-tunnel-panel"
copy_if_exists /usr/local/sbin/tunnel-panel-helper "$backup/tunnel-panel-helper"
copy_if_exists /usr/local/sbin/tunnelmod-update "$backup/tunnelmod-update"
copy_if_exists /usr/local/sbin/tunnelmod-diagnose "$backup/tunnelmod-diagnose"
copy_if_exists /usr/local/sbin/tunnelmod-domain "$backup/tunnelmod-domain"
copy_if_exists /usr/local/sbin/tunnelmod-render-nginx "$backup/tunnelmod-render-nginx"
copy_if_exists /usr/local/sbin/tunnelmod-agent "$backup/tunnelmod-agent"
copy_if_exists /etc/systemd/system/tunnel-panel.service "$backup/tunnel-panel.service"
copy_if_exists /etc/systemd/system/tunnel-panel-haproxy.service "$backup/tunnel-panel-haproxy.service"
copy_if_exists /etc/nginx/nginx.conf "$backup/nginx.conf"
copy_if_exists /etc/nginx/conf.d/tunnel-panel.conf "$backup/nginx-conf.d-tunnel-panel.conf"
copy_if_exists /etc/nginx/sites-available/tunnel-panel "$backup/nginx-sites-available-tunnel-panel"
copy_if_exists /etc/nginx/sites-enabled/tunnel-panel "$backup/nginx-sites-enabled-tunnel-panel"
copy_if_exists /etc/nginx/tunnel-panel.include.conf "$backup/nginx-direct-include.conf"

restore_file() { [[ -e "$1" ]] && cp -a "$1" "$2" || true; }
completed=0
rollback() {
  status=$?
  trap - ERR
  if [[ $completed -eq 0 ]]; then
    echo "Update failed; restoring the previous installed version..." >&2
    [[ -d "$backup/opt-tunnel-panel" ]] && { rm -rf /opt/tunnel-panel; cp -a "$backup/opt-tunnel-panel" /opt/tunnel-panel; }
    [[ -d "$backup/var-lib-tunnel-panel" ]] && { rm -rf /var/lib/tunnel-panel; cp -a "$backup/var-lib-tunnel-panel" /var/lib/tunnel-panel; }
    [[ -d "$backup/etc-tunnel-panel" ]] && { rm -rf /etc/tunnel-panel; cp -a "$backup/etc-tunnel-panel" /etc/tunnel-panel; }
    restore_file "$backup/tunnel-panel-helper" /usr/local/sbin/tunnel-panel-helper
    restore_file "$backup/tunnelmod-update" /usr/local/sbin/tunnelmod-update
    restore_file "$backup/tunnelmod-diagnose" /usr/local/sbin/tunnelmod-diagnose
    restore_file "$backup/tunnelmod-domain" /usr/local/sbin/tunnelmod-domain
    restore_file "$backup/tunnelmod-render-nginx" /usr/local/sbin/tunnelmod-render-nginx
    restore_file "$backup/tunnelmod-agent" /usr/local/sbin/tunnelmod-agent
    restore_file "$backup/tunnel-panel.service" /etc/systemd/system/tunnel-panel.service
    restore_file "$backup/tunnel-panel-haproxy.service" /etc/systemd/system/tunnel-panel-haproxy.service
    restore_file "$backup/nginx.conf" /etc/nginx/nginx.conf
    restore_file "$backup/nginx-conf.d-tunnel-panel.conf" /etc/nginx/conf.d/tunnel-panel.conf
    restore_file "$backup/nginx-sites-available-tunnel-panel" /etc/nginx/sites-available/tunnel-panel
    restore_file "$backup/nginx-sites-enabled-tunnel-panel" /etc/nginx/sites-enabled/tunnel-panel
    restore_file "$backup/nginx-direct-include.conf" /etc/nginx/tunnel-panel.include.conf
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
install -o root -g root -m 644 "$SOURCE_DIR/VERSION" /opt/tunnel-panel/VERSION
[[ -x /opt/tunnel-panel/venv/bin/pip ]] || python3 -m venv /opt/tunnel-panel/venv
/opt/tunnel-panel/venv/bin/pip install --no-cache-dir -r /opt/tunnel-panel/requirements.txt

install -o root -g root -m 750 "$SOURCE_DIR/scripts/tunnel-panel-helper" /usr/local/sbin/tunnel-panel-helper
install -o root -g root -m 755 "$SOURCE_DIR/update.sh" /usr/local/sbin/tunnelmod-update
install -o root -g root -m 755 "$SOURCE_DIR/diagnose.sh" /usr/local/sbin/tunnelmod-diagnose
install -o root -g root -m 755 "$SOURCE_DIR/domain.sh" /usr/local/sbin/tunnelmod-domain
install -o root -g root -m 755 "$SOURCE_DIR/scripts/render-nginx.sh" /usr/local/sbin/tunnelmod-render-nginx
bash "$SOURCE_DIR/scripts/install-agent.sh" "$SOURCE_DIR" || echo "Warning: Go agent build failed; Python fallback remains active." >&2
install -o root -g root -m 644 "$SOURCE_DIR/scripts/tunnel-panel.service" /etc/systemd/system/tunnel-panel.service
install -o root -g root -m 644 "$SOURCE_DIR/scripts/tunnel-panel-haproxy.service" /etc/systemd/system/tunnel-panel-haproxy.service
printf '%s\n' "$SOURCE_DIR" >"$SOURCE_FILE"
chmod 600 "$SOURCE_FILE"

/usr/local/sbin/tunnelmod-render-nginx /etc/tunnel-panel/panel.env
systemctl daemon-reload
systemctl restart tunnel-panel
systemctl restart nginx

healthy=0
for _attempt in {1..20}; do
  if ss -lnt '( sport = :8443 )' 2>/dev/null | grep -q ':8443' && curl -kfsS --max-time 3 https://127.0.0.1:8443/login -o /dev/null; then
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
