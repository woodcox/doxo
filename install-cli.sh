#!/usr/bin/env bash

REPO="https://github.com/woodcox/doxo.git"
DOXO_DIR="$HOME/doxo"
BIN_DIR="$HOME/.local/bin"
LINK="$BIN_DIR/doxo"

# plain helpers — gum not available yet at this stage
info()    { echo -e "\033[0;34m[INFO]\033[0m $1"; }
success() { echo -e "\033[0;32m[OK]\033[0m $1"; }
error()   { echo -e "\033[0;31m[ERROR]\033[0m $1" >&2; exit 1; }

info "Doxo installer starting..."
echo

# --- preflight checks ---
if ! command -v git >/dev/null 2>&1; then
  error "git is required but not installed. Install it with: sudo apt install git"
fi

if ! command -v docker >/dev/null 2>&1; then
  error "Docker is required but not installed. See: https://docs.docker.com/engine/install/"
fi

if ! command -v gum >/dev/null 2>&1; then
  info "gum is required for the doxo UI. Installing..."
  if command -v apt-get >/dev/null 2>&1; then
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://repo.charm.sh/apt/gpg.key \
      | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
    echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" \
      | sudo tee /etc/apt/sources.list.d/charm.list > /dev/null
    sudo apt-get update -qq && sudo apt-get install -y gum \
      || error "Failed to install gum — install manually: https://github.com/charmbracelet/gum"
  else
    error "Cannot auto-install gum on this system. Install manually: https://github.com/charmbracelet/gum"
  fi
  success "gum installed"
fi

# --- clone or update doxo ---
if [ -d "$DOXO_DIR/.git" ]; then
  info "Updating existing doxo install..."
  git -C "$DOXO_DIR" pull || error "git pull failed"
else
  info "Cloning doxo..."
  git clone "$REPO" "$DOXO_DIR" || error "git clone failed — check your internet connection"
fi

# --- symlink ---
mkdir -p "$BIN_DIR"
chmod +x "$DOXO_DIR/bin/doxo"
find "$DOXO_DIR/cmd" -type f -name "*.sh" -exec chmod +x {} \;
ln -sf "$DOXO_DIR/bin/doxo" "$LINK" || error "Failed to create symlink at $LINK"

export PATH="$HOME/.local/bin:$PATH"
success "doxo available at $LINK"

# --- hand off to doxo install ---
info "Running doxo install..."
"$LINK" install