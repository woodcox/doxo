# Caddy Setup

Doxo assumes Caddy is running as a Docker container on a shared `caddy` network.
Each app gets its own Caddy snippet in `~/docker/caddy/sites/` which Caddy
imports automatically.

---

## Directory structure

~~~
~/docker/caddy/
├── docker-compose.yml
├── Caddyfile
├── data/             # auto-created by Caddy, do not edit
├── config/           # auto-created by Caddy, do not edit
└── sites/
    ├── app1.caddy
    └── app2.caddy
~~~

---

## docker-compose.yml

~~~yaml
version: "3.8"

services:
  caddy:
    image: caddy:alpine
    container_name: caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - ./sites:/etc/caddy/sites
      - ./data:/data
      - ./config:/config
    networks:
      - caddy

networks:
  caddy:
    external: true
~~~

---

## Caddyfile

~~~
{
  email you@example.com
}

import /etc/caddy/sites/*.caddy
~~~

The `import` directive tells Caddy to load every snippet from the `sites/`
directory. When doxo creates or exposes an app it writes a `.caddy` file there
and reloads Caddy — no manual edits to the `Caddyfile` ever needed.

---

## First time setup

Create the shared Docker network:

~~~bash
docker network create caddy
~~~

Create the Caddy directory and files:

~~~bash
mkdir -p ~/docker/caddy/{sites,data,config}
~~~

Create `~/docker/caddy/Caddyfile` and `~/docker/caddy/docker-compose.yml` with
the contents above, then start Caddy:

~~~bash
cd ~/docker/caddy
docker compose up -d
~~~

Verify Caddy is running:

~~~bash
docker ps | grep caddy
~~~

---

## Local development

For `.local` domains, add entries to `/etc/hosts` for each app:

~~~
127.0.0.1  app1.local
127.0.0.1  app2.local
~~~

---

## HTTPS in production

Replace `.local` domains with real domains when running on a public server.
Caddy will automatically obtain and renew TLS certificates via Let's Encrypt
as long as port `443` is open and DNS points to your server. No extra
configuration needed.
~~~