#!/usr/bin/env bash

source "$(dirname "$0")/../lib/common.sh"

ERRORS=()

APP_NAME="${1:-}"
RECREATE="${2:-}"

# --- input ---
if [ -z "$APP_NAME" ]; then
  echo "Usage: doxo restart <app-name> [--recreate]"
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

echo "=== Restart App ==="
echo "App:    $APP_NAME"
echo "Image:  $IMAGE"
echo "Domain: $DOMAIN"
echo

cd "$APP_DIR"

if [ "$RECREATE" == "--recreate" ]; then
  echo "🔄 Recreating container (down + up)..."
  docker compose down || ERRORS+=("docker compose down failed")
  docker compose up -d || ERRORS+=("docker compose up failed")
else
  echo "🔄 Restarting container..."
  docker compose restart || ERRORS+=("docker compose restart failed")
fi

report_errors "$APP_NAME" "restarted" "${ERRORS[@]}"
