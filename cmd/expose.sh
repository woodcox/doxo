#!/usr/bin/env bash

source "$(dirname "$0")/../lib/common.sh"

ERRORS=()

APP_NAME="${1:-}"
ARG2="${2:-}"

# --- input ---
if [ -z "$APP_NAME" ]; then
  echo "Usage: doxo expose <app-name> [--local|--tailnet|domain]"
  exit 1
fi



APP_DIR="$BASE_DIR/$APP_NAME"
SITE_FILE="$SITES_DIR/$APP_NAME.caddy"

if [ ! -d "$APP_DIR" ]; then
  echo "❌ App '$APP_NAME' does not exist"
  exit 1
fi

if [ ! -f "$APP_DIR/.meta" ]; then
  echo "❌ No .meta file found — was this app created with doxo create?"
  exit 1
fi

# --- load metadata ---
load_meta "$APP_DIR"

# --- determine local/tailnet/domain mode ---
MODE="public"

case "$ARG2" in
  --local)
    MODE="local"
    DOMAIN="$APP_NAME.local"
    ;;
  --tailnet)
    MODE="tailnet"

    # detect tailnet domain
    TAILNET_DOMAIN=$(tailscale status --json 2>/dev/null | grep -o '"MagicDNSSuffix":[^,]*' | cut -d'"' -f4)

    if [ -z "$TAILNET_DOMAIN" ]; then
      echo "❌ Could not detect Tailscale domain (is tailscale running?)"
      exit 1
    fi

    DOMAIN="$APP_NAME.$TAILNET_DOMAIN"
    ;;
  "")
    DOMAIN=$(prompt "Domain" "$DOMAIN")
    ;;
  *)
    DOMAIN="$ARG2"
    ;;
esac

echo "=== Expose App ==="
echo "App:    $APP_NAME"
echo "Image:  $IMAGE"
echo "Domain: $DOMAIN"
echo

# --- create/update site ---
mkdir -p "$SITES_DIR" || ERRORS+=("Failed to create $SITES_DIR")

if [ -f "$SITE_FILE" ]; then
  echo "⚠️  Exposure already exists for '$APP_NAME'"
  if ! yes_no "Overwrite?"; then
    echo "Cancelled"
    exit 0
  fi
fi

echo "Creating Caddy site: $SITE_FILE"

if [[ "$IMAGE" == "caddy:alpine" ]]; then
  cat <<EOF > "$SITE_FILE"
$DOMAIN {
  root * /srv
  file_server
}
EOF
else
  cat <<EOF > "$SITE_FILE"
$DOMAIN {
  reverse_proxy $APP_NAME:$CONTAINER_PORT
}
EOF
fi

[ $? -ne 0 ] && ERRORS+=("Failed to write $SITE_FILE")

# --- local mode: update hosts ---
if [ "$MODE" == "local" ]; then
  add_to_hosts "$DOMAIN" || ERRORS+=("Failed to update /etc/hosts")
fi

# --- update metadata with the current domain --- 
update_meta "DOMAIN" "$DOMAIN" || ERRORS+=("Failed to update .meta")

# --- reload caddy ---
reload_caddy || ERRORS+=("Caddy reload failed")

# --- result ---
report_errors "$APP_NAME" "exposed"

echo "URL:"
echo "  http://$DOMAIN"
echo