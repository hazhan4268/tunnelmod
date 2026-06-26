#!/usr/bin/env bash
set -uo pipefail

if [[ $EUID -ne 0 ]]; then
  exec sudo "$0" "$@"
fi

failures=0
redact() {
  sed -E 's/([0-9]{1,3}\.){3}[0-9]{1,3}/[REDACTED_IP]/g; s/([0-9a-fA-F]{0,4}:){2,}[0-9a-fA-F:]+/[REDACTED_IPV6]/g'
}
pass() { printf '[OK] %s\n' "$1"; }
fail() { printf '[FAIL] %s\n' "$1"; failures=$((failures + 1)); }
check_service() {
  if systemctl is-active --quiet "$1"; then pass "service $1 is active"; else fail "service $1 is not active"; fi
}

echo 'TunnelMod diagnostics (addresses are redacted)'
echo '------------------------------------------------'

[[ -x /opt/tunnel-panel/venv/bin/gunicorn ]] && pass 'Gunicorn executable exists' || fail 'Gunicorn executable is missing'
[[ -r /etc/tunnel-panel/panel.env ]] && pass 'panel.env is readable by root' || fail 'panel.env is missing'
[[ -s /etc/tunnel-panel/panel.crt && -s /etc/tunnel-panel/panel.key ]] && pass 'TLS certificate files exist' || fail 'TLS certificate files are missing'

check_service tunnel-panel
check_service nginx

if nginx -t >/tmp/tunnelmod-nginx-test 2>&1; then
  pass 'Nginx configuration is valid'
else
  fail 'Nginx configuration is invalid'
  redact </tmp/tunnelmod-nginx-test
fi
rm -f /tmp/tunnelmod-nginx-test

if command -v curl >/dev/null; then
  if curl -fsS --max-time 5 http://127.0.0.1:9080/login -o /dev/null; then
    pass 'Gunicorn responds on the local backend'
  else
    fail 'Gunicorn does not respond on port 9080'
  fi
  if curl -kfsS --max-time 5 https://127.0.0.1:8443/login -o /dev/null; then
    pass 'Nginx HTTPS endpoint responds locally'
  else
    fail 'Nginx does not respond on HTTPS port 8443'
  fi
else
  fail 'curl is not installed; local HTTP checks were skipped'
fi

echo
echo 'Listening ports:'
ss -lntp '( sport = :8443 or sport = :9080 )' 2>&1 | redact

if (( failures > 0 )); then
  echo
  echo 'Recent panel logs:'
  journalctl -u tunnel-panel -n 80 --no-pager 2>&1 | redact
  echo
  echo "Diagnostics found ${failures} problem(s). Copy this redacted output when requesting support."
  exit 1
fi

echo
echo 'All local checks passed.'
echo 'If the panel is still unreachable, allow TCP/8443 in the provider firewall or security group and use https://, not http://.'

