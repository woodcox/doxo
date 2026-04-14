#!/usr/bin/env bash

DOXO_DIR="$HOME/doxo"
BIN_DIR="$HOME/.local/bin"
LINK="$BIN_DIR/doxo"
REPO="https://github.com/woodcox/doxo.git"

# --- clone or update ---
if [ -d "$DOXO_DIR/.git" ]; then
  echo "Updating doxo..."
  git -C "$DOXO_DIR" pull
else
  echo "Installing doxo..."
  git clone "$REPO" "$DOXO_DIR"
fi

mkdir -p "$BIN_DIR"
chmod +x "$DOXO_DIR/bin/doxo"
chmod +x "$DOXO_DIR/cmd/"*.sh

if [ -L "$LINK" ]; then
  rm "$LINK"
fi

ln -s "$DOXO_DIR/bin/doxo" "$LINK"

echo "✅ doxo installed → $BIN_DIR/doxo"
echo "   Make sure $BIN_DIR is in your PATH"
echo "   Add to ~/.bashrc: export PATH=\"\$HOME/.local/bin:\$PATH\""