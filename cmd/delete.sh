#!/usr/bin/env bash

source "$(dirname "$0")/../lib/common.sh"

ERRORS=()
APP_NAME="${1:-}"

# --- validate input ---
if [ -z "$APP_NAME" ]; then
  gum log --level error "Usage: doxo delete <app-name>"
  exit 1
fi

if ! validate_name "$APP_NAME"; then
  gum log --level error "Invalid app name"
  exit 1
fi

if is_protected "$APP_NAME"; then
  gum log --level error "'$APP_NAME' is a protected app and cannot be deleted"
  exit 1
fi

APP_DIR="$BASE_DIR/$APP_NAME"

if [ ! -d "$APP_DIR" ]; then
  gum log --level error "App '$APP_NAME' does not exist"
  exit 1
fi

# --- load metadata ---
load_meta "$APP_DIR"

# --- header ---
gum style \
  --foreground 212 --border-foreground 212 --border rounded \
  --padding "0 1" "  doxo delete"

echo
gum style --foreground 240 "  App       $(gum style --foreground 212 "$APP_NAME")"
gum style --foreground 240 "  Image     $(gum style --foreground 212 "$IMAGE")"
gum style --foreground 240 "  Mode      $(gum style --foreground 212 "${MODE:-none}")"
[ -n "$DOMAIN" ] && \
  gum style --foreground 240 "  Domain    $(gum style --foreground 212 "$DOMAIN")"
gum style --foreground 240 "  Directory $(gum style --foreground 212 "$APP_DIR")"
echo

# --- confirm ---
gum confirm --default=false \
  "$(gum style --foreground 196 "⚠  Delete '$APP_NAME'? This cannot be undone.")" \
  || { echo "Cancelled"; exit 0; }

echo

# --- unexpose from tailscale if needed ---
if [ "$MODE" = "public" ]; then
  gum spin --spinner dot --title "Removing Tailscale Funnel for $APP_NAME..." -- \
    tailscale funnel --bg --set-path "/$APP_NAME" off \
    || ERRORS+=("Failed to remove Tailscale Funnel")
elif [ "$MODE" = "private" ]; then
  gum spin --spinner dot --title "Removing Tailscale Serve for $APP_NAME..." -- \
    tailscale serve --bg --set-path "/$APP_NAME" off \
    || ERRORS+=("Failed to remove Tailscale Serve")
fi

# --- stop & remove containers ---
gum spin --spinner dot --title "Stopping containers..." -- \
  bash -c "cd '$APP_DIR' && docker compose down" \
  || ERRORS+=("docker compose down failed")

# --- remove app directory ---
gum spin --spinner dot --title "Removing app directory..." -- \
  rm -rf "$APP_DIR" \
  || ERRORS+=("Failed to remove $APP_DIR")

# --- report ---
report_errors "$APP_NAME" "deleted" "${ERRORS[@]}"
