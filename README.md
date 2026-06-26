# TunnelMod

[فارسی](README_FA.md)

TunnelMod is a self-hosted Ubuntu panel for managing multi-server tunnels with WireGuard, DNAT, and HAProxy.

## Requirements

- Ubuntu 20.04 or newer
- Full sudo/root access
- Public IPv4 address
- Open TCP/8443 for the panel
- Open TCP/80 if you want Let's Encrypt SSL

## Install

```bash
wget -qO install-online.sh https://raw.githubusercontent.com/hazhan4268/tunnelmod/main/install-online.sh
sudo bash install-online.sh
```

The installer uses a terminal UI when available. To force plain text mode:

```bash
TUNNELMOD_NO_TUI=1 sudo -E bash install-online.sh
```

Panel URL:

```text
https://YOUR_SERVER_IP:8443
```

## Domain SSL

During installation, enter your panel domain when asked. The installer will request Let's Encrypt SSL in the same flow.

Example domain URL:

```text
https://panel.example.com:8443
```

To change SSL later:

```bash
sudo tunnelmod-domain panel.example.com admin@example.com
```

## Update

From the panel:

```text
System and Update
```

From terminal:

```bash
sudo tunnelmod-update
```

## Repair

For a partial or failed installation:

```bash
wget -qO repair-install.sh https://raw.githubusercontent.com/hazhan4268/tunnelmod/main/repair-install.sh
sudo bash repair-install.sh
```

## Diagnostics

```bash
sudo tunnelmod-diagnose
```

## Security

Do not publish `/etc/tunnel-panel`, `/var/lib/tunnel-panel`, private keys, databases, passwords, or real server backups.

IP addresses entered during installation or in the panel stay on the installed server and are not stored in this repository.

## License

MIT
