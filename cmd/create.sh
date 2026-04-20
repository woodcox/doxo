#!/usr/bin/env bash

# Usage: doxo create [APP_NAME] [--port PORT] [--image IMAGE] [--no-caddy]

source "$(dirname "$0")/../lib/common.sh"

ERRORS=()

# --- input ---
APP_NAME="${1:-}"
PORT=""
CONTAINER_PORT=""
IMAGE=""
ADD_CADDY=true

# --- parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-caddy)
      ADD_CADDY=false
      shift
      ;;
    --port)
      PORT="$2"
      shift 2
      ;;
    --image)
      IMAGE="$2"
      shift 2
      ;;
    *)
      if [ -z "$APP_NAME" ]; then
        APP_NAME="$1"
      fi
      shift
      ;;
  esac
done

echo "=== Create Docker App ==="

if [ -z "$APP_NAME" ]; then
  APP_NAME=$(prompt "App name" "myapp")
fi

if ! validate_name "$APP_NAME"; then
  echo "❌ Invalid app name. Use letters, numbers, - or _"
  exit 1
fi

if is_protected "$APP_NAME"; then
  echo "❌ '$APP_NAME' is a protected name"
  exit 1
fi

# --- only prompt for PORT if skipping Caddy ---
if ! $ADD_CADDY; then
  if [ -z "$PORT" ]; then
    PORT=$(prompt "External port" "8080")
  fi
fi

# --- warn if --port passed with Caddy enabled ---
if $ADD_CADDY && [ -n "$PORT" ]; then
  echo "⚠️  --port is ignored when Caddy is enabled"
fi

# --- image selection ---
if [ -z "$IMAGE" ]; then
  echo "Choose an image:"
  echo "1) caddy (static site)"
  echo "2) deno (server)"
  echo "3) custom"
  read -rp "Select option [1]: " choice
  choice=${choice:-1}

  case "$choice" in
    1)
      IMAGE="caddy:alpine"
      CONTAINER_PORT=80
      ;;
    2)
      IMAGE="denoland/deno:latest"
      CONTAINER_PORT=8000
      ;;
    3)
      read -rp "Enter image: " IMAGE
      CONTAINER_PORT=$(prompt "Container port" "80")
      ;;
    *)
      IMAGE="caddy:alpine"
      CONTAINER_PORT=80
      ;;
  esac
else
  # --- infer CONTAINER_PORT from image flag ---
  case "$IMAGE" in
    caddy:alpine)
      CONTAINER_PORT=80
      ;;
    denoland/deno*)
      CONTAINER_PORT=8000
      ;;
    *)
      CONTAINER_PORT=$(prompt "Container port" "80")
      ;;
  esac
fi

# --- caddy info ---
if $ADD_CADDY; then
  echo "ℹ️  Caddy route will be created for $APP_NAME.local"
  echo "   Use --no-caddy to skip"
else
  echo "ℹ️  Skipping Caddy route (--no-caddy)"
fi

APP_DIR="$BASE_DIR/$APP_NAME"
SITE_FILE="$SITES_DIR/$APP_NAME.caddy"
DOMAIN="$APP_NAME.local"

echo "Creating app in $APP_DIR..."
mkdir -p "$APP_DIR/data" || ERRORS+=("Failed to create $APP_DIR/data")

# --- ensure docker network exists ---
if ! docker network inspect "$NETWORK" >/dev/null 2>&1; then
  echo "Creating docker network: $NETWORK"
  docker network create "$NETWORK" || ERRORS+=("Failed to create docker network: $NETWORK")
fi

# --- write metadata ---
cat <<EOF > "$APP_DIR/.meta"
IMAGE=$IMAGE
CONTAINER_PORT=$CONTAINER_PORT
PORT=$PORT
DOMAIN=$DOMAIN
CREATED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF
echo ".meta written" || ERRORS+=("Failed to write .meta")

# --- generate compose ---
if [ ! -f "$APP_DIR/docker-compose.yml" ]; then

  if [[ "$IMAGE" == "caddy:alpine" ]]; then
    VOLUMES="- ./data:/srv"
  elif [[ "$IMAGE" == denoland/deno* ]]; then
    VOLUMES="- ./data:/data
      - .:/app"
  else
    VOLUMES="- ./data:/data"
  fi

  # --- only expose port mapping if not using Caddy ---
  if $ADD_CADDY; then
    PORTS_BLOCK=""
  else
    PORTS_BLOCK="    ports:
      - \"$PORT:$CONTAINER_PORT\""
  fi

  cat <<EOF > "$APP_DIR/docker-compose.yml"

services:
  $APP_NAME:
    image: $IMAGE
    container_name: $APP_NAME
    restart: unless-stopped
$(if [[ "$IMAGE" == denoland/deno* ]]; then echo "    command: [\"run\", \"--allow-net\", \"--allow-read\", \"--allow-env\", \"/app/main.ts\"]"; fi)
$PORTS_BLOCK
    volumes:
      $VOLUMES
    networks:
      - $NETWORK

networks:
  $NETWORK:
    external: true
EOF

  echo "docker-compose.yml created" || ERRORS+=("Failed to write docker-compose.yml")
else
  echo "docker-compose.yml already exists, skipping"
fi

# --- scaffold deno entrypoint ---
if [[ "$IMAGE" == denoland/deno* ]]; then
  if [ ! -f "$APP_DIR/main.ts" ]; then
    cat <<EOF > "$APP_DIR/main.ts"
Deno.serve({ port: $CONTAINER_PORT }, (req: Request) => {
  const url = new URL(req.url);

  if (url.pathname === "/health") {
    return new Response("OK", { status: 200 });
  }

  return new Response("Hello from $APP_NAME", { status: 200 });
});
EOF
    echo "main.ts created" || ERRORS+=("Failed to write main.ts")
  else
    echo "main.ts already exists, skipping"
  fi
fi

# --- scaffold static index ---
if [[ "$IMAGE" == "caddy:alpine" ]]; then
  if [ ! -f "$APP_DIR/data/index.html" ]; then
    cat <<EOF > "$APP_DIR/data/index.html"
<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"><title>$APP_NAME</title></head>
<body><h1>$APP_NAME</h1></body>
</html>
EOF
    echo "index.html created" || ERRORS+=("Failed to write index.html")
  else
    echo "index.html already exists, skipping"
  fi
fi

# --- caddy snippet ---
if $ADD_CADDY; then
  mkdir -p "$SITES_DIR" || ERRORS+=("Failed to create $SITES_DIR")

  if [ ! -f "$SITE_FILE" ]; then
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

    # add to /etc/hosts
    add_to_hosts "$DOMAIN" || ERRORS+=("Failed to update /etc/hosts")
    reload_caddy || ERRORS+=("Caddy reload failed")
  else
    echo "Caddy site already exists, skipping"
  fi
fi

# --- start app ---
cd "$APP_DIR"
docker compose up -d || ERRORS+=("docker compose up failed for $APP_NAME")

# --- report ---
IP=$(hostname -I | awk '{print $1}')

report_errors "$APP_NAME" "created" "${ERRORS[@]}"

echo "Access:"
echo "======="
echo
if $ADD_CADDY; then
  echo "  http://$DOMAIN (your server only)"
  echo "  You may which to expose the app using doxo expose [app-name]"
else
  echo "  http://$IP:$PORT"
fi
echo