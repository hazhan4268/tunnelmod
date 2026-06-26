# Changelog

## 1.2.4 — 2026-06-26

- Added graphical terminal UI to the official online installer using `whiptail`
- Added welcome, prerequisite confirmation, domain SSL form, progress steps, and final success dialog
- Added `TUNNELMOD_NO_TUI=1` fallback for plain terminal or automation use
- Installer still falls back to normal text prompts when TUI is unavailable

## 1.2.2 — 2026-06-26

- Added repair flow for partial installations where Gunicorn is healthy but Nginx has not loaded the 8443 listener
- Online installer now continues after the legacy base installer fails at the final Nginx health check and immediately applies the migration/update stage
- Added `repair-install.sh` for fixing existing half-installed servers
- Tuned Nginx proxy header hash settings to remove proxy header hash warnings

## 1.2.1 — 2026-06-26

- Moved domain SSL into the initial online installation flow
- Added installer-level domain validation and final health check

## 1.2.0 — 2026-06-26

- Added Go-based `tunnelmod-agent` for faster per-tunnel traffic collection
- Helper now prefers the Go agent for traffic counters and falls back to Python automatically
- Added Go module and CI build validation for the agent
- Update workflow now builds and installs the Go agent at `/usr/local/sbin/tunnelmod-agent`
- Added agent installer script with graceful fallback if the build fails

## 1.1.0 — 2026-06-26

- Added per-tunnel inbound and outbound traffic counters
- Added total traffic cards on the dashboard
- Added traffic columns to the tunnel list
- Added safe tunnel editing with remove, apply, health status, and rollback attempt
- Added HAProxy stats socket support for TCP proxy tunnel traffic
- Added responsive table/card layout for mobile and tablet devices
- Added dedicated tunnel edit page

## 1.0.0 — 2026-06-26

- Promoted TunnelMod to stable version 1.0.0
- Added System and Update page inside the web panel
- Added update check and update apply actions through the protected helper
- Improved dashboard with system status, version, domain, and quick actions
- Modernized the panel layout with sidebar navigation and responsive UI
- Installer updater now copies VERSION into the installed application path

## 0.1.3-beta — 2026-06-26

- Online installer now asks for an optional panel domain during the first install
- If a domain is entered, domain SSL is requested in the same install flow
- Persian documentation updated for initial SSL setup

## 0.1.2-beta — 2026-06-26

- Moved generated Nginx panel configuration to `/etc/nginx/conf.d/tunnel-panel.conf`
- Added reusable Nginx renderer for self-signed and domain certificates
- Added domain SSL helper command
- Updated README installation commands

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
