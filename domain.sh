#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $EUID -ne 0 ]]; then
  exec sudo bash "$0" "$@"
fi

ENV_FILE="/etc/tunnel-panel/panel.env"
DOMAIN="${1:-${PANEL_DOMAIN:-}}"
EMAIL="${2:-${LETSENCRYPT_EMAIL:-${PANEL_LETSENCRYPT_EMAIL:-}}}"

[[ -r "$ENV_FILE" ]] || { echo "TunnelMod is not installed: $ENV_FILE is missing." >&2; exit 1; }
[[ -n "$DOMAIN" ]] || { echo "Usage: sudo tunnelmod-domain panel.example.com [email@example.com]" >&2; exit 1; }
[[ "$DOMAIN" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$ ]] || {
  echo "Invalid domain name." >&2
  exit 1
}

set_env() {
  local key="$1" value="$2" tmp
  tmp="$(mktemp)"
  grep -v "^${key}=" "$ENV_FILE" >"$tmp" || true
  printf '%s=%s\n' "$key" "$value" >>"$tmp"
  install -o root -g tunnelpanel -m 640 "$tmp" "$ENV_FILE"
  rm -f "$tmp"
}

set_env PANEL_DOMAIN "$DOMAIN"
if [[ -n "$EMAIL" ]]; then
  set_env PANEL_LETSENCRYPT_EMAIL "$EMAIL"
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y certbot curl

/usr/local/sbin/tunnelmod-render-nginx "$ENV_FILE"
systemctl reload nginx || systemctl restart nginx

args=(certonly --webroot -w /var/www/tunnel-panel-acme -d "$DOMAIN" --non-interactive --agree-tos --keep-until-expiring)
if [[ -n "$EMAIL" ]]; then
  args+=(--email "$EMAIL")
else
  args+=(--register-unsafely-without-email)
fi

certbot "${args[@]}"
/usr/local/sbin/tunnelmod-render-nginx "$ENV_FILE"
systemctl reload nginx || systemctl restart nginx
curl -kfsS --max-time 5 https://127.0.0.1:8443/login -o /dev/null

echo "Domain SSL is enabled: https://${DOMAIN}:8443"
echo "Make sure TCP/8443 is open in the provider firewall."
