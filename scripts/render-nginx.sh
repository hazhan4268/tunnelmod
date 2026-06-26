#!/usr/bin/env bash
set -Eeuo pipefail

ENV_FILE="${1:-/etc/tunnel-panel/panel.env}"
ACME_ROOT="/var/www/tunnel-panel-acme"
CONF_D_OUT="/etc/nginx/conf.d/tunnel-panel.conf"
SITES_AVAILABLE="/etc/nginx/sites-available/tunnel-panel"
SITES_ENABLED="/etc/nginx/sites-enabled/tunnel-panel"
DIRECT_INCLUDE="/etc/nginx/tunnel-panel.include.conf"
NGINX_CONF="/etc/nginx/nginx.conf"

if [[ -r "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

PANEL_DOMAIN="${PANEL_DOMAIN:-}"
SSL_CERT="/etc/tunnel-panel/panel.crt"
SSL_KEY="/etc/tunnel-panel/panel.key"
SERVER_NAME="_"
HTTP_BLOCK=""

if [[ -n "$PANEL_DOMAIN" ]]; then
  SERVER_NAME="$PANEL_DOMAIN"
  install -d -o www-data -g www-data -m 755 "$ACME_ROOT"
  if [[ -s "/etc/letsencrypt/live/${PANEL_DOMAIN}/fullchain.pem" && -s "/etc/letsencrypt/live/${PANEL_DOMAIN}/privkey.pem" ]]; then
    SSL_CERT="/etc/letsencrypt/live/${PANEL_DOMAIN}/fullchain.pem"
    SSL_KEY="/etc/letsencrypt/live/${PANEL_DOMAIN}/privkey.pem"
  fi
  HTTP_BLOCK="server {
    listen 80;
    listen [::]:80;
    server_name ${SERVER_NAME};

    location /.well-known/acme-challenge/ {
        root ${ACME_ROOT};
    }

    location / {
        return 301 https://\$host:8443\$request_uri;
    }
}
"
fi

backup_nginx_conf_once() {
  if [[ ! -f "${NGINX_CONF}.tunnelmod.original" ]]; then
    cp -a "$NGINX_CONF" "${NGINX_CONF}.tunnelmod.original"
  fi
}

remove_direct_include_line() {
  if [[ -f "$NGINX_CONF" ]] && grep -qF "include ${DIRECT_INCLUDE};" "$NGINX_CONF"; then
    backup_nginx_conf_once
    grep -vF "include ${DIRECT_INCLUDE};" "$NGINX_CONF" > /tmp/tunnelmod-nginx.conf
    install -o root -g root -m 644 /tmp/tunnelmod-nginx.conf "$NGINX_CONF"
    rm -f /tmp/tunnelmod-nginx.conf
  fi
}

make_config() {
  local out="$1"
  cat >"$out" <<EOF
proxy_headers_hash_max_size 1024;
proxy_headers_hash_bucket_size 128;

${HTTP_BLOCK}
limit_req_zone \$binary_remote_addr zone=panel_login:10m rate=10r/m;
server {
    listen 8443 ssl;
    listen [::]:8443 ssl;
    server_name ${SERVER_NAME};

    ssl_certificate ${SSL_CERT};
    ssl_certificate_key ${SSL_KEY};
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_session_tickets off;
    add_header Strict-Transport-Security "max-age=31536000" always;
    client_max_body_size 64k;

    location = /login {
        limit_req zone=panel_login burst=5 nodelay;
        proxy_pass http://127.0.0.1:9080;
        include proxy_params;
        proxy_set_header X-Forwarded-Proto https;
    }

    location / {
        proxy_pass http://127.0.0.1:9080;
        include proxy_params;
        proxy_set_header X-Forwarded-Proto https;
    }
}
EOF
}

nginx_loads_panel() {
  nginx -T 2>/tmp/tunnelmod-nginx-render.log | grep -Eq 'listen[[:space:]]+(\[::\]:)?8443[[:space:]]+ssl'
}

try_conf_d() {
  rm -f "$CONF_D_OUT" "$SITES_ENABLED" "$SITES_AVAILABLE" "$DIRECT_INCLUDE"
  remove_direct_include_line
  make_config "$CONF_D_OUT"
  nginx -t && nginx_loads_panel
}

try_sites_enabled() {
  rm -f "$CONF_D_OUT" "$SITES_ENABLED" "$SITES_AVAILABLE" "$DIRECT_INCLUDE"
  remove_direct_include_line
  make_config "$SITES_AVAILABLE"
  ln -sf "$SITES_AVAILABLE" "$SITES_ENABLED"
  nginx -t && nginx_loads_panel
}

try_direct_include() {
  rm -f "$CONF_D_OUT" "$SITES_ENABLED" "$SITES_AVAILABLE"
  make_config "$DIRECT_INCLUDE"
  if ! grep -qF "include ${DIRECT_INCLUDE};" "$NGINX_CONF"; then
    backup_nginx_conf_once
    awk -v inc="    include /etc/nginx/tunnel-panel.include.conf;" '
      !done && $0 ~ /^[[:space:]]*http[[:space:]]*\{/ { print; print inc; done=1; next }
      { print }
    ' "$NGINX_CONF" > /tmp/tunnelmod-nginx.conf
    install -o root -g root -m 644 /tmp/tunnelmod-nginx.conf "$NGINX_CONF"
    rm -f /tmp/tunnelmod-nginx.conf
  fi
  nginx -t && nginx_loads_panel
}

install -d -o root -g root -m 755 /etc/nginx/conf.d /etc/nginx/sites-available /etc/nginx/sites-enabled

if try_conf_d; then
  echo "TunnelMod Nginx include mode: conf.d"
  exit 0
fi

if try_sites_enabled; then
  echo "TunnelMod Nginx include mode: sites-enabled"
  exit 0
fi

if try_direct_include; then
  echo "TunnelMod Nginx include mode: direct nginx.conf include"
  exit 0
fi

echo "TunnelMod Nginx config was generated, but Nginx still does not load listen 8443." >&2
cat /tmp/tunnelmod-nginx-render.log >&2 || true
exit 1
