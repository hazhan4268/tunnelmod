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
 Secure multi-server tunnel panel for Ubuntu
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
  local text="Before continuing, make sure:\n\n- Ubuntu 20.04+ is installed\n- You have full sudo/root access\n- TCP/8443 is open for the panel\n- For domain SSL, TCP/80 is open and the A record points to this server\n\nContinue installation?"
  if (( USE_TUI )); then
    whiptail --title "TunnelMod prerequisites" --yesno "$text" 17 76
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

plain_banner
apt-get update
apt-get install -y git ca-certificates curl whiptail
can_tui && USE_TUI=1 || USE_TUI=0

if (( USE_TUI )); then
  whiptail --title "TunnelMod Installer" --msgbox "Welcome to TunnelMod.\n\nThis installer will set up the web panel, Nginx HTTPS listener, update tools, optional domain SSL, and health checks." 14 76
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

tui_info "Step 1/6: Downloading or updating TunnelMod source..."
if [[ -d "$SOURCE_DIR/.git" ]]; then
  git -C "$SOURCE_DIR" fetch --prune origin main
  git -C "$SOURCE_DIR" checkout main
  git -C "$SOURCE_DIR" merge --ff-only origin/main
else
  rm -rf "$SOURCE_DIR"
  git clone "$REPO_URL" "$SOURCE_DIR"
fi

cd "$SOURCE_DIR"

tui_info "Step 2/6: Running base installer. You will be asked for public IP and panel password in the terminal."
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

tui_info "Step 3/6: Installing latest helpers, Nginx renderer, update tools, and Go agent..."
env TUNNELMOD_UPDATE_APPLY=1 TUNNELMOD_SOURCE_DIR="$SOURCE_DIR" bash ./update.sh

if [[ -n "$DOMAIN" ]]; then
  tui_info "Step 4/6: Requesting and installing Let's Encrypt SSL for $DOMAIN..."
  bash ./domain.sh "$DOMAIN" "$EMAIL"
else
  tui_info "Step 4/6: Domain SSL skipped. Self-signed certificate remains active."
fi

tui_info "Step 5/6: Running local HTTPS health check..."
if ! curl -kfsS --max-time 5 https://127.0.0.1:8443/login -o /dev/null; then
  tui_msg "Installation health check failed. Run: sudo tunnelmod-diagnose"
  exit 1
fi

tui_info "Step 6/6: Installation completed successfully."
if [[ -n "$DOMAIN" ]]; then
  panel_url="https://${DOMAIN}:8443"
else
  panel_url="https://YOUR_SERVER_IP:8443"
fi

if (( USE_TUI )); then
  whiptail --title "TunnelMod installed" --msgbox "TunnelMod installation finished successfully.\n\nPanel URL:\n${panel_url}\n\nUpdates:\n- sudo tunnelmod-update\n- or use System and Update inside the panel" 15 76
else
  echo
  echo "TunnelMod installation finished."
  echo "Panel URL: ${panel_url}"
  echo "Updates: sudo tunnelmod-update or use System and Update inside the panel."
fi
