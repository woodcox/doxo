# Doxo
WIP
A simple CLI that combines Docker and Caddy to create and manage consistent dockerized apps.


## Requirements

 - Server: Any modern Linux server 
 - Domain: A domain or subdomain pointing to your server for secure API access
 - Tailscale (optional) for secure networking
 - Consider installing `jq`this is used to detect the tailnet MagicDNSSuffix more reliably (see cmd/expose.sh)


## Install

SSH into your server and run the install script:

~~~bash
curl -fsSL https://raw.githubusercontent.com/woodcox/doxo/main/install.sh | bash
~~~

This installs:
 - Docker
 - Docker compose
 - Docker image of Caddy
 - Doxo

Doxo assumes Caddy is running as a Docker container on a shared `caddy` network → See [docs/caddy-setup.md](docs/caddy-setup.md)

## Architecture
~~~
Internet / Tailscale / Local
        ↓
Caddy Reverse Proxy
        ↓
Docker containers
┌───────────────┬───────────────┬───────────────┐
│  Caddy        │    app1       │    app2       │
│               │   :8080       │   :5000       │
└───────────────┴───────────────┴───────────────┘
~~~

Doxo manages the apps under a consistent directory structure:

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

### Lazydocker
Use Doxo in conjuction with Lazydocker where Doxo is responsible for deployment cli:
 - app file management
 - local and public deployment
 - 

And [lazydocker](https://github.com/jesseduffield/lazydocker/) for runtime operations like:
 - container status
 - logs
 - restart/stop/start
 - debugging runtime issues

## Commands

### Create
Scaffold and start a new app.

~~~bash
doxo create
doxo create <app-name>
doxo create <app-name> <port>
~~~

Prompts for app name, port, and image type. Available image types:

| Option | Image | Internal port |
|--------|-------|---------------|
| 1 | `caddy:alpine` | 80 |
| 2 | `denoland/deno:latest` | 8000 |
| 3 | custom | prompted |

- **Caddy static** — mounts `data/` to `/srv`, scaffolds `data/index.html`, generates a `file_server` Caddy snippet
- **Deno server** — mounts `.` to `/app`, scaffolds `main.ts` with a `/health` endpoint, generates a `reverse_proxy` Caddy snippet

### Delete
Stop and remove an app and its Caddy route.

~~~bash
doxo delete <app-name>
~~~

Stops containers, removes the app directory, removes the Caddy snippet, and reloads Caddy.

### Expose
Add or update a Caddy route for an existing app.

~~~bash
doxo expose <app-name>
doxo expose <app-name> <domain>
~~~

Reads app config from `.meta` — no compose file parsing needed.


### Unexpose
Remove the Caddy route for an app without deleting the app.

~~~bash
doxo unexpose <app-name>
doxo unexpose <app-name> --force
~~~

### Restart
Restart an app's container.

~~~bash
doxo restart <app-name>
doxo restart <app-name> --recreate
~~~

`--recreate` does a full `docker compose down && up -d` cycle to pick up any changes to `docker-compose.yml`.

### List
List all apps and their current status.

~~~bash
doxo list
~~~

~~~
APP                STATUS       PORT       IMAGE                 UPTIME     MODE       DOMAIN
----------------------------------------------------------------------------------------------
myapp              🟢 running   8080       caddy:alpine          2h         local      myapp.local
api                🟢 running   3000       denoland/deno:latest  5h         tailnet    api.tailnet.ts.net
site               🔴 stopped   80         caddy:alpine          -          public     example.com

~~~

### Open
Opens the app in browers.

~~~bash
doxo open <app-name>
~~~

### Doctor
Checks if docker, caddy and doxo is running.

~~~bash
doxo doctor
~~~

### Uninstall

~~~bash
doxo uninstall
~~~

This removes the symlink only. To remove the doxo files entirely run `rm -rf ~/doxo`.

## The .meta file

Each app stores metadata in `~/docker/<app>/.meta`:

~~~bash
IMAGE=caddy:alpine
CONTAINER_PORT=80
PORT=8080
DOMAIN=app1.local
CREATED_AT=2024-01-01T00:00:00Z
~~~

This is used by `expose`, `unexpose`, `restart`, `delete`, and `list` so no compose file parsing is ever needed.

---

## Tailnet (tailscale)
To access apps across your private network, Doxo can expose services using Tailscale MagicDNS (no /etc/hosts required). You must install [tailscale](https://tailscale.com/) seperately.

### Requirements
 - Tailscale installed and running
 - MagicDNS enabled in your Tailscale admin settings

Use the --tailnet flag when exposing an app:

~~~bash
doxo expose app1 --tailnet
~~~

This will:

 - Create a Caddy route for your Tailnet domain
 - Automatically detect your Tailscale MagicDNS suffix
 - Expose the app on your private network

Example result:

~~~
app1.your-tailnet.ts.net
~~~

## Local DNS

To access apps via their `.local` domain, Doxo can automatically manage local DNS entries for you.

### Recommended (automatic)

Use the --local flag when exposing an app:

~~~bash
doxo expose app1 --local
~~~

This will:

 - Create a Caddy route for app1.local
 - Automatically add an entry to /etc/hosts
 - Map the domain to your local machine

Example result:

~~~
127.0.0.1  app1.local
~~~

### Manual setup (optional fallback)

If you prefer to manage local DNS entries yourself, you can still add them manually:

~~~
127.0.0.1  app1.local
127.0.0.1  app2.local
~~~

Edit the file:

~~~bash
sudo nano /etc/hosts
~~~

### Notes
.local domains are not real DNS records
They only resolve because of /etc/hosts
For LAN or remote access, use a real domain (e.g. app.example.com)

## Project structure

~~~
doxo/
├── bin/
│   └── doxo          # entry point
├── cmd/
│   ├── create.sh
│   ├── delete.sh
│   ├── list.sh
│   ├── restart.sh
│   ├── expose.sh
│   ├── unexpose.sh
│   ├── help.sh
│   ├── open.sh
│   ├── doctor.sh
│   └── uninstall.sh
├── lib/
│   └── common.sh     # shared helpers
└── install.sh
~~~

## Create a release
~~~sh
echo "0.2.0" > VERSION
git commit -m "release 0.2.0"
git tag v0.2.0
git push origin main --tags
~~~