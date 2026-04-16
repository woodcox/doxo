#!/usr/bin/env bash

source "$(dirname "$0")/../../../lib/common.sh"

# --- helpers ---
info() { echo "[INFO] $1"; }
success() { echo "[OK] $1"; }
error() { echo "[ERROR] $1" >&2; }

exists_cmd() {
  command -v "$1" >/dev/null 2>&1
}

exists_network() {
  docker network inspect "$1" >/dev/null 2>&1
}

echo "Caddy service installer"
echo "======================="

ERRORS=()
FORCE=0
if [[ "${1:-}" == "--force" ]]; then
  FORCE=1
fi

ports_in_use() {
  ss -tuln | awk '{print $5}' | grep -E ':(80|443)$'
}

# --- install caddy as a docker container ---
install_caddy() {
  info "Setting up Caddy..."

  if ! exists_cmd docker; then
    error "Docker is not installed"
    return 1
  fi

  # warn if system caddy is running
  if systemctl is-active --quiet caddy 2>/dev/null; then
    error "A system-installed Caddy is already running — port conflict on 80/443."
    info "Stop it first: sudo systemctl stop caddy && sudo systemctl disable caddy"
    return 1
  fi

  if ports_in_use && [[ "$FORCE" != "1" ]]; then
    error "Ports 80/443 are already in use"
    info "Caddy cannot start"
    error "Run 'doxo service caddy install --force' to override"
    return 1
  fi

  mkdir -p "$HOME/docker/caddy"

  # wait for docker daemon
  local retries=0
  until docker info >/dev/null 2>&1; do
    info "Waiting for Docker daemon..."
    sleep 2
    retries=$((retries + 1))
    [ "$retries" -ge 10 ] && { error "Docker daemon did not start in time"; return 1; }
  done

  if ! exists_network caddy; then
    docker network create caddy
    success "Created docker network: caddy"
  else
    info "Docker network 'caddy' already exists"
  fi
  
  # only create sites/ — data/ and config/ are caddy-managed
  mkdir -p "$HOME/docker/caddy/sites"
  #mkdir -p "$HOME/docker/caddy/data"
  #mkdir -p "$HOME/docker/caddy/config"

  success "Created $HOME/docker/caddy/sites"

  if [ ! -f "$HOME/docker/caddy/Caddyfile" ]; then
    cat <<EOF > "$HOME/docker/caddy/Caddyfile"
{
  email you@example.com
}

import /etc/caddy/sites/*
EOF
    success "Caddyfile created"
    info "⚠️  Edit $HOME/docker/caddy/Caddyfile and set your email address"
  else
    info "Caddyfile already exists, skipping"
  fi

  if [ ! -f "$HOME/docker/caddy/docker-compose.yml" ]; then
    cat <<EOF > "$HOME/docker/caddy/docker-compose.yml"
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
EOF
    success "Caddy docker-compose.yml created"
  else
    info "Caddy docker-compose.yml already exists, skipping"
  fi

  cd "$HOME/docker/caddy" || {
  error "Failed to enter Caddy directory"
  return 1
}

  info "Pulling Caddy image..."
  docker compose pull

  info "Starting Caddy..."
  docker compose up -d --remove-orphans
  success "Caddy is running 🚀"
}



install_caddy

# --- create test app ---
echo
if yes_no "Do you want to create a test app (hello-world.local)?"; then
  info "Creating test app via doxo..."

  doxo create hello-world --local

  success "Test app created!"
  
  info "Then visit: http://hello-world.local"
fi

