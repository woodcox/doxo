#!/usr/bin/env bash

DOXO_DIR="$HOME/doxo"
BIN_DIR="$HOME/.local/bin"
LINK="$BIN_DIR/doxo"
REPO="https://github.com/woodcox/doxo.git"

# --- helpers ---
info()    { echo -e "\033[0;34m[INFO]\033[0m $1"; }
success() { echo -e "\033[0;32m[OK]\033[0m $1"; }
error()   { echo -e "\033[0;31m[ERROR]\033[0m $1" >&2; }

yes_no() {
  read -rp "$1 (y/n): " yn
  [[ "$yn" =~ ^[Yy]$ ]]
}

# --- install docker ---
install_docker() {
  info "Installing Docker..."

  # requires root
  if [ "$(id -u)" -ne 0 ]; then
    error "Docker installation requires root. Re-run install.sh with sudo."
    return 1
  fi

  # detect distro
  if [ ! -f /etc/os-release ]; then
    error "Cannot detect distribution. Install Docker manually: https://docs.docker.com/engine/install/"
    return 1
  fi

  . /etc/os-release
  DISTRO="$ID"
  VERSION_CODENAME="${VERSION_CODENAME:-}"

  info "Detected distribution: $DISTRO"

  case "$DISTRO" in
    ubuntu|debian|linuxmint|pop|elementary|zorin)
      [[ "$DISTRO" =~ ^(linuxmint|pop|elementary|zorin)$ ]] && DISTRO="ubuntu"
      _install_docker_debian_ubuntu
      ;;
    centos|rocky|almalinux)
      DISTRO="centos"
      _install_docker_centos_rhel
      ;;
    rhel)
      _install_docker_centos_rhel
      ;;
    fedora)
      _install_docker_fedora
      ;;
    alpine)
      _install_docker_alpine
      ;;
    *)
      error "Unsupported distribution: $DISTRO. Install Docker manually: https://docs.docker.com/engine/install/"
      return 1
      ;;
  esac

  # add current user to docker group
  if [ -n "$SUDO_USER" ] && ! groups "$SUDO_USER" | grep -q docker; then
    usermod -aG docker "$SUDO_USER"
    info "Added $SUDO_USER to docker group — log out and back in for this to take effect"
  fi

  if command -v docker >/dev/null 2>&1; then
    success "Docker installed: $(docker --version)"
  else
    error "Docker installation completed but 'docker' command not found"
    return 1
  fi
}

_install_docker_debian_ubuntu() {
  apt-get update
  apt-get install -y ca-certificates curl gnupg

  install -m 0755 -d /etc/apt/keyrings
  [ -f /etc/apt/keyrings/docker.gpg ] && rm /etc/apt/keyrings/docker.gpg
  curl -fsSL "https://download.docker.com/linux/$DISTRO/gpg" \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  CODENAME="$VERSION_CODENAME"
  if [ -z "$CODENAME" ] && command -v lsb_release >/dev/null 2>&1; then
    CODENAME=$(lsb_release -cs)
  fi
  [ -z "$CODENAME" ] && { error "Cannot determine codename"; return 1; }

  ARCH=$(dpkg --print-architecture)
  echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/$DISTRO $CODENAME stable" \
    > /etc/apt/sources.list.d/docker.list

  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
  systemctl enable docker && systemctl start docker
}

_install_docker_centos_rhel() {
  PKG_MGR=$(command -v dnf || command -v yum)
  [ -z "$PKG_MGR" ] && { error "Neither dnf nor yum found"; return 1; }

  $PKG_MGR remove -y docker docker-client docker-client-latest docker-common \
    docker-latest docker-latest-logrotate docker-logrotate docker-engine 2>/dev/null || true
  $PKG_MGR install -y yum-utils

  REPO_DISTRO="$DISTRO"
  [ "$DISTRO" = "rhel" ] && REPO_DISTRO="centos"
  yum-config-manager --add-repo \
    "https://download.docker.com/linux/$REPO_DISTRO/docker-ce.repo"

  $PKG_MGR install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
  systemctl enable docker && systemctl start docker
}

_install_docker_fedora() {
  dnf remove -y docker docker-client docker-client-latest docker-common \
    docker-latest docker-latest-logrotate docker-logrotate docker-selinux \
    docker-engine-selinux docker-engine 2>/dev/null || true
  dnf install -y dnf-plugins-core
  dnf config-manager --add-repo \
    https://download.docker.com/linux/fedora/docker-ce.repo
  dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
  systemctl enable docker && systemctl start docker
}

_install_docker_alpine() {
  apk update
  apk add docker docker-cli
  rc-update add docker boot
  service docker start
}

# --- install caddy as a docker container ---
install_caddy() {
  info "Setting up Caddy..."

  # wait for docker (to prevent race conditions)
  until docker info >/dev/null 2>&1; do
    info "Waiting for Docker to start..."
    sleep 2
  done

  if ! docker network inspect caddy >/dev/null 2>&1; then
    docker network create caddy
    success "Created docker network: caddy"
  else
    info "Docker network 'caddy' already exists"
  fi

  mkdir -p "$HOME/docker/caddy/sites"
  mkdir -p "$HOME/docker/caddy/data"
  mkdir -p "$HOME/docker/caddy/config"

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
EOF
    success "Caddy docker-compose.yml created"
  else
    info "Caddy docker-compose.yml already exists, skipping"
  fi

  cd "$HOME/docker/caddy"

  info "Pulling Caddy image..."
  docker compose pull

  info "Starting Caddy..."
  docker compose up -d --remove-orphans
  success "Caddy is running 🚀"
}

# --- install doxo ---
install_doxo() {
  info "Installing doxo..."

  if [ -d "$DOXO_DIR/.git" ]; then
    info "Updating existing doxo installation..."
    git -C "$DOXO_DIR" pull
  else
    git clone "$REPO" "$DOXO_DIR"
  fi

  mkdir -p "$BIN_DIR"
  chmod +x "$DOXO_DIR/bin/doxo"
  chmod +x "$DOXO_DIR/cmd/"*.sh

  [ -L "$LINK" ] && rm "$LINK"
  ln -s "$DOXO_DIR/bin/doxo" "$LINK"
  success "doxo installed → $LINK"
}

# --- main ---
echo "=== Doxo Installer ==="
echo

# check for docker
if command -v docker >/dev/null 2>&1; then
  info "Docker already installed: $(docker --version)"
else
  if yes_no "Docker is not installed. Install it now?"; then
    install_docker || { error "Docker installation failed"; exit 1; }
  else
    error "Docker is required to run doxo"
    exit 1
  fi
fi

# check for caddy container
if docker ps -a --format '{{.Names}}' | grep -q '^caddy$'; then
  info "Caddy container already exists"
else
  if yes_no "Caddy is not set up. Set it up now?"; then
    install_caddy
  else
    info "Skipping Caddy setup — see docs/caddy-setup.md"
  fi
fi

# install doxo
install_doxo

# --- post install ---
echo
echo "======================================="
success "Doxo installation complete!"
echo "======================================="
echo
info "Make sure $BIN_DIR is in your PATH:"
echo "   export PATH=\"\$HOME/.local/bin:\$PATH\""
echo
info "Add the above to your ~/.bashrc or ~/.zshrc to make it permanent"
echo
info "Then run: doxo help"
echo
info "If you see the help menu, now try running: doxo create hello-world --local"
echo
info "Them open a browser and go to: https://hello-world.local
echo