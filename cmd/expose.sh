#!/usr/bin/env bash

source "$(dirname "$0")/../lib/common.sh"

ERRORS=()

# --- parse args ---
APP_NAME=""
EXPOSE_TARGET=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --local|--tailnet)
      EXPOSE_TARGET="$1"
      shift
      ;;
    *)
      if [ -z "$APP_NAME" ]; then
        APP_NAME="$1"
      else
        EXPOSE_TARGET="$1"
      fi
      shift
      ;;
  esac
done

# --- input ---
if [ -z "$APP_NAME" ]; then
  echo "Usage: doxo expose <app-name> [--local|--tailnet|domain]"
  exit 1
fi

APP_DIR="$BASE_DIR/$APP_NAME"
SITE_FILE="$SITES_DIR/$APP_NAME.caddy"
TAILNET_DIR="$SITES_DIR/tailnet"
TAILNET_SITE_FILE="$SITES_DIR/tailnet.caddy"
APP_TAILNET_FILE="$TAILNET_DIR/$APP_NAME.caddy"

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

# --- determine mode ---
MODE="public"

case "$EXPOSE_TARGET" in
  --local)
    MODE="local"
    DOMAIN="$APP_NAME.local"
    ;;
  --tailnet)
    MODE="tailnet"

    # --- validate tailscale ---
    if ! exists_cmd tailscale; then
      echo "❌ Tailscale is not installed — run: doxo services tailscale install"
      exit 1
    fi

    # --- check tailscale authenticated ---
    if ! tailscale status >/dev/null 2>&1; then
      echo "❌ Tailscale is not running or authenticated"
      exit 1
    fi

    # --- detect machine name and domain ---
    if command -v jq &>/dev/null; then
      TAILNET_DOMAIN=$(tailscale status --json 2>/dev/null | jq -r '.MagicDNSSuffix')
      TAILNET_MACHINE=$(tailscale status --json 2>/dev/null | jq -r '.Self.DNSName | rtrimstr(".")')
    else
      TAILNET_DOMAIN=$(tailscale status --json 2>/dev/null | grep -o '"MagicDNSSuffix":[^,]*' | cut -d'"' -f4)
      TAILNET_MACHINE=$(tailscale status --json 2>/dev/null | grep -o '"DNSName":[^,]*' | head -1 | cut -d'"' -f4 | sed 's/\.$//')
    fi

    if [ -z "$TAILNET_DOMAIN" ] || [ -z "$TAILNET_MACHINE" ]; then
      echo "❌ Could not detect Tailscale domain (is tailscale authenticated?)"
      exit 1
    fi

    DOMAIN="$TAILNET_MACHINE.$TAILNET_DOMAIN"
    APP_PATH="/$APP_NAME"
    ;;
  "")
    DOMAIN=$(prompt "Domain" "$DOMAIN")
    ;;
  *)
    DOMAIN="$EXPOSE_TARGET"
    ;;
esac

# --- validate container is running ---
if ! docker ps --format '{{.Names}}' | grep -q "^$APP_NAME$"; then
  echo "❌ Container '$APP_NAME' is not running — start it first with: doxo start $APP_NAME"
  exit 1
fi

echo "=== Expose App ==="
echo "App:    $APP_NAME"
echo "Mode:   $MODE"
echo "Image:  $IMAGE"
if [ "$MODE" == "tailnet" ]; then
  echo "URL:    https://$DOMAIN/$APP_NAME"
else
  echo "Domain: $DOMAIN"
fi
echo

# --- create sites dir ---
mkdir -p "$SITES_DIR" || ERRORS+=("Failed to create $SITES_DIR")

# ---tailnet mode ---
if [ "$MODE" == "tailnet" ]; then

  # --- ensure static tailnet domain block exists ---
  if [ ! -f "$TAILNET_SITE_FILE" ]; then
    cat <<EOF > "$TAILNET_SITE_FILE" || ERRORS+=("Failed to write $TAILNET_SITE_FILE")
$DOMAIN {
  import $CADDY_SITES_DIR/tailnet/*
}
EOF
  fi

  mkdir -p "$TAILNET_DIR" || ERRORS+=("Failed to create $TAILNET_DIR")

  # --- check if already exposed ---
  if [ -f "$APP_TAILNET_FILE" ]; then
    echo "⚠️  Tailnet exposure already exists for '$APP_NAME'"
    if ! yes_no "Overwrite?"; then
      echo "Cancelled"
      exit 0
    fi
  fi

  echo "Creating tailnet handle: $APP_TAILNET_FILE"

  cat <<EOF > "$APP_TAILNET_FILE" || ERRORS+=("Failed to write $APP_TAILNET_FILE")
handle_path /$APP_NAME/* {
  reverse_proxy $APP_NAME:$CONTAINER_PORT
}

handle /$APP_NAME {
  redir /$APP_NAME/ 308
}
EOF

  update_meta "DOMAIN" "$DOMAIN" || ERRORS+=("Failed to update .meta")
  update_meta "PATH" "$APP_PATH" || ERRORS+=("Failed to update .meta")

else
  # --- local/public mode ---
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
    cat <<EOF > "$SITE_FILE" || ERRORS+=("Failed to write $SITE_FILE")
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

  update_meta "DOMAIN" "$DOMAIN" || ERRORS+=("Failed to update .meta")
fi

# --- reload caddy ---
reload_caddy || ERRORS+=("Caddy reload failed")

# --- result ---
report_errors "$APP_NAME" "exposed" "${ERRORS[@]}"

echo "URL:"
if [ "$MODE" == "tailnet" ]; then
  echo "  https://$DOMAIN/$APP_NAME"
else
  echo "  http://$DOMAIN"
fi
echo