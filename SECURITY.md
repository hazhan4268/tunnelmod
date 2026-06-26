# Security policy

## Supported versions

TunnelMod is currently beta software. Security fixes are applied to the latest release only.

## Reporting a vulnerability

Please do not open a public issue containing exploit details, credentials, server addresses, or private logs. Use GitHub's **Security → Report a vulnerability** feature for this repository.

Include the affected version, Ubuntu version, reproduction steps, expected impact, and a minimal redacted log when available. Never test a vulnerability against systems you do not own or administer with permission.

## Deployment guidance

- Restrict port `8443/TCP` to trusted administrator addresses whenever possible.
- Replace the self-signed certificate with a trusted certificate when a domain is available.
- Use a unique, strong panel password.
- Keep Ubuntu security updates installed.
- Protect `/etc/tunnel-panel` and `/var/lib/tunnel-panel`; they contain sensitive configuration and SSH material.
- Review every release before upgrading a production host.

