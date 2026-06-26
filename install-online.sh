#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $EUID -ne 0 ]]; then
  exec sudo -E bash "$0" "$@"
fi

REPO_URL="${TUNNELMOD_REPO_URL:-https://github.com/hazhan4268/tunnelmod.git}"
SOURCE_DIR="${TUNNELMOD_SOURCE_DIR:-/opt/tunnelmod-src}"
ENV_FILE="/etc/tunnel-panel/panel.env"
DOMAIN="${PANEL_DOMAIN:-}"
EMAIL="${LETSENCRYPT_EMAIL:-${PANEL_LETSENCRYPT_EMAIL:-}}"
USE_TUI=0

export DEBIAN_FRONTEND=noninteractive

plain_banner() {
  cat <<'EOF'
============================================================
 TunnelMod Installer
 Clean install, integrated SSL, final health check
============================================================
EOF
}

can_tui() {
  [[ "${TUNNELMOD_NO_TUI:-0}" != "1" && -t 0 && -t 1 && -x /usr/bin/whiptail ]]
}

tui_msg() {
  if (( USE_TUI )); then
    whiptail --title "TunnelMod Installer" --msgbox "$1" 13 72
  else
    printf '\n==> %s\n' "$1"
  fi
}

tui_info() {
  if (( USE_TUI )); then
    whiptail --title "TunnelMod Installer" --infobox "$1" 9 72
    sleep 1
  else
    printf '\n-- %s\n' "$1"
  fi
}

tui_input() {
  local title="$1" text="$2" default="${3:-}" value
  if (( USE_TUI )); then
    value=$(whiptail --title "$title" --inputbox "$text" 10 76 "$default" 3>&1 1>&2 2>&3) || value=""
    printf '%s' "$value"
  else
    read -rp "$text ${default:+[$default]}: " value
    printf '%s' "${value:-$default}"
  fi
}

tui_confirm_prereq() {
  local text="Before continuing, make sure:\n\n- Ubuntu 20.04+ is installed\n- You have full sudo/root access\n- TCP/8443 is open for the panel\n- For domain SSL, TCP/80 is open and the A record points to this server\n\nIf an old TunnelMod installation exists, it will be backed up, removed, and rebuilt.\n\nContinue installation?"
  if (( USE_TUI )); then
    whiptail --title "TunnelMod prerequisites" --yesno "$text" 19 76
  else
    echo "$text"
    read -rp "Continue? [Y/n]: " ans
    [[ "${ans:-Y}" =~ ^[Yy]$|^$ ]]
  fi
}

set_env_value() {
  local key="$1" value="$2" tmp
  [[ -f "$ENV_FILE" ]] || return 0
  tmp="$(mktemp)"
  grep -v "^${key}=" "$ENV_FILE" >"$tmp" || true
  printf '%s=%s\n' "$key" "$value" >>"$tmp"
  install -o root -g tunnelpanel -m 640 "$tmp" "$ENV_FILE"
  rm -f "$tmp"
}

remove_direct_nginx_include() {
  local conf="/etc/nginx/nginx.conf"
  local inc="include /etc/nginx/tunnel-panel.include.conf;"
  if [[ -f "$conf" ]] && grep -qF "$inc" "$conf"; then
    cp -a "$conf" "${conf}.tunnelmod.clean.bak.$(date -u +%Y%m%dT%H%M%SZ)"
    grep -vF "$inc" "$conf" > /tmp/tunnelmod-nginx.conf
    install -o root -g root -m 644 /tmp/tunnelmod-nginx.conf "$conf"
    rm -f /tmp/tunnelmod-nginx.conf
  fi
}

clean_previous_install() {
  local backup="/var/backups/tunnelmod/clean-install-$(date -u +%Y%m%dT%H%M%SZ)"
  install -d -o root -g root -m 700 "$backup"

  [[ -d /opt/tunnel-panel ]] && cp -a /opt/tunnel-panel "$backup/opt-tunnel-panel"
  [[ -d /etc/tunnel-panel ]] && cp -a /etc/tunnel-panel "$backup/etc-tunnel-panel"
  [[ -d /var/lib/tunnel-panel ]] && cp -a /var/lib/tunnel-panel "$backup/var-lib-tunnel-panel"
  [[ -f /etc/nginx/nginx.conf ]] && cp -a /etc/nginx/nginx.conf "$backup/nginx.conf"
  [[ -f /etc/nginx/conf.d/tunnel-panel.conf ]] && cp -a /etc/nginx/conf.d/tunnel-panel.conf "$backup/nginx-conf.d-tunnel-panel.conf"
  [[ -f /etc/nginx/sites-available/tunnel-panel ]] && cp -a /etc/nginx/sites-available/tunnel-panel "$backup/nginx-sites-available-tunnel-panel"
  [[ -e /etc/nginx/sites-enabled/tunnel-panel ]] && cp -a /etc/nginx/sites-enabled/tunnel-panel "$backup/nginx-sites-enabled-tunnel-panel"
  [[ -f /etc/nginx/tunnel-panel.include.conf ]] && cp -a /etc/nginx/tunnel-panel.include.conf "$backup/nginx-direct-include.conf"

  systemctl disable --now tunnel-panel 2>/dev/null || true
  systemctl disable --now tunnel-panel-haproxy 2>/dev/null || true
  rm -rf /opt/tunnel-panel /etc/tunnel-panel /var/lib/tunnel-panel
  rm -f /etc/systemd/system/tunnel-panel.service /etc/systemd/system/tunnel-panel-haproxy.service
  rm -f /etc/sudoers.d/tunnel-panel
  rm -f /usr/local/sbin/tunnel-panel-helper /usr/local/sbin/tunnelmod-update /usr/local/sbin/tunnelmod-diagnose /usr/local/sbin/tunnelmod-domain /usr/local/sbin/tunnelmod-render-nginx /usr/local/sbin/tunnelmod-agent
  rm -f /etc/nginx/conf.d/tunnel-panel.conf /etc/nginx/sites-available/tunnel-panel /etc/nginx/sites-enabled/tunnel-panel /etc/nginx/tunnel-panel.include.conf
  remove_direct_nginx_include
  systemctl daemon-reload || true
  echo "$backup"
}

