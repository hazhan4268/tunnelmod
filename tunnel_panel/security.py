import functools
import ipaddress
import re
import secrets
from flask import abort, redirect, request, session, url_for


HOST_RE = re.compile(r"^[A-Za-z0-9.-]{1,253}$")
NAME_RE = re.compile(r"^[\w .-]{1,80}$", re.UNICODE)


def valid_host(value: str) -> str:
    value = (value or "").strip()
    try:
        return str(ipaddress.ip_address(value))
    except ValueError:
        if not HOST_RE.fullmatch(value) or ".." in value:
            raise ValueError("آدرس سرور نامعتبر است")
        return value.lower()


def valid_ip(value: str, *, ipv4_only=False) -> str:
    try:
        parsed = ipaddress.ip_address((value or "").strip())
        if ipv4_only and parsed.version != 4:
            raise ValueError
        return str(parsed)
    except ValueError as exc:
        raise ValueError("IP نامعتبر است") from exc


def valid_port(value, label="پورت") -> int:
    try:
        port = int(value)
    except (TypeError, ValueError) as exc:
        raise ValueError(f"{label} نامعتبر است") from exc
    if not 1 <= port <= 65535:
        raise ValueError(f"{label} باید بین ۱ تا ۶۵۵۳۵ باشد")
    return port


def valid_name(value: str) -> str:
    value = (value or "").strip()
    if not NAME_RE.fullmatch(value):
        raise ValueError("نام باید حداکثر ۸۰ کاراکتر و بدون علائم خاص باشد")
    return value


def login_required(view):
    @functools.wraps(view)
    def wrapped(*args, **kwargs):
        if not session.get("authenticated"):
            return redirect(url_for("login", next=request.path))
        return view(*args, **kwargs)
    return wrapped


def csrf_token() -> str:
    if "csrf" not in session:
        session["csrf"] = secrets.token_urlsafe(32)
    return session["csrf"]


def check_csrf() -> None:
    supplied = request.form.get("csrf_token") or request.headers.get("X-CSRF-Token")
    expected = session.get("csrf", "")
    if supplied and expected and secrets.compare_digest(supplied, expected):
        return

    # Login is protected by the admin password itself. This fallback prevents stale
    # browser cookies from breaking the first login after switching the panel from
    # HTTPS/self-signed mode to plain HTTP mode. All authenticated panel actions
    # still require a strict CSRF match.
    if request.endpoint == "login" and not session.get("authenticated"):
        session.pop("csrf", None)
        return

    abort(400, "CSRF validation failed")
