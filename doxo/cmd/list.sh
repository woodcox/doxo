#!/usr/bin/env bash

source "$(dirname "$0")/../lib/common.sh"

# --- preload docker data ---
DOCKER_PS=$(docker ps --format '{{.Names}}|{{.Status}}')
DOCKER_PS_ALL=$(docker ps -a --format '{{.Names}}|{{.Status}}')

declare -A STATUS_MAP
declare -A UPTIME_MAP

while IFS='|' read -r NAME STATUS; do
  [ -z "$NAME" ] && continue
  if [[ "$STATUS" == Up* ]]; then
    STATUS_MAP["$NAME"]="running"
    UPTIME_MAP["$NAME"]="${STATUS#Up }"
  fi
done <<< "$DOCKER_PS"

while IFS='|' read -r NAME STATUS; do
  [ -z "$NAME" ] && continue
  if [ -z "${STATUS_MAP[$NAME]}" ]; then
    if [[ "$STATUS" == Exited* ]]; then
      STATUS_MAP["$NAME"]="stopped"
    else
      STATUS_MAP["$NAME"]="none"
    fi
    UPTIME_MAP["$NAME"]="-"
  fi
done <<< "$DOCKER_PS_ALL"

status_icon() {
  case "$1" in
    running) echo "🟢" ;;
    stopped) echo "🔴" ;;
    *)       echo "⚪" ;;
  esac
}

# --- header ---
printf "\n%-20s %-10s %-10s %-22s %-10s %-30s\n" \
  "APP" "  STATUS" "PORT" "IMAGE" "UPTIME" "DOMAIN"
printf "%-20s %-10s %-10s %-22s %-10s %-30s\n" \
  "--------------------" "----------" "----------" "----------------------" "----------" "------------------------------"

# --- loop apps ---
for dir in "$BASE_DIR"/*/; do
  [ -d "$dir" ] || continue

  APP_NAME=$(basename "$dir")
  is_protected "$APP_NAME" && continue

  # --- load metadata ---
  load_meta "$dir"

  STATUS="${STATUS_MAP[$APP_NAME]:-none}"
  UPTIME="${UPTIME_MAP[$APP_NAME]:--}"
  ICON=$(status_icon "$STATUS")

  printf "%-20s %s %-8s %-10s %-22s %-10s %-30s\n" \
    "$APP_NAME" "$ICON" "$STATUS" "$PORT" "$IMAGE" "$UPTIME" "$DOMAIN"

done

echo