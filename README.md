<div align="center">

# 🚇 TunnelMod

**Ubuntu tunnel panel for WireGuard, DNAT and HAProxy**  
**پنل تونل Ubuntu برای WireGuard، DNAT و HAProxy**

![Version](https://img.shields.io/badge/version-1.2.6-22c55e?style=flat-square)
![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04+-E95420?style=flat-square&logo=ubuntu&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-2563eb?style=flat-square)

</div>

---

## ⚡ Install / نصب

```bash
curl -fsSL https://raw.githubusercontent.com/hazhan4268/tunnelmod/main/install-online.sh -o /tmp/tunnelmod-install && sudo bash /tmp/tunnelmod-install
```

Default panel mode is HTTP on port `8443`. No domain, SSL, IP certificate, or self-signed certificate is required.

حالت پیش‌فرض پنل HTTP روی پورت `8443` است. برای نصب، دامنه، SSL، گواهی IP یا گواهی خودامضا لازم نیست.

| Need / نیاز | Port / پورت |
|---|---:|
| Panel / پنل | `8443/TCP` |

---

## 🌐 Panel URL / آدرس پنل

```text
http://YOUR_SERVER_IP:8443
```

---

## 🔄 Update / به‌روزرسانی

Panel / داخل پنل:

```text
System and Update / سیستم و بروزرسانی
```

Terminal / ترمینال:

```bash
sudo tunnelmod-update
```

---

## 🛠 Repair / تعمیر نصب ناقص

```bash
curl -fsSL https://raw.githubusercontent.com/hazhan4268/tunnelmod/main/repair-install.sh -o /tmp/tunnelmod-repair && sudo bash /tmp/tunnelmod-repair
```

---

## 🔍 Diagnose / عیب‌یابی

```bash
sudo tunnelmod-diagnose
```

---

## 🧾 Recent changes / تغییرات اخیر

- Default panel mode is HTTP on `8443`.
- No SSL, domain, IP certificate, or self-signed certificate is required for the default installation.
- Old SSL Nginx template and outdated install guide were removed.
- Nginx renderer supports `PANEL_TLS_MODE=off`.
- Update and repair checks use the correct panel scheme.

---

## 🔐 Security / امنیت

Do not publish `/etc/tunnel-panel`, `/var/lib/tunnel-panel`, private keys, databases, passwords, or real server backups.

مسیرهای `/etc/tunnel-panel` و `/var/lib/tunnel-panel`، کلیدهای خصوصی، دیتابیس، رمزها و بکاپ واقعی سرورها را منتشر نکنید.

## License / مجوز

MIT
