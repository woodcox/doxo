#!/usr/bin/env bash

source "$(dirname "$0")/../lib/common.sh"

ERRORS=()

APP_NAME="${1:-}"
FORCE="${2:-}"

# --- input ---
if [ -z "$APP_NAME" ]; then
  echo "Usage: doxo unexpose <app-name> [--force]"
  exit 1
fi

if ! validate_name "$APP_NAME"; then
  echo "❌ Invalid app name"
  exit 1
fi

APP_DIR="$BASE_DIR/$APP_NAME"
SITE_FILE="$SITES_DIR/$APP_NAME.caddy"

# --- load metadata ---
load_meta "$APP_DIR"

echo "=== Unexpose App ==="
echo "App:    $APP_NAME"
echo "Domain: $DOMAIN"
echo

# --- check existence ---
if [ ! -f "$SITE_FILE" ]; then
  echo "ℹ️  No exposure found for '$APP_NAME'"
  exit 0
fi

# --- confirm ---
if [ "$FORCE" != "--force" ]; then
  if ! yes_no "Remove exposure for '$APP_NAME' ($DOMAIN)?"; then
    echo "Cancelled"
    exit 0
  fi
fi

# --- remove site ---
echo "Removing Caddy site..."
rm "$SITE_FILE" || ERRORS+=("Failed to remove $SITE_FILE")
echo "Caddy site removed"

reload_caddy || ERRORS+=("Caddy reload failed")

report_errors "$APP_NAME" "unexposed"