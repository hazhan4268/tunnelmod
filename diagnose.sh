#!/usr/bin/env bash
set -uo pipefail

if [[ $EUID -ne 0 ]]; then
  exec sudo bash "$0" "$@"
fi

failures=0
TLS_MODE="off"
if [[ -r /etc/tunnel-panel/panel.env ]]; then
  TLS_MODE="$(grep '^PANEL_TLS_MODE=' /etc/tunnel-panel/panel.env | tail -1 | cut -d= -f2- || true)"
  TLS_MODE="${TLS_MODE:-off}"
fi
SCHEME="http"
[[ "$TLS_MODE" != "off" ]] && SCHEME="https"

redact() {
  sed -E 's/([0-9]{1,3}\.){3}[0-9]{1,3}/[REDACTED_IP]/g; s/([0-9a-fA-F]{0,4}:){2,}[0-9a-fA-F:]+/[REDACTED_IPV6]/g'
}
pass() { printf '[OK] %s\n' "$1"; }
fail() { printf '[FAIL] %s\n' "$1"; failures=$((failures + 1)); }
check_service() { systemctl is-active --quiet "$1" && pass "service $1 is active" || fail "service $1 is not active"; }

echo 'TunnelMod diagnostics (addresses are redacted)'
echo '------------------------------------------------'
echo "Panel TLS mode: ${TLS_MODE}"

[[ -x /opt/tunnel-panel/venv/bin/gunicorn ]] && pass 'Gunicorn executable exists' || fail 'Gunicorn executable is missing'
[[ -r /etc/tunnel-panel/panel.env ]] && pass 'panel.env is readable by root' || fail 'panel.env is missing'
if [[ "$TLS_MODE" == "off" ]]; then
  pass 'TLS certificates are not required in HTTP mode'
else
  [[ -s /etc/tunnel-panel/panel.crt && -s /etc/tunnel-panel/panel.key ]] && pass 'TLS certificate files exist' || fail 'TLS certificate files are missing'
fi

check_service tunnel-panel
check_service nginx

if nginx -t >/tmp/tunnelmod-nginx-test 2>&1; then
  pass 'Nginx configuration is valid'
else
  fail 'Nginx configuration is invalid'
  redact </tmp/tunnelmod-nginx-test
fi
rm -f /tmp/tunnelmod-nginx-test

nginx -T >/tmp/tunnelmod-nginx-dump 2>/tmp/tunnelmod-nginx-dump.err
if grep -Eq 'listen[[:space:]]+(\[::\]:)?8443([[:space:]]+ssl)?' /tmp/tunnelmod-nginx-dump; then
  pass 'Nginx loaded TunnelMod 8443 listener config'
else
  fail 'Nginx did not load any TunnelMod 8443 listener config'
  grep -n 'tunnel-panel' /tmp/tunnelmod-nginx-dump 2>/dev/null | redact || true
fi
rm -f /tmp/tunnelmod-nginx-dump /tmp/tunnelmod-nginx-dump.err

if command -v curl >/dev/null; then
  curl -fsS --max-time 5 http://127.0.0.1:9080/login -o /dev/null && pass 'Gunicorn responds on the local backend' || fail 'Gunicorn does not respond on port 9080'
  curl -kfsS --max-time 5 "${SCHEME}://127.0.0.1:8443/login" -o /dev/null && pass "Nginx endpoint responds locally on 8443" || fail "Nginx does not respond on port 8443"
else
  fail 'curl is not installed; local checks were skipped'
fi

echo
echo 'Listening ports:'
ss -lntp '( sport = :8443 or sport = :9080 )' 2>&1 | redact

if (( failures > 0 )); then
  echo
  echo 'Nginx service status:'
  systemctl status nginx --no-pager -l 2>&1 | redact | tail -40
  echo
  echo 'Recent Nginx logs:'
  journalctl -u nginx -n 60 --no-pager 2>&1 | redact
  echo
  echo 'Recent panel logs:'
  journalctl -u tunnel-panel -n 80 --no-pager 2>&1 | redact
  echo
  echo "Diagnostics found ${failures} problem(s)."
  exit 1
fi

echo
echo 'All local checks passed.'
echo "Panel URL should be: ${SCHEME}://SERVER_IP:8443"
