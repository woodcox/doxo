#!/usr/bin/env bash

BIN_DIR="$HOME/.local/bin"
LINK="$BIN_DIR/doxo"

if [ -L "$LINK" ]; then
  rm "$LINK"
  echo "✅ doxo uninstalled — symlink removed from $BIN_DIR"
else
  echo "ℹ️  doxo is not installed at $LINK"
fi

echo "To remove doxo files run: rm -rf $DOXO_DIR"