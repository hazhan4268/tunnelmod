# TunnelMod — پنل مدیریت تونل چندسروره

> نسخه `0.1.0-beta`؛ پیش از استفاده در محیط حساس، ابتدا در یک VPS آزمایشی بررسی شود.

پنل تحت وب برای Ubuntu 20.04، 22.04 و 24.04 که محدودیت نرم‌افزاری در رابط برای تعداد سرورهای خارج ندارد و آن‌ها را با SSH Key مدیریت می‌کند.

## روش‌های ارتباطی

- WireGuard + DNAT: مسیر رمزنگاری‌شده و پیشنهاد پیش‌فرض
- WireGuard + HAProxy: رمزنگاری همراه با Health Check لایه TCP
- DNAT مستقیم: کمترین سربار و بدون رمزنگاری بین دو سرور
- HAProxy مستقیم: پروکسی TCP با بررسی سلامت مقصد

رمز root سرور خارج تنها هنگام ثبت اولیه برای نصب کلید عمومی استفاده می‌شود و در پایگاه داده ذخیره نمی‌شود.

## نصب

مخزن را روی سرور ورودی دریافت و نصب‌کننده را اجرا کنید:

```bash
sudo apt update && sudo apt install -y git
git clone https://github.com/hazhan4268/tunnelmod.git
cd tunnelmod
chmod +x install.sh uninstall.sh scripts/tunnel-panel-helper
sudo ./install.sh
```

نصب‌کننده IP عمومی و رمز مدیر را می‌پرسد. پس از نصب:

```text
https://YOUR_SERVER_IP:8443
```

گواهی اولیه Self-Signed است؛ اثر انگشت نمایش‌داده‌شده در پایان نصب را پیش از پذیرش هشدار مرورگر بررسی کنید. پورت `8443/TCP` باید در فایروال یا Security Group باز باشد.

## نکات عملیاتی

- سرویس مقصد برای روش WireGuard باید روی `0.0.0.0` یا IP خصوصی WireGuard گوش کند.
- پورت 8443 و پورت SSH جاری برای جلوگیری از قطع دسترسی رزرو می‌شوند.
- HAProxy فقط TCP است. برای UDP از WireGuard + DNAT استفاده کنید.
- هر پورت/پروتکل تنها به یک تونل اختصاص می‌یابد.
- حذف سرور تا زمانی که تونل وابسته دارد مجاز نیست.
- نصب‌کننده تنظیمات یا سرویس‌های موجود HAProxy و سایت پیش‌فرض Nginx را متوقف نمی‌کند؛ در صورت استفاده قبلی از همان پورت، ابتدا تداخل را رفع کنید.

## عیب‌یابی

```bash
sudo systemctl status tunnel-panel
sudo journalctl -u tunnel-panel -n 100 --no-pager
sudo wg show
sudo iptables -t nat -L -n -v
sudo systemctl status tunnel-panel-haproxy
```

## پشتیبان‌گیری

```bash
sudo cp -a /var/lib/tunnel-panel /root/tunnel-panel-backup
sudo cp -a /etc/tunnel-panel /root/tunnel-panel-config-backup
```

پوشه `/etc/tunnel-panel` شامل اسرار است و باید با دسترسی محدود نگهداری شود.

## امنیت و استفاده مجاز

این پروژه هنوز ممیزی امنیتی مستقل نشده است. تنها روی سرورها و شبکه‌هایی استفاده کنید که اجازه مدیریت آن‌ها را دارید. آسیب‌پذیری‌های امنیتی را مطابق فایل `SECURITY.md` گزارش کنید.
