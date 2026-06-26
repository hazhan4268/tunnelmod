<div align="center">

# 🚇 TunnelMod

**پنل تونل Ubuntu برای WireGuard، DNAT و HAProxy**

![نسخه](https://img.shields.io/badge/version-1.2.6-22c55e?style=flat-square)
![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04+-E95420?style=flat-square&logo=ubuntu&logoColor=white)
![مجوز](https://img.shields.io/badge/license-MIT-2563eb?style=flat-square)

[English](README.md)

</div>

---

## ⚡ نصب فقط با یک دستور

```bash
curl -fsSL https://raw.githubusercontent.com/hazhan4268/tunnelmod/main/install-online.sh -o /tmp/tunnelmod-install && sudo bash /tmp/tunnelmod-install
```

حالت پیش‌فرض پنل HTTP روی پورت `8443` است. برای نصب، دامنه، SSL، گواهی IP یا گواهی خودامضا لازم نیست.

| نیاز | پورت |
|---|---:|
| پنل | `8443/TCP` |

---

## 🌐 آدرس پنل

```text
http://IP-SERVER:8443
```

---

## 🔄 به‌روزرسانی

از داخل پنل:

```text
سیستم و بروزرسانی
```

از ترمینال:

```bash
sudo tunnelmod-update
```

---

## 🛠 تعمیر نصب ناقص

```bash
curl -fsSL https://raw.githubusercontent.com/hazhan4268/tunnelmod/main/repair-install.sh -o /tmp/tunnelmod-repair && sudo bash /tmp/tunnelmod-repair
```

---

## 🔍 عیب‌یابی

```bash
sudo tunnelmod-diagnose
```

---

## 🔐 امنیت

مسیرهای `/etc/tunnel-panel` و `/var/lib/tunnel-panel`، کلیدهای خصوصی، دیتابیس، رمزها و بکاپ واقعی سرورها را منتشر نکنید.

## مجوز

MIT
