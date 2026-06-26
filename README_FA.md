<div align="left">

**زبان:** [English](README.md) · فارسی

</div>

<div align="center">

# TunnelMod

### مدیریت امن و چندسروره تونل در Ubuntu

مدیریت WireGuard، ‏DNAT و HAProxy از طریق یک پنل تحت وب ساده و مستقل

[![نسخه](https://img.shields.io/badge/version-0.1.2--beta-f59e0b?style=flat-square)](CHANGELOG.md)
[![تست‌ها](https://img.shields.io/github/actions/workflow/status/hazhan4268/tunnelmod/ci.yml?branch=main&style=flat-square&label=tests)](https://github.com/hazhan4268/tunnelmod/actions/workflows/ci.yml)
[![اوبونتو](https://img.shields.io/badge/Ubuntu-20.04%20%7C%2022.04%20%7C%2024.04-E95420?style=flat-square&logo=ubuntu&logoColor=white)](#پیشنیازها)
[![مجوز](https://img.shields.io/badge/license-MIT-22c55e?style=flat-square)](LICENSE)

[نصب سریع](#نصب-سریع) · [SSL دامنه](#ssl-دامنه) · [به‌روزرسانی](#بهروزرسانی) · [امنیت](SECURITY.md)

</div>

> [!WARNING]
> TunnelMod نسخه آزمایشی است. پیش از استفاده در محیط حساس، ابتدا آن را روی یک VPS آزمایشی بررسی کنید.

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
- ابزار SSL دامنه با Let's Encrypt

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

ابتدا رکورد `A` دامنه را به IP سرور وصل کنید و پورت‌های `80/TCP` و `8443/TCP` را در فایروال ارائه‌دهنده باز کنید. سپس:

```bash
sudo tunnelmod-domain panel.example.com admin@example.com
```

آدرس پنل با دامنه:

```text
https://panel.example.com:8443
```

اگر صدور گواهی موفق نشد، DNS و فایروال را اصلاح کنید و دوباره همین دستور را اجرا کنید.

## روش‌های تونل

| روش | رمزنگاری بین سرورها | پروتکل | کاربرد پیشنهادی |
|---|---:|---|---|
| **WireGuard + DNAT** | دارد | TCP / UDP | انتخاب پیش‌فرض برای انتقال خصوصی و کم‌سربار |
| **WireGuard + HAProxy** | دارد | TCP | پروکسی TCP رمزنگاری‌شده همراه با Health Check |
| **DNAT مستقیم** | ندارد | TCP / UDP | کمترین سربار در شبکه‌ای که از قبل قابل‌اعتماد است |
| **HAProxy مستقیم** | ندارد | TCP | پروکسی TCP بدون نیاز به رمزنگاری مسیر |

## مدیریت و عیب‌یابی

```bash
sudo tunnelmod-diagnose
```

خروجی این ابزار، IPv4 و IPv6 را خودکار مخفی می‌کند و برای ارسال به پشتیبانی مناسب است.

## به‌روزرسانی

```bash
sudo tunnelmod-update
```

این فرمان نسخه پشتیبان خصوصی می‌سازد، تنظیمات، دیتابیس، گواهی‌ها و کلیدهای SSH را حفظ می‌کند و در صورت خطا نسخه قبلی را خودکار برمی‌گرداند.

اگر پنل را قبل از اضافه‌شدن این فرمان نصب کرده‌اید:

```bash
cd tunnelmod
git pull --ff-only
sudo bash update.sh
```

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
