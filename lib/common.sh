#!/usr/bin/env bash

source "$(dirname "$0")/../lib/common.sh"

DOXO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BIN_DIR="$HOME/.local/bin"
LINK="$BIN_DIR/doxo"

# --- header ---
gum style \
  --foreground 212 --border-foreground 212 --border rounded \
  --padding "0 1" "  doxo uninstall"
echo

gum style --foreground 214 "  This removes the doxo CLI. Your apps in ~/docker/ are not touched."
echo

gum confirm --default=false "Continue with uninstall?" || { echo "Cancelled"; exit 0; }
echo

# --- remove symlink ---
if [ -L "$LINK" ]; then
  rm "$LINK"
  gum style --foreground 212 "✔ Symlink removed from $BIN_DIR"
else
  gum log --level info "doxo symlink not found at $LINK"
fi

# --- haloy docker network ---
echo
if docker network inspect haloy >/dev/null 2>&1; then
  gum style --foreground 214 "  ⚠ The 'haloy' Docker network is shared by all your apps."
  if gum confirm --default=false "Remove the 'haloy' Docker network?"; then
    docker network rm haloy \
      && gum style --foreground 212 "✔ Docker network 'haloy' removed" \
      || gum log --level warn "Could not remove network — containers may still be attached"
  fi
else
  gum log --level info "Docker network 'haloy' not found, skipping"
fi

# --- docker ---
echo
gum style --foreground 214 "  ⚠ Docker may be used by other applications outside of doxo."
if gum confirm --default=false "Uninstall Docker?"; then
  gum style --foreground 196 "  This will remove Docker and ALL containers on this machine."
  if gum confirm --default=false "Are you sure?"; then
    if command -v apt-get >/dev/null 2>&1; then
      gum spin --spinner dot --title "Removing Docker..." -- \
        sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
      sudo rm -rf /var/lib/docker /etc/docker /etc/apt/keyrings/docker.gpg \
        /etc/apt/sources.list.d/docker.list
      gum style --foreground 212 "✔ Docker removed"
    else
      gum log --level warn "Auto-removal only supported on Debian/Ubuntu"
      gum log --level info "Remove Docker manually: https://docs.docker.com/engine/uninstall/"
    fi
  fi
fi

# --- summary ---
echo
gum style \
  --foreground 212 --border-foreground 212 --border rounded \
  --padding "0 1" "  ✔ Doxo uninstall complete"
echo
gum style --foreground 240 "  App data in ~/docker/ was not removed"
gum style --foreground 240 "  To remove it run: rm -rf ~/docker"
echo
gum style --foreground 240 "  To remove doxo source files run: rm -rf $DOXO_DIR"
echo