#!/usr/bin/env bash

source "$(dirname "$0")/../lib/common.sh"

APP_NAME="$1"

# --- input ---
if [ -z "$APP_NAME" ]; then
  echo "Usage: doxo open <app-name>"
  exit 1
fi

if ! validate_name "$APP_NAME"; then
  echo "❌ Invalid app name"
  exit 1
fi

APP_DIR="$BASE_DIR/$APP_NAME"

if [ ! -d "$APP_DIR" ]; then
  echo "❌ App '$APP_NAME' does not exist"
  exit 1
fi

# --- load metadata ---
load_meta "$APP_DIR"

# --- determine URL ---
if [ -n "$DOMAIN" ] && [ "$DOMAIN" != "-" ]; then
  # use http for .local domains, https for real domains
  if [[ "$DOMAIN" == *.local ]]; then
    URL="http://$DOMAIN"
  else
    URL="https://$DOMAIN"
  fi
elif [ -n "$PORT" ] && [ "$PORT" != "-" ]; then
  # fall back to port-based URL
  URL="http://$(get_local_ip):$PORT"
else
  echo "❌ No domain or port found for '$APP_NAME'"
  exit 1
fi

echo "🌐 Opening $URL..."

# --- open browser ---
if command -v xdg-open >/dev/null 2>&1; then
  xdg-open "$URL"
elif command -v open >/dev/null 2>&1; then
  open "$URL"
else
  echo "👉 Open manually: $URL"
fi