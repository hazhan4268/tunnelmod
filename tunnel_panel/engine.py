import ipaddress
import os
import subprocess
from flask import current_app
from .db import get_db, get_setting, set_setting
from .remote import ensure_wireguard, remove_remote_wireguard


def _run_helper(*args):
    command = ["sudo", current_app.config["HELPER"], *map(str, args)]
    result = subprocess.run(command, text=True, capture_output=True, timeout=60)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip() or "helper failed")


def _wg_addresses(server_id):
    # Stable /30 from 10.77.0.0/16; supports 16K servers.
    if server_id < 1 or server_id > 16383:
        raise ValueError("شناسه سرور خارج از محدوده WireGuard است")
    net = ipaddress.ip_network("10.77.0.0/16")
    base = int(net.network_address) + server_id * 4
    return str(ipaddress.ip_address(base + 1)), str(ipaddress.ip_address(base + 2))


def ensure_server_wg(server):
    iface = f"tp{server['id']}"
    local_addr, remote_addr = _wg_addresses(server["id"])
    setting_key = f"wg_ready_{server['id']}"
    if get_setting(setting_key) == "1":
        probe = subprocess.run(["wg", "show", iface], capture_output=True)
        if probe.returncode == 0:
            return iface, remote_addr
        set_setting(setting_key, "0")
    wg_port = 51820 + (server["id"] % 1000)
    ensure_wireguard(
        server, current_app.config["SSH_KEY"], iface,
        current_app.config["PUBLIC_IP"], local_addr, remote_addr, wg_port,
        current_app.config["HELPER"]
    )
    set_setting(setting_key, "1")
    return iface, remote_addr


def _protocols(value):
    return ("tcp", "udp") if value == "both" else (value,)


def apply_tunnel(tunnel, server):
    mode = tunnel["mode"]
    destination = server["host"]
    iface = "-"
    if mode.startswith("wg_"):
        iface, destination = ensure_server_wg(server)

    if mode.endswith("dnat"):
        for proto in _protocols(tunnel["protocol"]):
            _run_helper("forward-add", tunnel["id"], current_app.config["PUBLIC_IP"],
                        proto, tunnel["listen_port"], destination,
                        tunnel["target_port"], iface)
    else:
        if tunnel["protocol"] != "tcp":
            raise ValueError("HAProxy فقط TCP را پشتیبانی می‌کند")
        render_haproxy()


def remove_tunnel(tunnel, server):
    destination = server["host"]
    iface = "-"
    if tunnel["mode"].startswith("wg_"):
        iface = f"tp{server['id']}"
        destination = _wg_addresses(server["id"])[1]
    if tunnel["mode"].endswith("dnat"):
        for proto in _protocols(tunnel["protocol"]):
            _run_helper("forward-del", tunnel["id"], current_app.config["PUBLIC_IP"],
                        proto, tunnel["listen_port"], destination,
                        tunnel["target_port"], iface)
    else:
        render_haproxy(exclude=tunnel["id"])


def render_haproxy(exclude=None):
    rows = get_db().execute(
        "SELECT t.*,s.host,s.id server_id FROM tunnels t JOIN servers s ON s.id=t.server_id "
        "WHERE t.enabled=1 AND t.mode IN ('wg_haproxy','direct_haproxy')"
    ).fetchall()
    lines = [
        "global", "    log stdout format raw local0", "    maxconn 10000", "",
        "defaults", "    mode tcp", "    log global", "    timeout connect 8s",
        "    timeout client  60s", "    timeout server  60s", ""
    ]
    count = 0
    for row in rows:
        if row["id"] == exclude:
            continue
        destination = row["host"]
        if row["mode"] == "wg_haproxy":
            server = get_db().execute("SELECT * FROM servers WHERE id=?", (row["server_id"],)).fetchone()
            _iface, destination = ensure_server_wg(server)
        lines += [
            f"frontend tp_front_{row['id']}",
            f"    bind *:{row['listen_port']}",
            f"    default_backend tp_back_{row['id']}", "",
            f"backend tp_back_{row['id']}",
            f"    server target {destination}:{row['target_port']} check", ""
        ]
        count += 1
    path = current_app.config["HAPROXY_RENDER"]
    with open(path, "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines))
    os.chmod(path, 0o640)
    _run_helper("haproxy-apply" if count else "haproxy-stop", path)


def maybe_remove_server_wg(server):
    count = get_db().execute(
        "SELECT COUNT(*) n FROM tunnels WHERE server_id=? AND enabled=1 AND mode LIKE 'wg_%'",
        (server["id"],)
    ).fetchone()["n"]
    if count:
        return
    iface = f"tp{server['id']}"
    _run_helper("wg-down", iface)
    remove_remote_wireguard(server, current_app.config["SSH_KEY"], iface)
    set_setting(f"wg_ready_{server['id']}", "0")
