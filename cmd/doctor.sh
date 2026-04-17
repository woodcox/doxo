#!/usr/bin/env bash

source "$(dirname "$0")/../lib/common.sh"

echo "🩺 Doxo Doctor"
echo "==================="

ERRORS=()
WARNINGS=()

# --- Docker ---
echo
echo "🐳 Docker"

if command -v docker >/dev/null 2>&1; then
  echo "  ✔ Docker installed: $(docker --version)"
else
  echo "  ❌ Docker not installed"
  ERRORS+=("Docker not installed — run install.sh")
fi

if docker info >/dev/null 2>&1; then
  echo "  ✔ Docker daemon running"
else
  echo "  ❌ Docker daemon not running"
  ERRORS+=("Docker daemon not running — try: sudo systemctl start docker")
fi

if docker compose version >/dev/null 2>&1; then
  echo "  ✔ Docker Compose available: $(docker compose version)"
else
  echo "  ❌ Docker Compose plugin not found"
  ERRORS+=("Docker Compose missing — install docker-compose-plugin")
fi

# --- Docker network ---
echo
echo "🔗 Network"

if docker network inspect "$NETWORK" >/dev/null 2>&1; then
  echo "  ✔ Docker network '$NETWORK' exists"
else
  echo "  ❌ Docker network '$NETWORK' missing"
  ERRORS+=("Docker network '$NETWORK' missing — run: docker network create $NETWORK")
fi

# --- Caddy ---
echo
echo "🌐 Caddy"

# check for system caddy conflict
if systemctl is-active --quiet caddy 2>/dev/null; then
  echo "  ⚠️  System Caddy service is running (port conflict risk)"
  WARNINGS+=("System caddy service running — may conflict on ports 80/443. Disable with: sudo systemctl stop caddy && sudo systemctl disable caddy")
fi

if docker ps --format '{{.Names}}' | grep -q '^caddy$'; then
  echo "  ✔ Caddy container running"

  # validate caddy config
  if docker exec caddy caddy validate --config /etc/caddy/Caddyfile >/dev/null 2>&1; then
    echo "  ✔ Caddyfile valid"
  else
    echo "  ❌ Caddyfile has errors"
    ERRORS+=("Caddyfile invalid — run: docker exec caddy caddy validate --config /etc/caddy/Caddyfile")
  fi

  # check sites dir is mounted and readable
  if docker exec caddy test -d /etc/caddy/sites >/dev/null 2>&1; then
    SITE_COUNT=$(docker exec caddy sh -c 'ls /etc/caddy/sites/ 2>/dev/null | wc -l')
    echo "  ✔ Sites directory mounted ($SITE_COUNT site(s) loaded)"
  else
    echo "  ❌ Sites directory not found inside Caddy container"
    ERRORS+=("Caddy sites directory not mounted — check docker-compose.yml volumes")
  fi
elif docker ps -a --format '{{.Names}}' | grep -q '^caddy$'; then
  echo "  ❌ Caddy container exists but is stopped"
  ERRORS+=("Caddy stopped — run: cd ~/docker/caddy && docker compose up -d")
else
  echo "  ❌ Caddy container not found"
  ERRORS+=("Caddy not installed — run install.sh")
fi

# --- Doxo CLI ---
echo
echo "⚙️ Doxo CLI"

if command -v doxo >/dev/null 2>&1; then
  DOXO_PATH=$(command -v doxo)
  echo "  ✔ doxo in PATH: $DOXO_PATH"

  # check symlink target still exists
  if [ -L "$DOXO_PATH" ]; then
    TARGET=$(readlink -f "$DOXO_PATH")
    if [ -f "$TARGET" ]; then
      echo "  ✔ Symlink target exists: $TARGET"
    else
      echo "  ❌ Symlink target missing: $TARGET"
      ERRORS+=("doxo symlink broken — run install.sh to reinstall")
    fi
  fi
else
  echo "  ❌ doxo not in PATH"
  ERRORS+=("doxo not in PATH — add $HOME/.local/bin to PATH or run install.sh")
fi

# --- Apps ---
echo
echo "📦 Apps"

APP_COUNT=0
for dir in "$BASE_DIR"/*/; do
  [ -d "$dir" ] || continue
  APP_NAME=$(basename "$dir")
  is_protected "$APP_NAME" && continue
  APP_COUNT=$((APP_COUNT + 1))
done

echo "  ✔ $APP_COUNT app(s) found in $BASE_DIR"

# --- Summary ---
echo
echo "==================="

if [ ${#WARNINGS[@]} -gt 0 ]; then
  echo "⚠️  Warnings:"
  for w in "${WARNINGS[@]}"; do
    echo "   • $w"
  done
  echo
fi

if [ ${#ERRORS[@]} -eq 0 ]; then
  echo "✅ All systems healthy"
  exit 0
else
  echo "❌ Issues detected:"
  for e in "${ERRORS[@]}"; do
    echo "   • $e"
  done
  exit 1
fi
echo "==================="
echo