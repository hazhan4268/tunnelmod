import os
import shlex
import socket
import subprocess
import tempfile
import paramiko


class RemoteError(RuntimeError):
    pass


def _client(host, port, user, *, password=None, key_path=None, known_hosts=None,
            trust_new=False, timeout=12):
    client = paramiko.SSHClient()
    if known_hosts and os.path.exists(known_hosts):
        client.load_host_keys(known_hosts)
    client.set_missing_host_key_policy(
        paramiko.AutoAddPolicy() if trust_new else paramiko.RejectPolicy()
    )
    kwargs = dict(hostname=host, port=port, username=user, timeout=timeout,
                  banner_timeout=timeout, auth_timeout=timeout,
                  allow_agent=False, look_for_keys=False)
    if password is not None:
        kwargs["password"] = password
    else:
        kwargs["key_filename"] = key_path
    client.connect(**kwargs)
    if trust_new and known_hosts:
        client.save_host_keys(known_hosts)
    return client


def run(client, command, timeout=180):
    _stdin, stdout, stderr = client.exec_command(command, timeout=timeout)
    code = stdout.channel.recv_exit_status()
    out = stdout.read().decode("utf-8", "replace").strip()
    err = stderr.read().decode("utf-8", "replace").strip()
    if code:
        raise RemoteError(err or out or f"remote command failed ({code})")
    return out


def enroll_server(host, port, user, password, public_key, private_key):
    """Use the password once, install our public key, then verify key auth."""
    try:
        known_hosts = private_key + ".known_hosts"
        with _client(host, port, user, password=password, key_path=private_key,
                     known_hosts=known_hosts, trust_new=True) as client:
            quoted = shlex.quote(public_key.strip())
            command = (
                "umask 077; mkdir -p ~/.ssh; touch ~/.ssh/authorized_keys; "
                f"grep -qxF {quoted} ~/.ssh/authorized_keys || echo {quoted} >> ~/.ssh/authorized_keys; "
                "chmod 700 ~/.ssh; chmod 600 ~/.ssh/authorized_keys"
            )
            run(client, command)
        with _client(host, port, user, key_path=private_key,
                     known_hosts=known_hosts) as client:
            return run(client, "printf ready") == "ready"
    except (paramiko.SSHException, OSError, socket.error) as exc:
        raise RemoteError(f"اتصال SSH برقرار نشد: {exc}") from exc


def test_server(server, key_path):
    try:
        with _client(server["host"], server["ssh_port"], server["ssh_user"],
                     key_path=key_path, known_hosts=key_path + ".known_hosts") as client:
            return run(client, "printf online") == "online"
    except Exception as exc:
        raise RemoteError(str(exc)) from exc


def _wg_keypair():
    private = subprocess.check_output(["wg", "genkey"], text=True).strip()
    public = subprocess.check_output(["wg", "pubkey"], input=private + "\n", text=True).strip()
    return private, public


def ensure_wireguard(server, key_path, iface, local_public_ip, local_addr,
                     remote_addr, wg_port, helper):
    """Create a point-to-point WireGuard interface on both hosts."""
    local_private, local_public = _wg_keypair()
    try:
        with _client(server["host"], server["ssh_port"], server["ssh_user"],
                     key_path=key_path, known_hosts=key_path + ".known_hosts") as client:
            run(client, "export DEBIAN_FRONTEND=noninteractive; command -v wg >/dev/null || (apt-get update && apt-get install -y wireguard iptables iptables-persistent)", 600)
            remote_private, remote_public = _wg_keypair()
            remote_conf = f"""[Interface]
Address = {remote_addr}/30
ListenPort = {wg_port}
PrivateKey = {remote_private}

[Peer]
PublicKey = {local_public}
AllowedIPs = {local_addr}/32
PersistentKeepalive = 25
"""
            sftp = client.open_sftp()
            remote_tmp = f"/tmp/{iface}.conf"
            with sftp.file(remote_tmp, "w") as handle:
                handle.write(remote_conf)
            sftp.chmod(remote_tmp, 0o600)
            sftp.close()
            run(client, f"install -m 600 {shlex.quote(remote_tmp)} /etc/wireguard/{shlex.quote(iface)}.conf && rm -f {shlex.quote(remote_tmp)}")
            run(client, f"systemctl enable wg-quick@{shlex.quote(iface)} >/dev/null; systemctl restart wg-quick@{shlex.quote(iface)}")
            run(client, f"iptables -C INPUT -p udp -s {shlex.quote(local_public_ip)} --dport {wg_port} -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp -s {shlex.quote(local_public_ip)} --dport {wg_port} -j ACCEPT")
            run(client, "command -v netfilter-persistent >/dev/null && netfilter-persistent save >/dev/null || true")

        local_conf = f"""[Interface]
Address = {local_addr}/30
PrivateKey = {local_private}

[Peer]
PublicKey = {remote_public}
Endpoint = {server['host']}:{wg_port}
AllowedIPs = {remote_addr}/32
PersistentKeepalive = 25
"""
        fd, path = tempfile.mkstemp(prefix=f"{iface}-", suffix=".conf")
        with os.fdopen(fd, "w") as handle:
            handle.write(local_conf)
        os.chmod(path, 0o600)
        try:
            subprocess.run(["sudo", helper, "wg-up", iface, path], check=True)
        finally:
            try:
                os.unlink(path)
            except FileNotFoundError:
                pass
        return remote_addr
    except Exception:
        raise


def remove_remote_wireguard(server, key_path, iface):
    try:
        with _client(server["host"], server["ssh_port"], server["ssh_user"],
                     key_path=key_path, known_hosts=key_path + ".known_hosts") as client:
            run(client, f"systemctl disable --now wg-quick@{shlex.quote(iface)} 2>/dev/null || true; rm -f /etc/wireguard/{shlex.quote(iface)}.conf")
    except Exception:
        pass
