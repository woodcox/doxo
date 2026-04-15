#!/usr/bin/env bash

source "$(dirname "$0")/../lib/common.sh"

ERRORS=()

# --- input ---
APP_NAME="${1:-}"
PORT="${2:-}"
IMAGE="${3:-}"
INTERNAL_PORT=""

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

if [ -z "$PORT" ]; then
  PORT=$(prompt "External port" "8080")
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
      INTERNAL_PORT=80
      ;;
    2)
      IMAGE="denoland/deno:latest"
      INTERNAL_PORT=8000
      ;;
    3)
      read -rp "Enter image: " IMAGE
      INTERNAL_PORT=$(prompt "Internal container port" "80")
      ;;
    *)
      IMAGE="caddy:alpine"
      INTERNAL_PORT=80
      ;;
  esac
fi

ADD_CADDY=false
if yes_no "Add Caddy route?"; then
  ADD_CADDY=true
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
INTERNAL_PORT=$INTERNAL_PORT
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

  cat <<EOF > "$APP_DIR/docker-compose.yml"
version: "3.8"

services:
  $APP_NAME:
    image: $IMAGE
    container_name: $APP_NAME
    restart: unless-stopped
$(if [[ "$IMAGE" == denoland/deno* ]]; then echo "    command: [\"run\", \"--allow-net\", \"--allow-read\", \"--allow-env\", \"/app/main.ts\"]"; fi)
    ports:
      - "$PORT:$INTERNAL_PORT"
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
Deno.serve({ port: $INTERNAL_PORT }, (req: Request) => {
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
  reverse_proxy $APP_NAME:$INTERNAL_PORT
}
EOF
    fi

    [ $? -ne 0 ] && ERRORS+=("Failed to write $SITE_FILE")

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

report_errors "$APP_NAME" "created"

echo "Access:"
echo "  http://$IP:$PORT"
if $ADD_CADDY; then
  echo "  http://$DOMAIN (if hosts file configured)"
fi
echo