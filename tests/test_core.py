import os
import sqlite3
import tempfile
import unittest

from tunnel_panel.db import init_db
from tunnel_panel.security import valid_ip, valid_name, valid_port


class ValidationTests(unittest.TestCase):
    def test_ipv4(self):
        self.assertEqual(valid_ip("203.0.113.10", ipv4_only=True), "203.0.113.10")
        with self.assertRaises(ValueError):
            valid_ip("not-an-ip", ipv4_only=True)
        with self.assertRaises(ValueError):
            valid_ip("2001:db8::1", ipv4_only=True)

    def test_ports(self):
        self.assertEqual(valid_port("443"), 443)
        for value in ("0", "65536", "invalid"):
            with self.assertRaises(ValueError):
                valid_port(value)

    def test_names(self):
        self.assertEqual(valid_name("Primary relay"), "Primary relay")
        with self.assertRaises(ValueError):
            valid_name("x" * 81)


class DatabaseTests(unittest.TestCase):
    def test_schema_creation(self):
        with tempfile.TemporaryDirectory() as directory:
            path = os.path.join(directory, "panel.db")
            init_db(path)
            db = sqlite3.connect(path)
            tables = {row[0] for row in db.execute(
                "SELECT name FROM sqlite_master WHERE type='table'"
            )}
            self.assertTrue({"settings", "servers", "tunnels"}.issubset(tables))


if __name__ == "__main__":
    unittest.main()

