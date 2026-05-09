# Doxo

A simple CLI to create and manage dockerized apps on your own server, using [Haloy](https://haloy.dev/) for routing and [Tailscale](https://tailscale.com/) for secure access.

> **Status:** WIP

---

## How it works

Doxo scaffolds Docker apps with the right labels so [haloyd](https://haloy.dev/docs/architecture) auto-discovers and routes traffic to them. Tailscale handles TLS — no certificate management needed.

```
Public (internet):
  Internet → Tailscale Funnel (443) → haloyd proxy (80) → container

Private (tailnet only):
  Tailnet → Tailscale Serve (443) → haloyd proxy (80) → container
```

haloyd provides host-based routing, zero-downtime deploys, health checks, and rollbacks. Doxo provides the scaffolding CLI so you don't have to write compose files or labels by hand.

---

## Requirements

- **Server** — any modern Linux server (tested on Raspberry Pi OS)
- **Docker** + Docker Compose plugin
- **[haloyd](https://haloy.dev/docs/server-installation)** — running as a systemd service
- **[Tailscale](https://tailscale.com/)** — installed, authenticated, MagicDNS enabled
- **[gum](https://github.com/charmbracelet/gum)** — installed automatically by the install script
- **A personal domain** — for public-facing apps (CNAME to your Tailscale Funnel address)
- **`jq`** (optional but recommended) — for reliable Tailscale hostname detection

---

## Install

SSH into your server and run:

```bash
curl -fsSL https://raw.githubusercontent.com/woodcox/doxo/main/install-cli.sh | bash
```

This will:
- Install [gum](https://github.com/charmbracelet/gum) if not present
- Clone the doxo repo to `~/doxo`
- Symlink `doxo` into `~/.local/bin`
- Check for Docker, haloyd, and Tailscale and report their status

> haloyd and Tailscale are **not** installed by this script — install them separately before running `doxo expose`.

### Install haloyd

```bash
curl -fsSL https://sh.haloy.dev/install-haloyd.sh | API_DOMAIN=<your-tailscale-hostname> sh
```

See [haloy.dev/docs/server-installation](https://haloy.dev/docs/server-installation) for full instructions.

### Install Tailscale

```bash
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up
```

Enable **MagicDNS** and **HTTPS Certificates** in your [Tailscale admin console](https://login.tailscale.com/admin/dns).

---

## Architecture

```
Internet / Tailnet
        ↓
Tailscale Funnel (public) or Serve (private)
        ↓
haloyd reverse proxy  ←  discovers containers via Docker labels
        ↓
Docker containers
┌───────────────┬───────────────┬───────────────┐
│    app1       │    app2       │    app3       │
│   :8080       │   :8081       │   :3000       │
└───────────────┴───────────────┴───────────────┘
```

Doxo manages apps under a consistent directory structure:

```
~/docker/
├── app1/
│   ├── docker-compose.yml   # includes haloyd labels
│   ├── .meta                # app metadata (image, port, domain, mode)
│   └── data/
└── app2/
    ├── docker-compose.yml
    ├── .meta
    └── data/
```

---

## Commands

### create

Scaffold and start a new app.

```bash
doxo create
doxo create <app-name>
doxo create <app-name> --port <port> --image <image>
```

Prompts for app name, image type, and port. Available image types:

| Option | Image | Internal port |
|--------|-------|---------------|
| 1 | `denoland/deno:latest` | 8000 |
| 2 | `nginx:alpine` | 80 |
| 3 | custom | prompted |

- **Deno** — scaffolds `main.ts` with a `/health` endpoint
- **nginx** — scaffolds `data/index.html`, mounts as static site
- **custom** — prompts for container port

The generated `docker-compose.yml` includes haloyd discovery labels. haloyd will begin routing once a domain is set via `doxo expose`.

### expose

Expose an app publicly or privately via Tailscale.

```bash
doxo expose <app-name> --public
doxo expose <app-name> --private
```

| Flag | How it works | URL format |
|------|-------------|------------|
| `--public` | Tailscale Funnel + your custom domain | `https://myapp.yourdomain.com` |
| `--private` | Tailscale Serve on your tailnet | `https://device.ts.net/myapp` |

`--public` prompts for your custom domain. Point it to your Tailscale Funnel address as a CNAME.

### unexpose

Remove the Tailscale Funnel or Serve route for an app without deleting it.

```bash
doxo unexpose <app-name>
doxo unexpose <app-name> --force   # skip confirmation
```

### delete

Stop and remove an app, its containers, and its Tailscale route.

```bash
doxo delete <app-name>
```

### list

List all apps and their current status.

```bash
doxo list
```

```
╭──────────────────┬────────────┬──────┬────────────────────────┬────────────┬─────────┬─────────────────────────────────╮
│ APP              │ STATUS     │ PORT │ IMAGE                  │ UPTIME     │ MODE    │ DOMAIN                          │
├──────────────────┼────────────┼──────┼────────────────────────┼────────────┼─────────┼─────────────────────────────────┤
│ myapp            │ 🟢 running │ 8080 │ denoland/deno:latest   │ 2h         │ public  │ myapp.yourdomain.com            │
│ api              │ 🟢 running │ 8081 │ denoland/deno:latest   │ 5h         │ private │ raspberrypi.ts.net/api          │
│ site             │ 🔴 stopped │ 80   │ nginx:alpine           │ -          │ none    │ -                               │
╰──────────────────┴────────────┴──────┴────────────────────────┴────────────┴─────────┴─────────────────────────────────╯
```

### open

Open an app in the browser.

```bash
doxo open <app-name>
```

Resolves the correct URL from `.meta` — `https://` for exposed apps, `http://localhost:PORT` for unexposed.

### doctor

Check all dependencies and configuration.

```bash
doxo doctor
```

Checks Docker, haloyd, Tailscale, jq, and the doxo CLI symlink.

### uninstall

```bash
doxo uninstall
```

Removes the doxo symlink. Optionally removes the `haloy` Docker network and Docker itself.
To remove doxo source files entirely: `rm -rf ~/doxo`.
App data in `~/docker/` is never touched.

---

## The .meta file

Each app stores metadata in `~/docker/<app>/.meta`:

```bash
IMAGE=denoland/deno:latest
CONTAINER_PORT=8000
PORT=8080
DOMAIN=myapp.yourdomain.com
MODE=public                        # public | private | none
CREATED_AT=2024-01-01T00:00:00Z
```

Used by `expose`, `unexpose`, `delete`, `list`, and `open` — no compose file parsing needed.

---

## Runtime operations

Doxo handles scaffolding and exposure. Use the `haloy` CLI for runtime operations:

```bash
haloy status              # show running apps and health
haloy logs <app>          # stream app logs
haloy rollback <app>      # roll back to previous deploy
```

---

## Project structure

```
doxo/
├── bin/
│   └── doxo             # entry point
├── cmd/
│   ├── create.sh
│   ├── delete.sh
│   ├── expose.sh
│   ├── unexpose.sh
│   ├── list.sh
│   ├── open.sh
│   ├── doctor.sh
│   ├── help.sh
│   ├── install.sh
│   └── uninstall.sh
├── lib/
│   └── common.sh        # shared helpers
├── install-cli.sh       # bootstrap (curl | bash entry point)
└── install.sh           # full installer (called by doxo install)
```

---

## Create a release

```bash
echo "0.3.0" > VERSION
git commit -m "release 0.3.0"
git tag v0.3.0
git push origin main --tags
```