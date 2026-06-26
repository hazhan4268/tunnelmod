# Changelog

## 0.1.1-beta — 2026-06-26

- Added transactional `sudo tunnelmod-update` with backup, health check, and rollback
- Added `diagnose.sh` with automatic IPv4/IPv6 redaction
- Added an installation post-flight HTTPS health check
- Documented that operator-provided addresses remain local to the installed server

## 0.1.0-beta — 2026-06-26

- Initial public beta
- Multi-server web panel
- WireGuard + DNAT and WireGuard + HAProxy modes
- Direct DNAT and direct HAProxy modes
- One-time password-based SSH enrollment followed by key authentication
- Ubuntu installer, systemd services, Nginx TLS proxy, and persistent iptables rules
