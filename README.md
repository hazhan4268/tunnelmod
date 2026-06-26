<div align="right">

**Language:** English · [فارسی](README_FA.md)

</div>

<div align="center">

# TunnelMod

### Secure, multi-server tunnel management for Ubuntu

Manage WireGuard, DNAT, and HAProxy routes from a clean self-hosted web panel.

[![Version](https://img.shields.io/badge/version-1.0.0-22c55e?style=flat-square)](CHANGELOG.md)
[![CI](https://img.shields.io/github/actions/workflow/status/hazhan4268/tunnelmod/ci.yml?branch=main&style=flat-square&label=tests)](https://github.com/hazhan4268/tunnelmod/actions/workflows/ci.yml)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04%20%7C%2022.04%20%7C%2024.04-E95420?style=flat-square&logo=ubuntu&logoColor=white)](#requirements)
[![License](https://img.shields.io/badge/license-MIT-22c55e?style=flat-square)](LICENSE)

[Quick install](#quick-install) · [Domain SSL](#domain-ssl) · [Updating](#updating) · [Security](SECURITY.md)

</div>

> [!NOTE]
> TunnelMod 1.0.0 is the first stable release. Test it on a disposable VPS before using it in a sensitive environment.

## Overview

TunnelMod turns an Ubuntu server into a centrally managed entry point for forwarding TCP and UDP traffic to multiple destination servers. It provisions the selected transport, applies persistent network rules, and exposes day-to-day operations through a clean web interface.

## Features

- Multiple destination servers without a fixed UI limit
- WireGuard + DNAT for encrypted TCP and UDP forwarding
- WireGuard + HAProxy for encrypted TCP proxying with health checks
- Direct DNAT and direct HAProxy for low-overhead scenarios
- No storage of destination SSH passwords
- HTTPS admin panel on port `8443`
- Robust Nginx config under `/etc/nginx/conf.d/tunnel-panel.conf`
- Transactional updater with backup and rollback
- Update check and update execution from inside the panel
- Domain SSL activation during the initial online installation

## Requirements

- Ubuntu `20.04`, `22.04`, or `24.04`
- A user with full `sudo` access
- Public IPv4 address
- Port `8443/TCP` open
- For domain SSL: DNS A record pointing to the server and port `80/TCP` open

## Quick install

Recommended install:

```bash
wget -qO install-online.sh https://raw.githubusercontent.com/hazhan4268/tunnelmod/main/install-online.sh
sudo bash install-online.sh
```

The online installer asks for an optional panel domain at the beginning. Leave it empty for a self-signed certificate, or enter a domain to request Let's Encrypt during the same installation flow.

Classic install:

```bash
git clone https://github.com/hazhan4268/tunnelmod.git && cd tunnelmod
sudo bash install.sh
```

Open the panel afterward:

```text
https://YOUR_SERVER_IP:8443
```

## Domain SSL

The online installer can enable domain SSL during the initial installation. To enable or change it later:

```bash
sudo tunnelmod-domain panel.example.com admin@example.com
```

Domain URL:

```text
https://panel.example.com:8443
```

## Updating

From the panel, open **System and Update**, check GitHub, type `UPDATE`, and run the safe updater when a new version is available.

From the command line:

```bash
sudo tunnelmod-update
```

The updater creates a private backup, preserves configuration, database, certificates and SSH keys, checks the HTTPS endpoint, and automatically rolls back on failure.

## Operations

```bash
sudo tunnelmod-diagnose
```

The diagnostic output automatically redacts IPv4 and IPv6 addresses.

## Uninstalling

```bash
sudo bash uninstall.sh
```

## Security

Use TunnelMod only on systems and networks you are authorized to administer. Never commit panel databases, private keys, passwords, `/etc/tunnel-panel`, `/var/lib/tunnel-panel`, or real server backups.

Public and destination addresses entered during installation are stored only on the installed server. The repository does not contain or upload them.

## Documentation

- [راهنمای فارسی](README_FA.md)
- [Persian HTML installation guide](docs/install-fa.html)
- [Security policy](SECURITY.md)
- [Contribution guide](CONTRIBUTING.md)
- [Changelog](CHANGELOG.md)

## License

TunnelMod is released under the [MIT License](LICENSE).
