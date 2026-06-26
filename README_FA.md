# TunnelMod

[English](README.md)

TunnelMod یک پنل نصب‌شونده روی Ubuntu برای مدیریت تونل‌های چندسروره با WireGuard، DNAT و HAProxy است.

## پیش‌نیازها

- Ubuntu 20.04 یا جدیدتر
- دسترسی کامل sudo/root
- IPv4 عمومی
- باز بودن پورت TCP/8443 برای پنل
- باز بودن پورت TCP/80 برای SSL دامنه

## نصب

```bash
wget -qO install-online.sh https://raw.githubusercontent.com/hazhan4268/tunnelmod/main/install-online.sh
sudo bash install-online.sh
```

نصب‌کننده در صورت امکان محیط گرافیکی ترمینال را نشان می‌دهد. برای حالت متنی ساده:

```bash
TUNNELMOD_NO_TUI=1 sudo -E bash install-online.sh
```

آدرس پنل:

```text
https://IP-SERVER:8443
```

## SSL دامنه

در زمان نصب، دامنه پنل را وارد کنید تا SSL دامنه در همان روند نصب فعال شود.

نمونه آدرس با دامنه:

```text
https://panel.example.com:8443
```

برای تغییر SSL بعد از نصب:

```bash
sudo tunnelmod-domain panel.example.com admin@example.com
```

## به‌روزرسانی

از داخل پنل:

```text
سیستم و بروزرسانی
```

از ترمینال:

```bash
sudo tunnelmod-update
```

## تعمیر نصب ناقص

```bash
wget -qO repair-install.sh https://raw.githubusercontent.com/hazhan4268/tunnelmod/main/repair-install.sh
sudo bash repair-install.sh
```

## عیب‌یابی

```bash
sudo tunnelmod-diagnose
```

## امنیت

مسیرهای `/etc/tunnel-panel` و `/var/lib/tunnel-panel`، کلیدهای خصوصی، دیتابیس، رمزها و بکاپ واقعی سرورها را منتشر نکنید.

IPهایی که هنگام نصب یا داخل پنل وارد می‌شوند فقط روی همان سرور نصب‌شده ذخیره می‌شوند و داخل این مخزن قرار نمی‌گیرند.

## مجوز

MIT
