#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { echo "با sudo اجرا کنید" >&2; exit 1; }
echo "این عملیات سرویس پنل را حذف می‌کند اما برای جلوگیری از قطع ناگهانی، قوانین فعال iptables را خودکار پاک نمی‌کند."
read -rp "برای ادامه REMOVE را وارد کنید: " answer
[[ "$answer" == REMOVE ]] || exit 0
systemctl disable --now tunnel-panel tunnel-panel-haproxy 2>/dev/null || true
rm -f /etc/systemd/system/tunnel-panel.service /etc/systemd/system/tunnel-panel-haproxy.service
rm -f /etc/nginx/sites-enabled/tunnel-panel /etc/nginx/sites-available/tunnel-panel
rm -f /etc/sudoers.d/tunnel-panel /usr/local/sbin/tunnel-panel-helper
rm -rf /opt/tunnel-panel /etc/tunnel-panel
systemctl daemon-reload
systemctl reload nginx 2>/dev/null || true
echo "برنامه حذف شد. داده‌ها برای بازیابی در /var/lib/tunnel-panel باقی مانده‌اند."

