#!/usr/bin/env bash

source "$(dirname "$0")/../lib/common.sh"

# --- preload docker state once ---
DOCKER_PS=$(docker ps --format '{{.Names}}|{{.Status}}')
DOCKER_PS_ALL=$(docker ps -a --format '{{.Names}}|{{.Status}}')

declare -A STATUS_MAP
declare -A UPTIME_MAP

while IFS='|' read -r NAME STATUS; do
  [ -z "$NAME" ] && continue
  if [[ "$STATUS" == Up* ]]; then
    STATUS_MAP["$NAME"]="🟢 running"
    UPTIME_MAP["$NAME"]="${STATUS#Up }"
  fi
done <<< "$DOCKER_PS"

while IFS='|' read -r NAME STATUS; do
  [ -z "$NAME" ] && continue
  if [ -z "${STATUS_MAP[$NAME]}" ]; then
    if [[ "$STATUS" == Exited* ]]; then
      STATUS_MAP["$NAME"]="🔴 stopped"
    else
      STATUS_MAP["$NAME"]="⚪ none"
    fi
    UPTIME_MAP["$NAME"]="-"
  fi
done <<< "$DOCKER_PS_ALL"

# --- check for any apps ---
shopt -s nullglob
app_dirs=("$BASE_DIR"/*/)
shopt -u nullglob

HAS_APPS=false
for dir in "${app_dirs[@]}"; do
  APP_NAME=$(basename "$dir")
  is_protected "$APP_NAME" && continue
  [ -f "$dir/.meta" ] && HAS_APPS=true && break
done

if ! $HAS_APPS; then
  gum style --foreground 240 "No apps found. Run: doxo create"
  exit 0
fi

# --- header ---
gum style \
  --foreground 212 --border-foreground 212 --border rounded \
  --padding "0 1" "  doxo list"
echo

# --- build CSV for gum table ---
# Use | as separator to avoid conflicts with image names containing colons
CSV="APP|STATUS|PORT|IMAGE|UPTIME|MODE|DOMAIN"

for dir in "$BASE_DIR"/*/; do
  [ -d "$dir" ] || continue

  APP_NAME=$(basename "$dir")
  is_protected "$APP_NAME" && continue
  [ ! -f "$dir/.meta" ] && continue

  load_meta "$dir"

  STATUS="${STATUS_MAP[$APP_NAME]:-⚪ none}"
  UPTIME="${UPTIME_MAP[$APP_NAME]:--}"
  DISPLAY_MODE="${MODE:-none}"
  if [ "$MODE" = "private" ] && [ -n "$DOMAIN" ]; then
    DISPLAY_DOMAIN="$DOMAIN/$APP_NAME"
  else
    DISPLAY_DOMAIN="${DOMAIN:--}"
  fi

  CSV+=$'\n'"${APP_NAME}|${STATUS}|${PORT:--}|${IMAGE:--}|${UPTIME}|${DISPLAY_MODE}|${DISPLAY_DOMAIN}"
done

# --- render ---
echo "$CSV" | gum table --separator "|" \
  --columns "APP,STATUS,PORT,IMAGE,UPTIME,MODE,DOMAIN" \
  --widths "16,12,6,24,10,9,40"

echo