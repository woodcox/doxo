#!/usr/bin/env bash
set -e

REPO="https://github.com/woodcox/doxo.git"
DOXO_DIR="$HOME/doxo"
BIN_DIR="$HOME/.local/bin"
LINK="$BIN_DIR/doxo"

info()    { echo -e "\033[0;34m[INFO]\033[0m $1"; }
success() { echo -e "\033[0;32m[OK]\033[0m $1"; }
error()   { echo -e "\033[0;31m[ERROR]\033[0m $1" >&2; }

info "Downloading doxo..."

# clone or update
if [ -d "$DOXO_DIR/.git" ]; then
  info "Updating existing install..."
  git -C "$DOXO_DIR" pull
else
  git clone "$REPO" "$DOXO_DIR"
fi

# setup binary
mkdir -p "$BIN_DIR"
chmod +x "$DOXO_DIR/bin/doxo"
ln -sf "$DOXO_DIR/bin/doxo" "$LINK"

# ✅ make doxo command available immediately
export PATH="$HOME/.local/bin:$PATH"

success "doxo downloaded → $LINK"

# run real installer (doxo install)
info "Running doxo install..."
# $LINK == doxo
"$LINK" install