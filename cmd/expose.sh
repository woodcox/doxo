#!/usr/bin/env bash

source "$(dirname "$0")/../lib/common.sh"

ERRORS=()

APP_NAME="${1:-}"
EXPOSE_TARGET="${2:-}"

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


# --- guard container port ---
if [ -z "$CONTAINER_PORT" ]; then
  CONTAINER_PORT=$(prompt "Container port" "80")
fi

# --- determine local/tailnet/domain mode ---
MODE="public"

case "$EXPOSE_TARGET" in
  --local)
    MODE="local"
    DOMAIN="$APP_NAME.local"
    ;;
  --tailnet)
    MODE="tailnet"

    # detect tailnet domain
    if command -v jq &>/dev/null; then
      TAILNET_DOMAIN=$(tailscale status --json 2>/dev/null | jq -r '.MagicDNSSuffix')
    else
      TAILNET_DOMAIN=$(tailscale status --json 2>/dev/null | grep -o '"MagicDNSSuffix":[^,]*' | cut -d'"' -f4)
    fi

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
    DOMAIN="$EXPOSE_TARGET"
    ;;
esac

echo "=== Expose App ==="
echo "App:    $APP_NAME"
echo "Mode:   $MODE"
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
  remove_from_hosts "$APP_NAME.local" || ERRORS+=("Failed to update /etc/hosts")
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
  cat <<EOF > "$SITE_FILE" || ERRORS+=("Failed to write $SITE_FILE")
$DOMAIN {
  reverse_proxy $APP_NAME:$CONTAINER_PORT
}
EOF
fi

# --- local mode: update hosts ---
if [ "$MODE" == "local" ]; then
  add_to_hosts "$DOMAIN" || ERRORS+=("Failed to update /etc/hosts")
fi

# --- update metadata with the current domain --- 
update_meta "DOMAIN" "$DOMAIN" || ERRORS+=("Failed to update .meta")

# --- reload caddy ---
reload_caddy || ERRORS+=("Caddy reload failed")

# --- result ---
report_errors "$APP_NAME" "exposed" "${ERRORS[@]}"

echo "URL:"
echo "  http://$DOMAIN"
echo