#!/usr/bin/env bash

source "$(dirname "$0")/../lib/common.sh"

ERRORS=()
APP_NAME=""
FORCE=false

# --- parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=true; shift ;;
    *)
      if [ -z "$APP_NAME" ]; then APP_NAME="$1"; fi
      shift
      ;;
  esac
done

# --- validate ---
if [ -z "$APP_NAME" ]; then
  gum log --level error "Usage: doxo unexpose <app-name> [--force]"
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

if [ ! -f "$APP_DIR/.meta" ]; then
  gum log --level error "No .meta file found — was this app created with doxo create?"
  exit 1
fi

# --- load metadata ---
load_meta "$APP_DIR"

# --- check exposure exists ---
if [ "${MODE:-none}" = "none" ] || [ -z "$DOMAIN" ]; then
  gum log --level warn "'$APP_NAME' is not currently exposed"
  exit 0
fi

# --- header ---
gum style \
  --foreground 212 --border-foreground 212 --border rounded \
  --padding "0 1" "  doxo unexpose"

echo
gum style --foreground 240 "  App     $(gum style --foreground 212 "$APP_NAME")"
gum style --foreground 240 "  Mode    $(gum style --foreground 212 "$MODE")"
gum style --foreground 240 "  Domain  $(gum style --foreground 212 "$DOMAIN")"
echo

# --- confirm ---
if [ "$FORCE" != true ]; then
  gum confirm "Remove exposure for '$APP_NAME'?" || { echo "Cancelled"; exit 0; }
fi

# --- remove tailscale funnel or serve ---
if [ "$MODE" = "public" ]; then
  gum spin --spinner dot --title "Removing Tailscale Funnel for $APP_NAME..." -- \
    tailscale funnel --bg --set-path "/$APP_NAME" off \
    || ERRORS+=("tailscale funnel off failed")
elif [ "$MODE" = "private" ]; then
  gum spin --spinner dot --title "Removing Tailscale Serve for $APP_NAME..." -- \
    tailscale serve --bg --set-path "/$APP_NAME" off \
    || ERRORS+=("tailscale serve off failed")
fi

# --- remove domain label from compose and increment deployment-id ---
COMPOSE_FILE="$APP_DIR/docker-compose.yml"
if [ -f "$COMPOSE_FILE" ]; then
  sed -i '/dev.haloy.domain/d' "$COMPOSE_FILE" \
    || ERRORS+=("Failed to remove domain label from docker-compose.yml")
  increment_deployment_id "$COMPOSE_FILE" \
    || ERRORS+=("Failed to increment deployment-id")
fi

# --- restart container so haloyd stops routing to it ---
gum spin --spinner dot --title "Restarting $APP_NAME..." -- \
  bash -c "cd '$APP_DIR' && docker compose up -d --force-recreate" \
  || ERRORS+=("docker compose up failed")

# --- update .meta ---
update_meta "DOMAIN" "" || ERRORS+=("Failed to update .meta DOMAIN")
update_meta "MODE"   "none" || ERRORS+=("Failed to update .meta MODE")

# --- report ---
report_errors "$APP_NAME" "unexposed" "${ERRORS[@]}"