#!/usr/bin/env bash

REPO="https://github.com/woodcox/doxo.git"
DOXO_DIR="$HOME/doxo"
BIN_DIR="$HOME/.local/bin"
LINK="$BIN_DIR/doxo"

info()    { echo -e "\033[0;34m[INFO]\033[0m $1"; }
success() { echo -e "\033[0;32m[OK]\033[0m $1"; }
error()   { echo -e "\033[0;31m[ERROR]\033[0m $1" >&2; exit 1; }

info "Downloading doxo..."

# --- preflight ---
if ! command -v git >/dev/null 2>&1; then
  error "git is required but not installed. Install it and try again."
fi

# --- clone or update ---
if [ -d "$DOXO_DIR/.git" ]; then
  info "Updating existing install..."
  git -C "$DOXO_DIR" pull || error "git pull failed"
else
  info "Cloning doxo..."
  git clone "$REPO" "$DOXO_DIR" || error "git clone failed — check your internet connection"
fi

# --- set permissions and symlink ---
mkdir -p "$BIN_DIR"
chmod +x "$DOXO_DIR/bin/doxo"
if [ -L "$LINK" ]; then
  info "Updating existing symlink..."
fi
ln -sf "$DOXO_DIR/bin/doxo" "$LINK" || error "Failed to create symlink at $LINK"
success "doxo available at $LINK"

# --- make available in current shell ---
export PATH="$HOME/.local/bin:$PATH"

success "doxo downloaded → $LINK"

# --- hand off to doxo install ---
info "Running doxo install..."
# $LINK == doxo
"$LINK" install