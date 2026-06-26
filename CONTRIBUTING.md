# Contributing

Contributions are welcome through GitHub issues and pull requests.

1. Fork the repository and create a focused branch.
2. Do not add real IP addresses, credentials, SSH keys, databases, or logs containing secrets.
3. Run the checks below.
4. Explain the operational and security impact in the pull request.

```bash
python3 -m compileall -q tunnel_panel
bash -n install.sh update.sh diagnose.sh uninstall.sh scripts/tunnel-panel-helper
python3 -m unittest discover -s tests -v
```

Security vulnerabilities must be reported privately as described in `SECURITY.md`.
