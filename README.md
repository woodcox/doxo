# Doxo
WIP
A simple CLI that combines Docker and Caddy to create and manage consistent dockerized apps.

---

## Structure

Doxo manages apps under a consistent directory structure:

~~~
~/docker/
├── caddy/
│   ├── docker-compose.yml
│   ├── Caddyfile
│   ├── sites/
│   │   └── app1.caddy
│   ├── data/     # auto-created by Caddy, do not edit
│   └── config/   # auto-created by Caddy, do not edit
├── app1/
│   ├── docker-compose.yml
│   ├── .meta
│   └── data/
└── app2/
    ├── docker-compose.yml
    ├── .meta
    └── data/
~~~

Each app gets its own directory with a `docker-compose.yml`, a `.meta` file, and a `data/` directory. Caddy route snippets are stored in `~/docker/caddy/sites/`.

---

## Requirements

- Docker
- Docker Compose
- Caddy running as a Docker container on the `caddy` network
  → See [docs/caddy-setup.md](docs/caddy-setup.md)

---

## Install

Clone the repo and run the install script:

~~~bash
curl -fsSL https://raw.githubusercontent.com/woodcox/doxo/main/install.sh | bash
~~~

---

## Uninstall

~~~bash
curl -fsSL https://raw.githubusercontent.com/woodcox/doxo/main/uninstall.sh | bash
~~~

This removes the symlink only. To remove the doxo files entirely run `rm -rf ~/doxo`.

---

## Commands

### `doxo create`
Scaffold and start a new app.

~~~bash
doxo create
doxo create <app-name>
doxo create <app-name> <port>
~~~

Prompts for app name, external port, and image type. Available image types:

| Option | Image | Internal port |
|--------|-------|---------------|
| 1 | `caddy:alpine` | 80 |
| 2 | `denoland/deno:latest` | 8000 |
| 3 | custom | prompted |

- **Caddy static** — mounts `data/` to `/srv`, scaffolds `data/index.html`, generates a `file_server` Caddy snippet
- **Deno server** — mounts `.` to `/app`, scaffolds `main.ts` with a `/health` endpoint, generates a `reverse_proxy` Caddy snippet

---

### `doxo delete`
Stop and remove an app and its Caddy route.

~~~bash
doxo delete <app-name>
~~~

Stops containers, removes the app directory, removes the Caddy snippet, and reloads Caddy.

---

### `doxo expose`
Add or update a Caddy route for an existing app.

~~~bash
doxo expose <app-name>
doxo expose <app-name> <domain>
~~~

Reads app config from `.meta` — no compose file parsing needed.

---

### `doxo unexpose`
Remove the Caddy route for an app without deleting the app.

~~~bash
doxo unexpose <app-name>
doxo unexpose <app-name> --force
~~~

---

### `doxo restart`
Restart an app's container.

~~~bash
doxo restart <app-name>
doxo restart <app-name> --recreate
~~~

`--recreate` does a full `down`/`up` cycle to pick up any changes to `docker-compose.yml`.

---

### `doxo list`
List all apps and their current status.

~~~bash
doxo list
~~~

~~~
APP                   STATUS     PORT       IMAGE                  UPTIME     DOMAIN
--------------------  ---------- ---------- ---------------------- ---------- ------------------------------
app1                🟢 running   8080       caddy:alpine           2 hours    app1.local
app2                🔴 stopped   8081       denoland/deno:latest   -          app2.local
~~~

---

## The .meta file

Each app stores metadata in `~/docker/<app>/.meta`:

~~~bash
IMAGE=caddy:alpine
INTERNAL_PORT=80
PORT=8080
DOMAIN=app1.local
CREATED_AT=2024-01-01T00:00:00Z
~~~

This is used by `expose`, `unexpose`, `restart`, `delete`, and `list` so no compose file parsing is ever needed.

---

## Local DNS

To access apps via their `.local` domain, add entries to `/etc/hosts`:

~~~
127.0.0.1  app1.local
127.0.0.1  app2.local
~~~

---

## Project structure

~~~
doxo/
├── bin/
│   └── doxo          # entry point
├── cmd/
│   ├── create.sh
│   ├── delete.sh
│   ├── expose.sh
│   ├── unexpose.sh
│   ├── list.sh
│   ├── restart.sh
│   └── help.sh
├── lib/
│   └── common.sh     # shared helpers
├── install.sh
└── uninstall.sh
~~~

# Create a release
~~~sh
echo "0.2.0" > VERSION
git add VERSION
git commit -m "release 0.2.0"
git tag v0.2.0
git push origin main --tags
~~~