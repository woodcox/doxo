#!/usr/bin/env bash

source "$(dirname "$0")/../lib/common.sh"

ERRORS=()

APP_NAME="${1:-}"

# --- input ---
if [ -z "$APP_NAME" ]; then
  echo "Usage: doxo delete <app-name>"
  exit 1
fi

if ! validate_name "$APP_NAME"; then
  echo "❌ Invalid app name"
  exit 1
fi

if is_protected "$APP_NAME"; then
  echo "❌ '$APP_NAME' is a protected app and cannot be deleted with this tool"
  exit 1
fi

APP_DIR="$BASE_DIR/$APP_NAME"
SITE_FILE="$SITES_DIR/$APP_NAME.caddy"

if [ ! -d "$APP_DIR" ]; then
  echo "❌ App '$APP_NAME' does not exist"
  exit 1
fi

# --- load metadata ---
load_meta "$APP_DIR"

echo "=== Delete Docker App ==="
echo "App:       $APP_NAME"
echo "Image:     $IMAGE"
echo "Domain:    $DOMAIN"
echo "Directory: $APP_DIR"
[ -f "$SITE_FILE" ] && echo "Caddy:     $SITE_FILE"
echo

if ! yes_no "⚠️  Delete '$APP_NAME'? This cannot be undone."; then
  echo "Cancelled"
  exit 0
fi

echo

# --- stop & remove containers ---
if [ -d "$APP_DIR" ]; then
  echo "Stopping containers..."
  (
    cd "$APP_DIR"
    docker compose down 2>&1 || ERRORS+=("docker compose down failed")
  )
  echo "Containers stopped"
fi

# --- remove app directory ---
if [ -d "$APP_DIR" ]; then
  echo "Removing app directory..."
  rm -rf "$APP_DIR" || ERRORS+=("Failed to remove $APP_DIR")
  echo "Directory removed"
fi

# --- remove caddy site ---
if [ -f "$SITE_FILE" ]; then
  echo "Removing Caddy site..."
  rm "$SITE_FILE" || ERRORS+=("Failed to remove $SITE_FILE")
  echo "Caddy site removed"
  reload_caddy || ERRORS+=("Caddy reload failed")
else
  echo "No Caddy site found, skipping"
fi

# --- remove from /etc/hosts if local domain ---
if [[ "$DOMAIN" == *.local ]]; then
  echo "🧹 Removing $DOMAIN from /etc/hosts..."
  remove_from_hosts "$DOMAIN" || ERRORS+=("Failed to update /etc/hosts")
else
  echo "No local domain to clean up"
fi

report_errors "$APP_NAME" "deleted" "${ERRORS[@]}"
