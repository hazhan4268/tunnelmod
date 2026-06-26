<div align="left">

**زبان:** [English](README.md) · فارسی

</div>

<div align="center">

# TunnelMod

### مدیریت امن و چندسروره تونل در Ubuntu

مدیریت WireGuard، ‏DNAT و HAProxy از طریق یک پنل تحت وب ساده و مستقل

[![نسخه](https://img.shields.io/badge/version-1.0.0-22c55e?style=flat-square)](CHANGELOG.md)
[![تست‌ها](https://img.shields.io/github/actions/workflow/status/hazhan4268/tunnelmod/ci.yml?branch=main&style=flat-square&label=tests)](https://github.com/hazhan4268/tunnelmod/actions/workflows/ci.yml)
[![اوبونتو](https://img.shields.io/badge/Ubuntu-20.04%20%7C%2022.04%20%7C%2024.04-E95420?style=flat-square&logo=ubuntu&logoColor=white)](#پیشنیازها)
[![مجوز](https://img.shields.io/badge/license-MIT-22c55e?style=flat-square)](LICENSE)

[نصب سریع](#نصب-سریع) · [SSL دامنه](#ssl-دامنه) · [به‌روزرسانی](#بهروزرسانی) · [امنیت](SECURITY.md)

</div>

> [!NOTE]
> TunnelMod 1.0.0 نسخه Stable است؛ همچنان پیش از استفاده در محیط حساس، روی VPS آزمایشی بررسی شود.

## معرفی

TunnelMod یک سرور Ubuntu را به نقطه ورودی مرکزی برای انتقال ترافیک TCP و UDP به چندین سرور مقصد تبدیل می‌کند. پنل، روش ارتباطی انتخاب‌شده را راه‌اندازی می‌کند، قوانین شبکه را پایدار می‌کند و مدیریت روزمره را از طریق یک رابط فارسی و واکنش‌گرا در اختیار مدیر قرار می‌دهد.

## قابلیت‌ها

- افزودن و مدیریت چندین سرور مقصد بدون محدودیت ثابت در رابط کاربری
- WireGuard + DNAT برای انتقال رمزنگاری‌شده TCP و UDP
- WireGuard + HAProxy برای پروکسی TCP همراه با Health Check
- DNAT مستقیم و HAProxy مستقیم برای سناریوهای کم‌سربار
- عدم ذخیره رمز SSH سرورهای مقصد
- پنل مدیریتی HTTPS روی پورت `8443`
- کانفیگ پایدار Nginx در مسیر استاندارد `/etc/nginx/conf.d/tunnel-panel.conf`
- دستور به‌روزرسانی امن با Backup و Rollback
- بررسی و اجرای بروزرسانی از داخل پنل
- فعال‌سازی SSL دامنه در همان نصب اولیه

## پیش‌نیازها

- Ubuntu نسخه `20.04`،‏ `22.04` یا `24.04`
- کاربر دارای دسترسی کامل `sudo`
- IPv4 عمومی
- باز بودن پورت `8443/TCP`
- برای SSL دامنه: رکورد DNS دامنه به IP سرور و باز بودن پورت `80/TCP`

## نصب سریع

روش پیشنهادی:

```bash
wget -qO install-online.sh https://raw.githubusercontent.com/hazhan4268/tunnelmod/main/install-online.sh
sudo bash install-online.sh
```

در ابتدای نصب، دامنه پنل برای SSL پرسیده می‌شود. اگر خالی بگذارید، نصب با گواهی خودامضا انجام می‌شود و بعداً می‌توانید SSL دامنه را فعال کنید.

روش کلاسیک:

```bash
git clone https://github.com/hazhan4268/tunnelmod.git && cd tunnelmod
sudo bash install.sh
```

پس از نصب:

```text
https://IP-SERVER:8443
```

## SSL دامنه

در نصب آنلاین، SSL دامنه همان ابتدا قابل فعال‌سازی است. برای فعال‌سازی یا تغییر دامنه بعد از نصب:

```bash
sudo tunnelmod-domain panel.example.com admin@example.com
```

آدرس پنل با دامنه:

```text
https://panel.example.com:8443
```

## به‌روزرسانی

از داخل پنل: وارد بخش **سیستم و بروزرسانی** شوید، ابتدا «بررسی وجود آپدیت» را بزنید و در صورت وجود نسخه جدید، عبارت `UPDATE` را برای اجرا وارد کنید.

از خط فرمان:

```bash
sudo tunnelmod-update
```

این فرمان نسخه پشتیبان خصوصی می‌سازد، تنظیمات، دیتابیس، گواهی‌ها و کلیدهای SSH را حفظ می‌کند و در صورت خطا نسخه قبلی را خودکار برمی‌گرداند.

## مدیریت و عیب‌یابی

```bash
sudo tunnelmod-diagnose
```

خروجی این ابزار، IPv4 و IPv6 را خودکار مخفی می‌کند و برای ارسال به پشتیبانی مناسب است.

## حذف پنل

```bash
sudo bash uninstall.sh
```

## امنیت

از TunnelMod فقط روی سرورها و شبکه‌هایی استفاده کنید که اجازه مدیریت آن‌ها را دارید. دیتابیس پنل، کلیدهای خصوصی، رمزها، مسیرهای `/etc/tunnel-panel` و `/var/lib/tunnel-panel` یا نسخه پشتیبان واقعی سرورها را در GitHub قرار ندهید.

IP عمومی و IP مقصدی که هنگام نصب یا کار با پنل وارد می‌شوند فقط روی همان سرور نصب‌شده ذخیره خواهند شد و وارد مخزن GitHub نمی‌شوند.

## مستندات

- [English README](README.md)
- [راهنمای نصب HTML](docs/install-fa.html)
- [سیاست امنیتی](SECURITY.md)
- [راهنمای مشارکت](CONTRIBUTING.md)
- [تاریخچه تغییرات](CHANGELOG.md)

## مجوز

TunnelMod تحت [مجوز MIT](LICENSE) منتشر شده است.
