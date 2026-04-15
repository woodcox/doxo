#!/usr/bin/env bash

DOXO_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$HOME/.local/bin"
LINK="$BIN_DIR/doxo"

# --- helpers ---
info()    { echo -e "\033[0;34m[INFO]\033[0m $1"; }
success() { echo -e "\033[0;32m[OK]\033[0m $1"; }
warn()    { echo -e "\033[0;33m[WARN]\033[0m $1"; }

yes_no() {
  read -rp "$1 (y/n): " yn
  [[ "$yn" =~ ^[Yy]$ ]]
}

echo "=== Doxo Uninstaller ==="
echo

# --- remove symlink ---
if [ -L "$LINK" ]; then
  rm "$LINK"
  success "Symlink removed from $BIN_DIR"
else
  info "doxo symlink not found at $LINK"
fi

# --- remove doxo files ---
echo
info "To remove doxo source files run: rm -rf $DOXO_DIR"

# --- caddy ---
echo
warn "Caddy is a Docker container managed by doxo."
warn "Removing it will take down all exposed apps."
if yes_no "Stop and remove the Caddy container?"; then
  if docker ps -a --format '{{.Names}}' | grep -q '^caddy$'; then
    cd "$HOME/docker/caddy"
    docker compose down
    success "Caddy container removed"
  else
    info "Caddy container not found, skipping"
  fi

  if yes_no "Remove Caddy config and sites from ~/docker/caddy?"; then
    rm -rf "$HOME/docker/caddy"
    success "~/docker/caddy removed"
  fi
fi

# --- docker network ---
echo
if yes_no "Remove the 'caddy' Docker network?"; then
  if docker network inspect caddy >/dev/null 2>&1; then
    docker network rm caddy && success "Docker network 'caddy' removed" \
      || warn "Could not remove network — containers may still be attached"
  else
    info "Docker network 'caddy' not found, skipping"
  fi
fi

# --- docker ---
echo
warn "Docker may be used by other applications on this system outside of doxo."
if yes_no "Uninstall Docker?"; then
  if yes_no "⚠️  Are you sure? This will remove Docker and ALL containers on this machine."; then
    if command -v apt-get >/dev/null 2>&1; then
      sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
      sudo rm -rf /var/lib/docker /etc/docker /etc/apt/keyrings/docker.gpg \
        /etc/apt/sources.list.d/docker.list
      success "Docker removed"
    else
      warn "Auto-removal only supported on Debian/Ubuntu."
      info "Remove Docker manually: https://docs.docker.com/engine/uninstall/"
    fi
  fi
fi

# --- summary ---
echo
echo "======================================="
success "Doxo uninstall complete"
echo "======================================="
echo
info "App data in ~/docker/ was not removed"
info "To remove it run: rm -rf ~/docker"
echo