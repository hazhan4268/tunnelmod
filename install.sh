#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $EUID -ne 0 ]]; then echo "این نصب‌کننده باید با sudo اجرا شود." >&2; exit 1; fi
source /etc/os-release
if [[ "${ID:-}" != ubuntu ]]; then echo "فقط Ubuntu پشتیبانی می‌شود." >&2; exit 1; fi
major="${VERSION_ID%%.*}"
if (( major < 20 )); then echo "Ubuntu 20.04 یا جدیدتر لازم است." >&2; exit 1; fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DETECTED_IP="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')"
if [[ -n "${PANEL_PUBLIC_IP:-}" ]]; then DETECTED_IP="$PANEL_PUBLIC_IP"; fi
if [[ -n "$DETECTED_IP" ]]; then
  read -rp "IP عمومی این سرور [${DETECTED_IP}]: " PUBLIC_IP
  PUBLIC_IP="${PUBLIC_IP:-$DETECTED_IP}"
else
  read -rp "IP عمومی این سرور: " PUBLIC_IP
fi
[[ "$PUBLIC_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || { echo "IPv4 نامعتبر" >&2; exit 1; }
python3 -c 'import ipaddress,sys; ipaddress.IPv4Address(sys.argv[1])' "$PUBLIC_IP" || { echo "IPv4 نامعتبر" >&2; exit 1; }
SSH_PORT="$(awk '{print $4}' <<<"${SSH_CONNECTION:-}" 2>/dev/null || true)"
[[ "$SSH_PORT" =~ ^[0-9]+$ ]] || SSH_PORT=22
read -rsp "رمز مدیر پنل (حداقل 10 کاراکتر): " ADMIN_PASSWORD; echo
[[ ${#ADMIN_PASSWORD} -ge 10 ]] || { echo "رمز کوتاه است." >&2; exit 1; }
read -rsp "تکرار رمز: " ADMIN_PASSWORD_2; echo
[[ "$ADMIN_PASSWORD" == "$ADMIN_PASSWORD_2" ]] || { echo "رمزها برابر نیستند." >&2; exit 1; }

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y python3 python3-venv python3-pip nginx haproxy wireguard iptables iptables-persistent openssl sudo curl

id tunnelpanel >/dev/null 2>&1 || useradd --system --home /var/lib/tunnel-panel --shell /usr/sbin/nologin tunnelpanel
install -d -o tunnelpanel -g tunnelpanel -m 750 /var/lib/tunnel-panel
install -d -o root -g tunnelpanel -m 750 /etc/tunnel-panel
rm -rf /opt/tunnel-panel
install -d -o root -g root -m 755 /opt/tunnel-panel
cp -a "$SCRIPT_DIR/tunnel_panel" "$SCRIPT_DIR/requirements.txt" /opt/tunnel-panel/
python3 -m venv /opt/tunnel-panel/venv
/opt/tunnel-panel/venv/bin/pip install --no-cache-dir -r /opt/tunnel-panel/requirements.txt

if [[ ! -f /var/lib/tunnel-panel/id_ed25519 ]]; then
  sudo -u tunnelpanel ssh-keygen -q -t ed25519 -N '' -f /var/lib/tunnel-panel/id_ed25519
fi
PANEL_SECRET="$(openssl rand -hex 32)"
cat > /etc/tunnel-panel/panel.env <<EOF
PANEL_SECRET=${PANEL_SECRET}
PANEL_DB=/var/lib/tunnel-panel/panel.db
PANEL_SSH_KEY=/var/lib/tunnel-panel/id_ed25519
PANEL_HELPER=/usr/local/sbin/tunnel-panel-helper
PANEL_PUBLIC_IP=${PUBLIC_IP}
PANEL_HAPROXY_RENDER=/var/lib/tunnel-panel/haproxy.cfg
PANEL_RESERVED_PORTS=8443,${SSH_PORT}
EOF
chown root:tunnelpanel /etc/tunnel-panel/panel.env
chmod 640 /etc/tunnel-panel/panel.env

install -o root -g root -m 750 "$SCRIPT_DIR/scripts/tunnel-panel-helper" /usr/local/sbin/tunnel-panel-helper
cat > /etc/sudoers.d/tunnel-panel <<'EOF'
tunnelpanel ALL=(root) NOPASSWD: /usr/local/sbin/tunnel-panel-helper *
EOF
chmod 440 /etc/sudoers.d/tunnel-panel
visudo -cf /etc/sudoers.d/tunnel-panel >/dev/null

install -o root -g root -m 644 "$SCRIPT_DIR/scripts/tunnel-panel.service" /etc/systemd/system/tunnel-panel.service
install -o root -g root -m 644 "$SCRIPT_DIR/scripts/tunnel-panel-haproxy.service" /etc/systemd/system/tunnel-panel-haproxy.service
install -o root -g root -m 644 "$SCRIPT_DIR/scripts/nginx.conf.template" /etc/nginx/sites-available/tunnel-panel
ln -sf /etc/nginx/sites-available/tunnel-panel /etc/nginx/sites-enabled/tunnel-panel

openssl req -x509 -newkey rsa:3072 -sha256 -days 825 -nodes \
  -keyout /etc/tunnel-panel/panel.key -out /etc/tunnel-panel/panel.crt \
  -subj "/CN=${PUBLIC_IP}" -addext "subjectAltName=IP:${PUBLIC_IP}"
chmod 600 /etc/tunnel-panel/panel.key

cat > /etc/sysctl.d/99-tunnel-panel.conf <<'EOF'
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
EOF
sysctl --system >/dev/null

set -a; source /etc/tunnel-panel/panel.env; set +a
cd /opt/tunnel-panel
PANEL_INITIAL_PASSWORD="$ADMIN_PASSWORD" /opt/tunnel-panel/venv/bin/python -c 'from tunnel_panel.app import init_admin; init_admin()'
chown -R tunnelpanel:tunnelpanel /var/lib/tunnel-panel
unset ADMIN_PASSWORD ADMIN_PASSWORD_2 PANEL_INITIAL_PASSWORD

if ! nginx -t; then
  echo "خطا در تنظیمات Nginx" >&2
  bash "$SCRIPT_DIR/diagnose.sh" || true
  exit 1
fi
systemctl daemon-reload
if ! systemctl enable --now tunnel-panel nginx; then
  echo "خطا در اجرای سرویس‌های پنل" >&2
  bash "$SCRIPT_DIR/diagnose.sh" || true
  exit 1
fi
if command -v ufw >/dev/null && ufw status | grep -q '^Status: active'; then
  ufw allow 8443/tcp >/dev/null
fi

healthy=0
for _attempt in {1..10}; do
  if curl -kfsS --max-time 3 https://127.0.0.1:8443/login -o /dev/null; then
    healthy=1
    break
  fi
  sleep 1
done
if [[ $healthy -ne 1 ]]; then
  echo "خطا: پنل پس از نصب پاسخ نداد. خروجی عیب‌یابی:" >&2
  bash "$SCRIPT_DIR/diagnose.sh" || true
  exit 1
fi

echo
echo "نصب کامل شد: https://${PUBLIC_IP}:8443"
echo "هشدار گواهی Self-Signed در اولین ورود طبیعی است. اثر انگشت گواهی:"
openssl x509 -in /etc/tunnel-panel/panel.crt -noout -fingerprint -sha256
