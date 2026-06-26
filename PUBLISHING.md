# Publishing TunnelMod

Repository: `https://github.com/hazhan4268/tunnelmod`

## First push

Run these commands from the project directory. They do not overwrite an existing remote history.

```bash
git init
git branch -M main
git remote add origin https://github.com/hazhan4268/tunnelmod.git
git add .
git commit -m "Public beta: TunnelMod 0.1.1"
git push -u origin main
```

If GitHub rejects the push because the repository already contains commits, clone the repository first and copy the project files into that clone. Do not force-push unless you intentionally want to replace its history.

## Release

After CI passes:

```bash
git tag -a v0.1.1-beta -m "TunnelMod 0.1.1 beta"
git push origin v0.1.1-beta
```

Create a GitHub Release from this tag and mark it as a **pre-release**. Include the beta warning and a link to `SECURITY.md`.

## Repository settings

- Enable private vulnerability reporting under Security settings.
- Protect the `main` branch and require the CI workflow.
- Enable Dependabot security updates.
- Never upload `/etc/tunnel-panel`, `/var/lib/tunnel-panel`, databases, private keys, passwords, or real server backups.
