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

# --- dynamic terminal width ---
  TERM_WIDTH=$(tput cols 2>/dev/null || echo 120)

  APP_W=20
  STATUS_W=10
  PORT_W=10
  IMAGE_W=22
  UPTIME_W=10
  MODE_W=10

  FIXED_WIDTH=$((APP_W + STATUS_W + PORT_W + IMAGE_W + UPTIME_W + MODE_W + 7))
  DOMAIN_W=$((TERM_WIDTH - FIXED_WIDTH))

  # --- minimum width safeguard ---
  if [ "$DOMAIN_W" -lt 15 ]; then
    DOMAIN_W=15
  fi

# --- header ---
printf "\n%-${APP_W}s %-10s %-${PORT_W}s %-${IMAGE_W}s %-${UPTIME_W}s %-${MODE_W}s %-${DOMAIN_W}s\n" \
  "APP" "STATUS" "PORT" "IMAGE" "UPTIME" "MODE" "DOMAIN"

# --- seperator ---
printf "%-${APP_W}s %-10s %-${PORT_W}s %-${IMAGE_W}s %-${UPTIME_W}s %-${MODE_W}s %-${DOMAIN_W}s\n" \
  "--------------------" "----------" "----------" "----------------------" "----------" "----------" "------------------------------"

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
  STATUS_DISPLAY="$ICON $STATUS"


  # --- determine mode ---
  if [[ "$DOMAIN" == *.local ]]; then
    MODE="local"
  elif [[ "$DOMAIN" == *.ts.net ]]; then
    MODE="tailnet"
  elif [ -n "$DOMAIN" ]; then
    MODE="public"
  else
    MODE="-"
  fi

  # --- domain display ---
  if [ -z "$DOMAIN" ]; then
    DOMAIN_DISPLAY="-"
  else
    if [ ${#DOMAIN} -gt "$DOMAIN_W" ]; then
      DOMAIN_DISPLAY="${DOMAIN:0:$((DOMAIN_W-3))}..."
    else
      DOMAIN_DISPLAY="$DOMAIN"
    fi
  fi

  # --- row ---
  printf "%-${APP_W}s %-10s %-${PORT_W}s %-${IMAGE_W}s %-${UPTIME_W}s %-${MODE_W}s %-${DOMAIN_W}s\n" \
  "$APP_NAME" "$STATUS_DISPLAY" "$PORT" "$IMAGE" "$UPTIME" "$MODE" "$DOMAIN_DISPLAY"
  
done

echo