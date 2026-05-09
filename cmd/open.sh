#!/usr/bin/env bash

source "$(dirname "$0")/../lib/common.sh"

APP_NAME="$1"

# --- validate ---
if [ -z "$APP_NAME" ]; then
  gum log --level error "Usage: doxo open <app-name>"
  exit 1
fi

if ! validate_name "$APP_NAME"; then
  gum log --level error "Invalid app name"
  exit 1
fi

APP_DIR="$BASE_DIR/$APP_NAME"

if [ ! -d "$APP_DIR" ]; then
  gum log --level error "App '$APP_NAME' does not exist"
  exit 1
fi

# --- load metadata ---
load_meta "$APP_DIR"

# --- determine URL ---
# public:  custom domain, HTTPS — https://myapp.yourdomain.com
# private: Tailscale MagicDNS hostname + path — https://device.ts.net/myapp
# none:    unexposed, fall back to localhost for local testing
if [ "$MODE" = "public" ] && [ -n "$DOMAIN" ]; then
  URL="https://$DOMAIN"
elif [ "$MODE" = "private" ] && [ -n "$DOMAIN" ]; then
  URL="https://$DOMAIN/$APP_NAME"
elif [ -n "$PORT" ]; then
  URL="http://localhost:$PORT"
else
  gum log --level error "No domain or port found for '$APP_NAME'"
  exit 1
fi

gum style --foreground 212 "Opening $URL"

# --- open browser ---
if exists_cmd xdg-open; then
  xdg-open "$URL" 2>/dev/null &
elif exists_cmd open; then
  open "$URL"
else
  gum log --level warn "No browser opener found — open manually:"
  gum style --foreground 212 "  $URL"
fi