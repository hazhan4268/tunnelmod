import os
import sqlite3
import subprocess
from datetime import timedelta
from flask import Flask, flash, redirect, render_template, request, session, url_for
from werkzeug.security import check_password_hash, generate_password_hash
from .db import close_db, get_db, init_db, set_setting, transaction
from .engine import apply_tunnel, maybe_remove_server_wg, remove_tunnel
from .remote import enroll_server, test_server
from .security import (check_csrf, csrf_token, login_required, valid_ip,
                       valid_name, valid_port)


def run_helper(app, *args, timeout=45):
    cmd = ["sudo", app.config["HELPER"], *args]
    proc = subprocess.run(cmd, text=True, capture_output=True, timeout=timeout)
    if proc.returncode != 0:
        raise RuntimeError((proc.stderr or proc.stdout or "helper failed").strip()[:1200])
    return proc.stdout.strip()


def parse_kv(text):
    data = {}
    for line in text.splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            data[key.strip()] = value.strip()
    return data


def installed_version():
    for path in ("/opt/tunnel-panel/VERSION", "/etc/tunnel-panel/VERSION"):
        try:
            with open(path, encoding="utf-8") as file:
                return file.read().strip()
        except OSError:
            pass
    return "unknown"


def create_app():
    app = Flask(__name__)
    app.config.update(
        SECRET_KEY=os.environ.get("PANEL_SECRET", "change-me"),
        DATABASE=os.environ.get("PANEL_DB", "/var/lib/tunnel-panel/panel.db"),
        SSH_KEY=os.environ.get("PANEL_SSH_KEY", "/var/lib/tunnel-panel/id_ed25519"),
        HELPER=os.environ.get("PANEL_HELPER", "/usr/local/sbin/tunnel-panel-helper"),
        PUBLIC_IP=os.environ.get("PANEL_PUBLIC_IP", "127.0.0.1"),
        PANEL_DOMAIN=os.environ.get("PANEL_DOMAIN", ""),
        HAPROXY_RENDER=os.environ.get("PANEL_HAPROXY_RENDER", "/var/lib/tunnel-panel/haproxy.cfg"),
        SESSION_COOKIE_SECURE=True,
        SESSION_COOKIE_HTTPONLY=True,
        SESSION_COOKIE_SAMESITE="Strict",
        PERMANENT_SESSION_LIFETIME=timedelta(hours=8),
        MAX_CONTENT_LENGTH=64 * 1024,
    )
    app.config["RESERVED_PORTS"] = {
        int(port) for port in os.environ.get("PANEL_RESERVED_PORTS", "8443,22").split(",")
        if port.strip().isdigit()
    }
    os.makedirs(os.path.dirname(app.config["DATABASE"]), exist_ok=True)
    init_db(app.config["DATABASE"])
    app.teardown_appcontext(close_db)
    app.jinja_env.globals["csrf_token"] = csrf_token

    @app.after_request
    def headers(response):
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["Referrer-Policy"] = "no-referrer"
        response.headers["Content-Security-Policy"] = "default-src 'self'; style-src 'self'; script-src 'self'"
        return response

    @app.route("/login", methods=["GET", "POST"])
    def login():
        if request.method == "POST":
            check_csrf()
            row = get_db().execute("SELECT value FROM settings WHERE key='admin_password'").fetchone()
            if row and check_password_hash(row["value"], request.form.get("password", "")):
                session.clear()
                session["authenticated"] = True
                session.permanent = True
                return redirect(url_for("dashboard"))
            flash("رمز عبور نادرست است", "error")
        return render_template("login.html")

    @app.post("/logout")
    @login_required
    def logout():
        check_csrf()
        session.clear()
        return redirect(url_for("login"))

    @app.route("/")
    @login_required
    def dashboard():
        db = get_db()
        stats = {
            "servers": db.execute("SELECT COUNT(*) n FROM servers").fetchone()["n"],
            "online": db.execute("SELECT COUNT(*) n FROM servers WHERE status='online'").fetchone()["n"],
            "tunnels": db.execute("SELECT COUNT(*) n FROM tunnels WHERE enabled=1").fetchone()["n"],
            "errors": db.execute("SELECT COUNT(*) n FROM tunnels WHERE status='error'").fetchone()["n"],
        }
        tunnels = db.execute(
            "SELECT t.*,s.name server_name,s.host FROM tunnels t JOIN servers s ON s.id=t.server_id ORDER BY t.id DESC LIMIT 10"
        ).fetchall()
        system = {
            "version": installed_version(),
            "public_ip": app.config["PUBLIC_IP"],
            "domain": app.config["PANEL_DOMAIN"] or "تنظیم نشده",
        }
        return render_template("dashboard.html", stats=stats, tunnels=tunnels, system=system)

    @app.route("/system")
    @login_required
    def system():
        update_info = None
        if request.args.get("check") == "1":
            try:
                update_info = parse_kv(run_helper(app, "update-check", timeout=60))
                flash("بررسی بروزرسانی انجام شد", "success")
            except Exception as exc:
                flash(f"بررسی بروزرسانی ناموفق بود: {exc}", "error")
        system_info = {
            "version": installed_version(),
            "public_ip": app.config["PUBLIC_IP"],
            "domain": app.config["PANEL_DOMAIN"] or "تنظیم نشده",
            "reserved_ports": ", ".join(str(p) for p in sorted(app.config["RESERVED_PORTS"])),
        }
        return render_template("system.html", system=system_info, update=update_info)

    @app.post("/system/update")
    @login_required
    def system_update():
        check_csrf()
        confirm = request.form.get("confirm") == "UPDATE"
        if not confirm:
            flash("برای اجرای بروزرسانی عبارت UPDATE را وارد کنید", "error")
            return redirect(url_for("system", check=1))
        try:
            output = run_helper(app, "update-apply", timeout=900)
            flash("بروزرسانی انجام شد. سرویس پنل سالم است.", "success")
            if output:
                flash(output[-900:], "success")
        except Exception as exc:
            flash(f"بروزرسانی ناموفق بود و در صورت امکان Rollback شده است: {exc}", "error")
        return redirect(url_for("system", check=1))

    @app.route("/servers", methods=["GET", "POST"])
    @login_required
    def servers():
        db = get_db()
        if request.method == "POST":
            check_csrf()
            try:
                name = valid_name(request.form.get("name"))
                host = valid_ip(request.form.get("host"), ipv4_only=True)
                port = valid_port(request.form.get("ssh_port", 22), "پورت SSH")
                user = request.form.get("ssh_user", "root").strip()
                if user != "root":
                    raise ValueError("نسخه فعلی برای راه‌اندازی خودکار به کاربر root نیاز دارد")
                password = request.form.get("password", "")
                if not password:
                    raise ValueError("رمز موقت root الزامی است")
                public_key = open(app.config["SSH_KEY"] + ".pub", encoding="utf-8").read()
                enroll_server(host, port, user, password, public_key, app.config["SSH_KEY"])
                with transaction() as tx:
                    tx.execute("INSERT INTO servers(name,host,ssh_port,ssh_user,status) VALUES(?,?,?,?,?)",
                               (name, host, port, user, "online"))
                flash("سرور اضافه شد؛ رمز آن ذخیره نشد و اتصال کلیدی فعال است", "success")
                return redirect(url_for("servers"))
            except (ValueError, RuntimeError, sqlite3.IntegrityError, OSError) as exc:
                flash(str(exc), "error")
        rows = db.execute("SELECT * FROM servers ORDER BY id DESC").fetchall()
        return render_template("servers.html", servers=rows)

    @app.post("/servers/<int:server_id>/test")
    @login_required
    def server_test(server_id):
        check_csrf()
        db = get_db()
        server = db.execute("SELECT * FROM servers WHERE id=?", (server_id,)).fetchone()
        if not server:
            return ("not found", 404)
        try:
            test_server(server, app.config["SSH_KEY"])
            db.execute("UPDATE servers SET status='online',last_error=NULL WHERE id=?", (server_id,))
            flash("اتصال سرور سالم است", "success")
        except Exception as exc:
            db.execute("UPDATE servers SET status='offline',last_error=? WHERE id=?", (str(exc)[:500], server_id))
            flash(f"اتصال ناموفق: {exc}", "error")
        db.commit()
        return redirect(url_for("servers"))

    @app.post("/servers/<int:server_id>/delete")
    @login_required
    def server_delete(server_id):
        check_csrf()
        db = get_db()
        count = db.execute("SELECT COUNT(*) n FROM tunnels WHERE server_id=?", (server_id,)).fetchone()["n"]
        if count:
            flash("ابتدا تونل‌های متصل به این سرور را حذف کنید", "error")
        else:
            db.execute("DELETE FROM servers WHERE id=?", (server_id,))
            db.commit()
            flash("سرور حذف شد", "success")
        return redirect(url_for("servers"))

    @app.route("/tunnels", methods=["GET", "POST"])
    @login_required
    def tunnels():
        db = get_db()
        if request.method == "POST":
            check_csrf()
            tunnel_id = None
            try:
                name = valid_name(request.form.get("name"))
                server_id = int(request.form.get("server_id"))
                server = db.execute("SELECT * FROM servers WHERE id=?", (server_id,)).fetchone()
                if not server:
                    raise ValueError("سرور مقصد پیدا نشد")
                mode = request.form.get("mode")
                if mode not in {"wg_dnat", "direct_dnat", "wg_haproxy", "direct_haproxy"}:
                    raise ValueError("روش اتصال نامعتبر است")
                protocol = request.form.get("protocol")
                if protocol not in {"tcp", "udp", "both"}:
                    raise ValueError("پروتکل نامعتبر است")
                if mode.endswith("haproxy") and protocol != "tcp":
                    raise ValueError("HAProxy فقط با TCP قابل استفاده است")
                listen = valid_port(request.form.get("listen_port"), "پورت ورودی")
                target = valid_port(request.form.get("target_port"), "پورت مقصد")
                if listen in app.config["RESERVED_PORTS"]:
                    raise ValueError("این پورت برای پنل یا اتصال SSH رزرو شده است")
                conflict = db.execute(
                    "SELECT id FROM tunnels WHERE enabled=1 AND listen_port=? "
                    "AND (protocol=? OR protocol='both' OR ?='both')", (listen, protocol, protocol)
                ).fetchone()
                if conflict:
                    raise ValueError("این پورت و پروتکل قبلاً استفاده شده است")
                cur = db.execute(
                    "INSERT INTO tunnels(name,server_id,mode,protocol,listen_port,target_port,status) VALUES(?,?,?,?,?,?,?)",
                    (name, server_id, mode, protocol, listen, target, "applying")
                )
                tunnel_id = cur.lastrowid
                db.commit()
                tunnel = db.execute("SELECT * FROM tunnels WHERE id=?", (tunnel_id,)).fetchone()
                apply_tunnel(tunnel, server)
                db.execute("UPDATE tunnels SET status='active',last_error=NULL WHERE id=?", (tunnel_id,))
                db.commit()
                flash("تونل با موفقیت فعال شد", "success")
                return redirect(url_for("tunnels"))
            except (ValueError, RuntimeError, sqlite3.IntegrityError, OSError) as exc:
                if tunnel_id:
                    db.execute("UPDATE tunnels SET enabled=0,status='error',last_error=? WHERE id=?", (str(exc)[:500], tunnel_id))
                    db.commit()
                flash(str(exc), "error")
        rows = db.execute(
            "SELECT t.*,s.name server_name,s.host FROM tunnels t JOIN servers s ON s.id=t.server_id ORDER BY t.id DESC"
        ).fetchall()
        servers_list = db.execute("SELECT * FROM servers ORDER BY name").fetchall()
        return render_template("tunnels.html", tunnels=rows, servers=servers_list)

    @app.post("/tunnels/<int:tunnel_id>/delete")
    @login_required
    def tunnel_delete(tunnel_id):
        check_csrf()
        db = get_db()
        tunnel = db.execute("SELECT * FROM tunnels WHERE id=?", (tunnel_id,)).fetchone()
        if not tunnel:
            return ("not found", 404)
        server = db.execute("SELECT * FROM servers WHERE id=?", (tunnel["server_id"],)).fetchone()
        try:
            remove_tunnel(tunnel, server)
            db.execute("DELETE FROM tunnels WHERE id=?", (tunnel_id,))
            db.commit()
            maybe_remove_server_wg(server)
            flash("تونل و قوانین آن حذف شدند", "success")
        except Exception as exc:
            flash(f"حذف کامل نشد: {exc}", "error")
        return redirect(url_for("tunnels"))

    return app


def init_admin():
    app = create_app()
    password = os.environ.get("PANEL_INITIAL_PASSWORD")
    if not password or len(password) < 10:
        raise SystemExit("PANEL_INITIAL_PASSWORD must contain at least 10 characters")
    with app.app_context():
        set_setting("admin_password", generate_password_hash(password, method="scrypt"))


app = create_app()
