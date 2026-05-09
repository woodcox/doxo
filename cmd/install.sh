#!/usr/bin/env bash

DOXO_DIR="$HOME/doxo"
BIN_DIR="$HOME/.local/bin"
LINK="$BIN_DIR/doxo"
REPO="https://github.com/woodcox/doxo.git"
REPAIR_MODE=0

# --- parse args ---
if [[ "${1:-}" == "--repair" ]]; then
  REPAIR_MODE=1
fi

# --- header ---
gum style \
  --foreground 212 --border-foreground 212 --border rounded \
  --padding "0 1" "  doxo install"
echo

# --- install doxo ---
install_doxo() {
  if [[ "$REPAIR_MODE" == "1" ]]; then
    gum log --level info "Repair mode: forcing reinstall"
    rm -rf "$DOXO_DIR"
  fi

  if [ -d "$DOXO_DIR/.git" ]; then
    gum spin --spinner dot --title "Updating doxo..." -- \
      git -C "$DOXO_DIR" pull \
      || { gum log --level error "git pull failed"; return 1; }
  else
    gum spin --spinner dot --title "Cloning doxo..." -- \
      git clone "$REPO" "$DOXO_DIR" \
      || { gum log --level error "git clone failed — check your internet connection"; return 1; }
  fi

  mkdir -p "$BIN_DIR"
  chmod +x "$DOXO_DIR/bin/doxo"
  find "$DOXO_DIR/cmd" -type f -name "*.sh" -exec chmod +x {} \;

  [ -L "$LINK" ] && rm "$LINK"
  ln -sf "$DOXO_DIR/bin/doxo" "$LINK"
  gum log --level info "doxo installed → $LINK"
}

ensure_path() {
  local shell_rc="$HOME/.bashrc"
  local path_line='export PATH="$HOME/.local/bin:$PATH"'

  [[ "$SHELL" == *"zsh" ]] && shell_rc="$HOME/.zshrc"

  if grep -Fxq "$path_line" "$shell_rc"; then
    gum log --level info "PATH already configured in $shell_rc"
    return 0
  fi

  echo "" >> "$shell_rc"
  echo "# Added by doxo installer" >> "$shell_rc"
  echo "$path_line" >> "$shell_rc"
  gum log --level info "Added ~/.local/bin to PATH in $shell_rc"
  gum log --level warn "Run: source $shell_rc  or restart your terminal to apply"
}

# --- check haloyd ---
check_haloyd() {
  gum style --foreground 212 --bold "haloyd"

  if systemctl list-units --full -all 2>/dev/null | grep -q "haloyd.service"; then
    if systemctl is-active --quiet haloyd; then
      gum style --foreground 212 "  ✔ haloyd running"
    else
      gum style --foreground 214 "  ⚠ haloyd installed but not running"
      gum style --foreground 240 "    Start with: sudo systemctl start haloyd"
    fi
  else
    gum style --foreground 214 "  ⚠ haloyd not installed"
    gum style --foreground 240 "    Install it on your server:"
    gum style --foreground 240 "    curl -fsSL https://sh.haloy.dev/install-haloyd.sh | API_DOMAIN=<your-tailscale-hostname> sh"
    gum style --foreground 240 "    See: https://haloy.dev/docs/server-installation"
  fi
  echo
}

# --- check tailscale ---
check_tailscale() {
  gum style --foreground 212 --bold "Tailscale"

  if command -v tailscale >/dev/null 2>&1; then
    gum style --foreground 212 "  ✔ Tailscale installed"
    if tailscale status >/dev/null 2>&1; then
      gum style --foreground 212 "  ✔ Tailscale connected"
    else
      gum style --foreground 214 "  ⚠ Tailscale not connected — run: tailscale up"
    fi
  else
    gum style --foreground 214 "  ⚠ Tailscale not installed"
    gum style --foreground 240 "    Install: curl -fsSL https://tailscale.com/install.sh | sh"
    gum style --foreground 240 "    Required for: doxo expose --public / --private"
  fi
  echo
}

# --- check docker ---
check_docker() {
  gum style --foreground 212 --bold "Docker"

  if ! command -v docker >/dev/null 2>&1; then
    gum style --foreground 196 "  ✖ Docker not installed"
    gum style --foreground 240 "    See: https://docs.docker.com/engine/install/"
    echo
    return 1
  fi

  gum style --foreground 212 "  ✔ Docker installed: $(docker --version)"

  if docker info >/dev/null 2>&1; then
    gum style --foreground 212 "  ✔ Docker daemon running"
  else
    gum style --foreground 196 "  ✖ Docker daemon not running — try: sudo systemctl start docker"
  fi

  if docker compose version >/dev/null 2>&1; then
    gum style --foreground 212 "  ✔ Docker Compose available"
  else
    gum style --foreground 196 "  ✖ Docker Compose plugin not found — install docker-compose-plugin"
  fi
  echo
}

# --- check jq ---
check_jq() {
  gum style --foreground 212 --bold "Optional tools"

  if command -v jq >/dev/null 2>&1; then
    gum style --foreground 212 "  ✔ jq installed"
  else
    gum style --foreground 214 "  ⚠ jq not installed — Tailscale hostname detection uses fallback grep"
    gum style --foreground 240 "    Install with: sudo apt install jq"
  fi
  echo
}

# --- run ---
install_doxo
ensure_path

echo
gum style --foreground 212 --bold "Checking dependencies"
echo

check_docker
check_haloyd
check_tailscale
check_jq

# --- done ---
gum style \
  --foreground 212 --border-foreground 212 --border rounded \
  --padding "0 1" "  ✔ Doxo installation complete"
echo
gum style --foreground 240 "  Get started:"
gum style --foreground 240 "  doxo create        create your first app"
gum style --foreground 240 "  doxo doctor        check all systems"
gum style --foreground 240 "  doxo help          show all commands"
echo