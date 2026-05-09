#!/usr/bin/env bash

# Usage: doxo create [APP_NAME] [--port PORT] [--image IMAGE]

source "$(dirname "$0")/../lib/common.sh"

ERRORS=()

# --- input ---
APP_NAME="${1:-}"
PORT=""
CONTAINER_PORT=""
IMAGE=""

# --- parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
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
# --- header ---
gum style \
  --foreground 212 --border-foreground 212 --border rounded \
  --padding "0 1" "  doxo create"

# --- app name ---
if [ -z "$APP_NAME" ]; then
  APP_NAME=$(gum input \
    --placeholder "my-app" \
    --prompt "App name › ")
fi

[ -z "$APP_NAME" ] && gum log --level error "App name is required" && exit 1

if ! validate_name "$APP_NAME"; then
  gum log --level error "Invalid app name — use letters, numbers, - or _"
  exit 1
fi

if is_protected "$APP_NAME"; then
  gum log --level error "'$APP_NAME' is a protected name"
  exit 1
fi

if app_exists "$APP_NAME"; then
  gum log --level error "App '$APP_NAME' already exists"
  exit 1
fi

# --- image selection ---
if [ -z "$IMAGE" ]; then
  IMAGE=$(gum choose \
    --header "Choose an image type:" \
    "denoland/deno:latest" \
    "nginx:alpine" \
    "custom")

  if [ "$IMAGE" = "custom" ]; then
    IMAGE=$(gum input \
      --placeholder "e.g. node:22-alpine" \
      --prompt "Image › ")
    [ -z "$IMAGE" ] && gum log --level error "Image is required" && exit 1
  fi
fi

# --- infer or prompt container port ---
case "$IMAGE" in
  denoland/deno*) CONTAINER_PORT=8000 ;;
  nginx*)         CONTAINER_PORT=80   ;;
  *)
    CONTAINER_PORT=$(gum input \
      --placeholder "8080" \
      --prompt "Container port › ")
    CONTAINER_PORT=${CONTAINER_PORT:-8080}
    ;;
esac

# --- host port ---
if [ -z "$PORT" ]; then
  PORT=$(gum input \
    --placeholder "8080" \
    --prompt "Host port › ")
  PORT=${PORT:-8080}
fi

# --- confirm ---
echo
gum style --foreground 240 "  App     $(gum style --foreground 212 "$APP_NAME")"
gum style --foreground 240 "  Image   $(gum style --foreground 212 "$IMAGE")"
gum style --foreground 240 "  Port    $(gum style --foreground 212 "$PORT → $CONTAINER_PORT")"
echo

gum confirm "Create app?" || exit 0

# --- create app dir ---
APP_DIR="$BASE_DIR/$APP_NAME"

gum spin --spinner dot --title "Setting up $APP_NAME..." -- \
  mkdir -p "$APP_DIR/data" \
  || ERRORS+=("Failed to create $APP_DIR/data")

# --- ensure haloy docker network exists ---
if ! docker network inspect haloy >/dev/null 2>&1; then
  gum spin --spinner dot --title "Creating docker network: haloy..." -- \
    docker network create haloy \
    || ERRORS+=("Failed to create docker network: haloy")
fi

# --- write .meta ---
cat <<EOF > "$APP_DIR/.meta"
IMAGE=$IMAGE
CONTAINER_PORT=$CONTAINER_PORT
PORT=$PORT
DOMAIN=
MODE=none
CREATED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF

# --- generate docker-compose.yml ---
if [ ! -f "$APP_DIR/docker-compose.yml" ]; then

  case "$IMAGE" in
    denoland/deno*)
      VOLUMES="      - ./data:/data
      - .:/app"
      COMMAND='    command: ["run", "--allow-net", "--allow-read", "--allow-env", "/app/main.ts"]'
      ;;
    nginx*)
      VOLUMES="      - ./data:/usr/share/nginx/html:ro"
      COMMAND=""
      ;;
    *)
      VOLUMES="      - ./data:/data"
      COMMAND=""
      ;;
  esac

  cat <<EOF > "$APP_DIR/docker-compose.yml"
services:
  $APP_NAME:
    image: $IMAGE
    container_name: $APP_NAME
    restart: unless-stopped
${COMMAND:+$COMMAND}
    ports:
      - "$PORT:$CONTAINER_PORT"
    volumes:
$VOLUMES
    networks:
      - haloy
    labels:
      dev.haloy.appName: "$APP_NAME"
      dev.haloy.deployment-id: "1"
      dev.haloy.role: "app"
      dev.haloy.port: "$CONTAINER_PORT"
      dev.haloy.health-check-path: "/health"

networks:
  haloy:
    external: true
EOF

fi

# --- scaffold deno entrypoint ---
if [[ "$IMAGE" == denoland/deno* ]] && [ ! -f "$APP_DIR/main.ts" ]; then
  cat <<EOF > "$APP_DIR/main.ts"
Deno.serve({ port: $CONTAINER_PORT }, (req: Request) => {
  const url = new URL(req.url);

  if (url.pathname === "/health") {
    return new Response("OK", { status: 200 });
  }

  return new Response("Hello from $APP_NAME", { status: 200 });
});
EOF
fi

# --- scaffold static index ---
if [[ "$IMAGE" == nginx* ]] && [ ! -f "$APP_DIR/data/index.html" ]; then
  cat <<EOF > "$APP_DIR/data/index.html"
<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"><title>$APP_NAME</title></head>
<body><h1>$APP_NAME</h1></body>
</html>
EOF
fi

# --- start app ---
cd "$APP_DIR" || { gum log --level error "Could not cd to $APP_DIR"; exit 1; }

gum spin --spinner dot --title "Starting $APP_NAME..." -- \
  docker compose up -d \
  || ERRORS+=("docker compose up failed for $APP_NAME")

# --- report ---
report_errors "$APP_NAME" "created" "${ERRORS[@]}"

echo
gum style --foreground 212 "✓ $APP_NAME created"
echo
gum style --foreground 240 "Next steps:"
gum style --foreground 240 "  doxo expose $APP_NAME --public    expose publicly via Tailscale Funnel"
gum style --foreground 240 "  doxo expose $APP_NAME --private   expose on tailnet via Tailscale Serve"
gum style --foreground 240 "  doxo list                         check status"
