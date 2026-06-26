<div align="center">

# 🚇 TunnelMod

**Ubuntu tunnel panel for WireGuard, DNAT and HAProxy**

![Version](https://img.shields.io/badge/version-1.2.6-22c55e?style=flat-square)
![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04+-E95420?style=flat-square&logo=ubuntu&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-2563eb?style=flat-square)

[فارسی](README_FA.md)

</div>

---

## ⚡ One-command install

```bash
curl -fsSL https://raw.githubusercontent.com/hazhan4268/tunnelmod/main/install-online.sh -o /tmp/tunnelmod-install && sudo bash /tmp/tunnelmod-install
```

Default panel mode is HTTP on port `8443`. No domain, SSL, IP certificate, or self-signed certificate is required.

| Need | Port |
|---|---:|
| Panel | `8443/TCP` |

---

## 🌐 Panel URL

```text
http://YOUR_SERVER_IP:8443
```

---

## 🔄 Update

Panel:

```text
System and Update
```

Terminal:

```bash
sudo tunnelmod-update
```

---

## 🛠 Repair

```bash
curl -fsSL https://raw.githubusercontent.com/hazhan4268/tunnelmod/main/repair-install.sh -o /tmp/tunnelmod-repair && sudo bash /tmp/tunnelmod-repair
```

---

## 🔍 Diagnose

```bash
sudo tunnelmod-diagnose
```

---

## 🔐 Security

Do not publish `/etc/tunnel-panel`, `/var/lib/tunnel-panel`, private keys, databases, passwords, or real server backups.

## License

MIT
