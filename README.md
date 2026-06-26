# TunnelMod

TunnelMod is a self-hosted web panel for managing TCP/UDP forwarding from one Ubuntu entry server to multiple destination servers.

> **Beta software:** version `0.1.0-beta` has not received an independent security audit. Test it on a disposable VPS before production use.

## Features

- Multiple destination servers with no UI-imposed limit
- WireGuard + DNAT (recommended)
- WireGuard + HAProxy
- Direct DNAT and direct HAProxy
- TCP, UDP, or both (HAProxy modes are TCP-only)
- One-time SSH password enrollment; the password is not stored
- HTTPS admin panel on port `8443`
- Ubuntu 20.04, 22.04, and 24.04 targets

## Quick install

Connect to the Ubuntu entry server with a sudo-enabled account:

```bash
sudo apt update && sudo apt install -y git
git clone https://github.com/hazhan4268/tunnelmod.git
cd tunnelmod
chmod +x install.sh uninstall.sh scripts/tunnel-panel-helper
sudo ./install.sh
```

The installer asks for the entry server's public IPv4 address and an admin password. Open the panel afterward:

```text
https://YOUR_SERVER_IP:8443
```

The initial certificate is self-signed. Compare the certificate fingerprint shown by the installer before accepting the browser warning.

## Requirements

- Ubuntu 20.04, 22.04, or 24.04 entry server
- A user with full `sudo` access on the entry server
- Root SSH access to destination servers for automatic WireGuard provisioning
- Port `8443/TCP` allowed by the host and provider firewalls
- The destination service listening on `0.0.0.0` or its WireGuard address when using a WireGuard mode

## Tunnel modes

| Mode | Encryption between servers | Protocol |
|---|---:|---|
| WireGuard + DNAT | Yes | TCP/UDP |
| WireGuard + HAProxy | Yes | TCP |
| Direct DNAT | No | TCP/UDP |
| Direct HAProxy | No | TCP |

The installer reserves the panel port and the SSH port used during installation to reduce accidental lockouts.

## Operations

```bash
sudo systemctl status tunnel-panel
sudo journalctl -u tunnel-panel -n 100 --no-pager
sudo wg show
sudo iptables -t nat -L -n -v
```

Persian documentation: [README_FA.md](README_FA.md)

## Updating

Back up `/var/lib/tunnel-panel` and `/etc/tunnel-panel`, then pull the release. Until a dedicated migration command is available, review the release notes before rerunning the installer.

## Security

Only use TunnelMod on systems and networks you are authorized to administer. Do not commit `/etc/tunnel-panel`, `/var/lib/tunnel-panel`, SSH keys, databases, passwords, or backups. See [SECURITY.md](SECURITY.md) for private vulnerability reporting guidance.

## License

[MIT](LICENSE)

