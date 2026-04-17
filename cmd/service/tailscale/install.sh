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

# --- configure caddy access to tailscale socket ---

# note: only required if caddy runs as non-root
# docker caddy container runs as root by default so this may be a no-op
# included for completeness if caddy user is changed later
TAILSCALED_DEFAULT="/etc/default/tailscaled"

if [ -f "$TAILSCALED_DEFAULT" ]; then
  if grep -q "TS_PERMIT_CERT_UID" "$TAILSCALED_DEFAULT"; then
    info "TS_PERMIT_CERT_UID already set"
  else
    info "Granting Caddy access to Tailscale certificates..."
    echo "TS_PERMIT_CERT_UID=caddy" | sudo tee -a "$TAILSCALED_DEFAULT" >/dev/null || {
      error "Failed to update $TAILSCALED_DEFAULT"
      exit 1
    }
    info "Restarting tailscaled..."
    sudo systemctl restart tailscaled || {
      error "Failed to restart tailscaled"
      exit 1
    }
    success "Caddy granted certificate access"
  fi
else
  error "$TAILSCALED_DEFAULT not found — is tailscaled installed?"
  exit 1
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