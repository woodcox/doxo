#!/usr/bin/env bash

source "$(dirname "$0")/../../../lib/common.sh"

info() { echo "[INFO] $1"; }
success() { echo "[OK] $1"; }
error() { echo "[ERROR] $1" >&2; }

echo "Tailscale installer"
echo "==================="

# check if already installed
if exists_cmd tailscale; then
  info "Tailscale already installed"
else
  info "Installing Tailscale..."

  curl -fsSL https://tailscale.com/install.sh | bash || {
    error "Failed to install Tailscale"
    exit 1
  }

  success "Tailscale installed"
fi

# check if running
if systemctl is-active --quiet tailscaled; then
  info "tailscaled is already running"
elif systemctl is-failed --quiet tailscaled; then
  error "tailscaled is in a failed state — check: sudo systemctl status tailscaled"
  exit 1
else
  info "Starting tailscaled..."
  sudo systemctl enable --now tailscaled || {
    error "Failed to start tailscaled"
    exit 1
  }
fi

if tailscale status &>/dev/null; then
  info "Tailscale already authenticated"
else
  echo
  info "Run the following to authenticate:"
  echo "  sudo tailscale up"
  echo
fi

success "Tailscale ready"