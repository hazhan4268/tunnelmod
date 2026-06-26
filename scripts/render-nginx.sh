#!/usr/bin/env bash
set -Eeuo pipefail

ENV_FILE="${1:-/etc/tunnel-panel/panel.env}"
OUT="/etc/nginx/conf.d/tunnel-panel.conf"
ACME_ROOT="/var/www/tunnel-panel-acme"

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

install -d -o root -g root -m 755 /etc/nginx/conf.d
rm -f /etc/nginx/sites-enabled/tunnel-panel
cat >"$OUT" <<EOF
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

nginx -t