plain_banner
apt-get update
apt-get install -y git ca-certificates curl whiptail
can_tui && USE_TUI=1 || USE_TUI=0

if (( USE_TUI )); then
  whiptail --title "TunnelMod Installer" --msgbox "Welcome to TunnelMod.\n\nThis installer backs up and removes old TunnelMod folders, rebuilds the panel, configures Nginx, optionally requests domain SSL, and performs a real health check." 15 76
fi

tui_confirm_prereq || { echo "Installation cancelled." >&2; exit 1; }

if [[ -z "$DOMAIN" ]]; then
  DOMAIN="$(tui_input "Domain SSL" "Panel domain for initial SSL setup. Leave empty for self-signed certificate." "")"
fi
if [[ -n "$DOMAIN" ]]; then
  [[ "$DOMAIN" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$ ]] || {
    tui_msg "Invalid domain name: $DOMAIN"
    exit 1
  }
  if [[ -z "$EMAIL" ]]; then
    EMAIL="$(tui_input "Let's Encrypt email" "Email for Let's Encrypt notices. Optional." "")"
  fi
fi

export PANEL_DOMAIN="$DOMAIN"
export PANEL_LETSENCRYPT_EMAIL="$EMAIL"
export LETSENCRYPT_EMAIL="$EMAIL"

tui_info "Step 1/7: Downloading or updating TunnelMod source..."
if [[ -d "$SOURCE_DIR/.git" ]]; then
  git -C "$SOURCE_DIR" fetch --prune origin main
  git -C "$SOURCE_DIR" checkout main
  git -C "$SOURCE_DIR" reset --hard origin/main
else
  rm -rf "$SOURCE_DIR"
  git clone "$REPO_URL" "$SOURCE_DIR"
fi

cd "$SOURCE_DIR"

tui_info "Step 2/7: Backing up and removing previous installation folders..."
backup_path="$(clean_previous_install)"

tui_info "Step 3/7: Running fresh base installer. You will be asked for public IP and panel password."
set +e
bash ./install.sh "$@"
base_status=$?
set -e
if [[ $base_status -ne 0 ]]; then
  tui_info "Base installer stopped before the final health check. Applying automatic migration and repair..."
fi

if [[ -n "$DOMAIN" ]]; then
  set_env_value PANEL_DOMAIN "$DOMAIN"
  set_env_value PANEL_LETSENCRYPT_EMAIL "$EMAIL"
fi

tui_info "Step 4/7: Installing latest helpers, Nginx renderer, update tools, and Go agent..."
env TUNNELMOD_UPDATE_APPLY=1 TUNNELMOD_SOURCE_DIR="$SOURCE_DIR" bash ./update.sh

if [[ -n "$DOMAIN" ]]; then
  tui_info "Step 5/7: Requesting and installing Let's Encrypt SSL for $DOMAIN..."
  bash ./domain.sh "$DOMAIN" "$EMAIL"
else
  tui_info "Step 5/7: Domain SSL skipped. Self-signed certificate remains active."
fi

tui_info "Step 6/7: Running local HTTPS health check..."
if ! ss -lnt '( sport = :8443 )' 2>/dev/null | grep -q ':8443' || ! curl -kfsS --max-time 5 https://127.0.0.1:8443/login -o /dev/null; then
  tui_msg "Installation health check failed. Backup: $backup_path\n\nRun: sudo tunnelmod-diagnose"
  bash ./diagnose.sh || true
  exit 1
fi

tui_info "Step 7/7: Installation completed successfully."
if [[ -n "$DOMAIN" ]]; then
  panel_url="https://${DOMAIN}:8443"
else
  panel_url="https://YOUR_SERVER_IP:8443"
fi

if (( USE_TUI )); then
  whiptail --title "TunnelMod installed" --msgbox "TunnelMod installation finished successfully.\n\nPanel URL:\n${panel_url}\n\nBackup:\n${backup_path}\n\nUpdates:\n- sudo tunnelmod-update\n- or use System and Update inside the panel" 18 76
else
  echo
  echo "TunnelMod installation finished."
  echo "Panel URL: ${panel_url}"
  echo "Backup: ${backup_path}"
  echo "Updates: sudo tunnelmod-update or use System and Update inside the panel."
fi
