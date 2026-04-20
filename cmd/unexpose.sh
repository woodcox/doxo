#!/usr/bin/env bash

source "$(dirname "$0")/../lib/common.sh"

ERRORS=()

APP_NAME="${1:-}"
FORCE="${2:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force)
      FORCE=true
      shift
      ;;
    *)
      if [ -z "$APP_NAME" ]; then
        APP_NAME="$1"
      fi
      shift
      ;;
  esac
done

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
APP_TAILNET_FILE="$SITES_DIR/tailnet/$APP_NAME.caddy"

if [ ! -d "$APP_DIR" ]; then
  echo "❌ App '$APP_NAME' does not exist"
  exit 1
fi

# --- load metadata ---
load_meta "$APP_DIR"

# --- detect mode from metadata ---
if [ -n "$DOMAIN" == *.ts.net* ]]; then
  MODE="tailnet"
elif [[ "$DOMAIN" == *.local ]]; then
  MODE="local"
elif [ -n "$DOMAIN" ]; then
  MODE="public"
else
  MODE="none"
fi

echo "=== Unexpose App ==="
echo "App:    $APP_NAME"
if [ MODE="tailnet"]; then
echo "Domain: ${DOMAIN/$APP_NAME:--}"
else
  echo "Domain: ${DOMAIN:--}"
fi
echo

# --- check exposure exists ---
if [ "$MODE" == "none" ]; then
  echo "ℹ️  No exposure found for '$APP_NAME'"
  exit 0
fi

if [ "$MODE" == "tailnet" ] && [ ! -f "$APP_TAILNET_FILE" ]; then
  echo "ℹ️  No tailnet exposure found for '$APP_NAME'"
  exit 0
fi

if [ "$MODE" != "tailnet" ] && [ ! -f "$SITE_FILE" ]; then
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

# --- remove based on mode ---
if [ "$MODE" == "tailnet" ]; then
  echo "Removing tailnet handle..."
  rm "$APP_TAILNET_FILE" || ERRORS+=("Failed to remove $APP_TAILNET_FILE")
  echo "Tailnet handle removed"

  # --- remove tailnet.caddy if no apps left ---
  if [ -z "$(ls -A "$SITES_DIR/tailnet/" 2>/dev/null)" ]; then
    echo "No tailnet apps remaining, removing tailnet.caddy..."
    rm -f "$SITES_DIR/tailnet.caddy" || ERRORS+=("Failed to remove tailnet.caddy")
  fi

else
  echo "Removing Caddy site..."
  rm "$SITE_FILE" || ERRORS+=("Failed to remove $SITE_FILE")
  echo "Caddy site removed"

  # --- remove hosts entry for local mode ---
  if [ "$MODE" == "local" ]; then
    remove_from_hosts "$DOMAIN" || ERRORS+=("Failed to update /etc/hosts")
  fi
fi

# --- update metadata ---
update_meta "DOMAIN" "" || ERRORS+=("Failed to update .meta")
update_meta "PATH" "" || ERRORS+=("Failed to update .meta")

# --- reload caddy ---
reload_caddy || ERRORS+=("Caddy reload failed")

report_errors "$APP_NAME ($DOMAIN)" "unexposed" "${ERRORS[@]}"