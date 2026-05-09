#!/usr/bin/env bash

source "$(dirname "$0")/../lib/common.sh"

ERRORS=()
WARNINGS=()

check_ok()   { gum style --foreground 212 "  ✔ $1"; }
check_err()  { gum style --foreground 196 "  ✖ $1"; ERRORS+=("$1"); }
check_warn() { gum style --foreground 214 "  ⚠ $1"; WARNINGS+=("$1"); }

# --- header ---
gum style \
  --foreground 212 --border-foreground 212 --border rounded \
  --padding "0 1" "  doxo doctor"
echo

# --- Docker ---
gum style --foreground 212 --bold "Docker"

if exists_cmd docker; then
  check_ok "Docker installed: $(docker --version)"
else
  check_err "Docker not installed — run install.sh"
fi

if docker info >/dev/null 2>&1; then
  check_ok "Docker daemon running"
else
  check_err "Docker daemon not running — try: sudo systemctl start docker"
fi

if docker compose version >/dev/null 2>&1; then
  check_ok "Docker Compose available: $(docker compose version)"
else
  check_err "Docker Compose plugin not found — install docker-compose-plugin"
fi

# --- Docker network ---
echo
gum style --foreground 212 --bold "Network"

if docker network inspect haloy >/dev/null 2>&1; then
  check_ok "Docker network 'haloy' exists"
else
  check_warn "Docker network 'haloy' missing — will be created on first doxo create"
fi

# --- haloyd ---
echo
gum style --foreground 212 --bold "haloyd"

if exists_service haloyd; then
  if systemctl is-active --quiet haloyd 2>/dev/null; then
    check_ok "haloyd service running"
  else
    check_err "haloyd service installed but not running — try: sudo systemctl start haloyd"
  fi
else
  check_err "haloyd not installed — see https://haloy.dev/docs/server-installation"
fi

# check ports 80/443 are accessible (haloyd proxy)
for port in 80 443; do
  if ss -tlnp 2>/dev/null | grep -q ":$port "; then
    check_ok "Port $port is bound"
  else
    check_warn "Port $port not bound — haloyd proxy may not be running"
  fi
done

# warn if system caddy is running and competing on 80/443
if systemctl is-active --quiet caddy 2>/dev/null; then
  check_warn "System Caddy service is running — may conflict with haloyd on ports 80/443. Disable with: sudo systemctl disable --now caddy"
fi

# --- Tailscale ---
echo
gum style --foreground 212 --bold "Tailscale"

if exists_cmd tailscale; then
  check_ok "Tailscale installed: $(tailscale version | head -1)"

  if tailscale status >/dev/null 2>&1; then
    check_ok "Tailscale connected"

    # check MagicDNS hostname is resolvable
    if command -v jq &>/dev/null; then
      TS_MACHINE=$(tailscale status --json 2>/dev/null \
        | jq -r '.Self.DNSName | rtrimstr(".")')
    else
      TS_MACHINE=$(tailscale status --json 2>/dev/null \
        | grep -o '"DNSName":[^,]*' | head -1 | cut -d'"' -f4 | sed 's/\.$//')
    fi

    if [ -n "$TS_MACHINE" ]; then
      check_ok "MagicDNS hostname: $TS_MACHINE"
    else
      check_warn "Could not detect Tailscale MagicDNS hostname — is MagicDNS enabled?"
    fi

    # check funnel is available
    if tailscale funnel status >/dev/null 2>&1; then
      check_ok "Tailscale Funnel available"
    else
      check_warn "Tailscale Funnel unavailable — enable it in the Tailscale admin console"
    fi
  else
    check_err "Tailscale not connected — run: tailscale up"
  fi
else
  check_warn "Tailscale not installed — needed for expose --public / --private"
fi

# --- jq ---
echo
gum style --foreground 212 --bold "Optional tools"

if exists_cmd jq; then
  check_ok "jq installed — Tailscale hostname detection will be reliable"
else
  check_warn "jq not installed — Tailscale hostname detection uses fallback grep (less reliable). Install with: sudo apt install jq"
fi

# --- Doxo CLI ---
echo
gum style --foreground 212 --bold "Doxo CLI"

if exists_cmd doxo; then
  DOXO_PATH=$(command -v doxo)
  check_ok "doxo in PATH: $DOXO_PATH"

  if [ -L "$DOXO_PATH" ]; then
    TARGET=$(readlink -f "$DOXO_PATH")
    if [ -f "$TARGET" ]; then
      check_ok "Symlink target exists: $TARGET"
    else
      check_err "Symlink target missing: $TARGET — run install.sh to reinstall"
    fi
  fi
else
  check_err "doxo not in PATH — add $HOME/.local/bin to PATH or run install.sh"
fi

# --- Apps ---
echo
gum style --foreground 212 --bold "Apps"

APP_COUNT=0
for dir in "$BASE_DIR"/*/; do
  [ -d "$dir" ] || continue
  APP_NAME=$(basename "$dir")
  is_protected "$APP_NAME" && continue
  APP_COUNT=$((APP_COUNT + 1))
done

check_ok "$APP_COUNT app(s) found in $BASE_DIR"

# --- summary ---
echo
if [ ${#ERRORS[@]} -eq 0 ] && [ ${#WARNINGS[@]} -eq 0 ]; then
  gum style \
    --foreground 212 --border-foreground 212 --border rounded \
    --padding "0 1" "  ✔ All systems healthy"
elif [ ${#ERRORS[@]} -eq 0 ]; then
  gum style \
    --foreground 214 --border-foreground 214 --border rounded \
    --padding "0 1" "  ⚠ Healthy with warnings"
  for w in "${WARNINGS[@]}"; do
    gum style --foreground 214 "  • $w"
  done
else
  gum style \
    --foreground 196 --border-foreground 196 --border rounded \
    --padding "0 1" "  ✖ Issues detected"
  for e in "${ERRORS[@]}"; do
    gum style --foreground 196 "  • $e"
  done
  echo
  exit 1
fi
echo