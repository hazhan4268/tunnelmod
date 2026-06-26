import sqlite3
from contextlib import contextmanager
from flask import current_app, g


SCHEMA = """
CREATE TABLE IF NOT EXISTS settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS servers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    host TEXT NOT NULL UNIQUE,
    ssh_port INTEGER NOT NULL DEFAULT 22,
    ssh_user TEXT NOT NULL DEFAULT 'root',
    status TEXT NOT NULL DEFAULT 'unknown',
    last_error TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS tunnels (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    server_id INTEGER NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    mode TEXT NOT NULL CHECK(mode IN ('wg_dnat','direct_dnat','wg_haproxy','direct_haproxy')),
    protocol TEXT NOT NULL CHECK(protocol IN ('tcp','udp','both')),
    listen_port INTEGER NOT NULL,
    target_port INTEGER NOT NULL,
    enabled INTEGER NOT NULL DEFAULT 1,
    status TEXT NOT NULL DEFAULT 'pending',
    last_error TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE UNIQUE INDEX IF NOT EXISTS tunnel_port_proto
ON tunnels(listen_port, protocol) WHERE enabled = 1;
"""


def get_db():
    if "db" not in g:
        g.db = sqlite3.connect(current_app.config["DATABASE"])
        g.db.row_factory = sqlite3.Row
        g.db.execute("PRAGMA foreign_keys=ON")
    return g.db


def close_db(_error=None):
    db = g.pop("db", None)
    if db is not None:
        db.close()


def init_db(path: str):
    db = sqlite3.connect(path)
    db.executescript(SCHEMA)
    db.close()


@contextmanager
def transaction():
    db = get_db()
    try:
        yield db
        db.commit()
    except Exception:
        db.rollback()
        raise


def get_setting(key, default=None):
    row = get_db().execute("SELECT value FROM settings WHERE key=?", (key,)).fetchone()
    return row["value"] if row else default


def set_setting(key, value):
    get_db().execute(
        "INSERT INTO settings(key,value) VALUES(?,?) "
        "ON CONFLICT(key) DO UPDATE SET value=excluded.value", (key, str(value))
    )
    get_db().commit()

