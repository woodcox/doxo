#!/usr/bin/env bash

source "$(dirname "$0")/../lib/common.sh"

echo "🩺 Doxo Doctor"
echo "=============="

ERRORS=()

# --- Docker ---
echo
echo "🐳 Docker"

if command -v docker >/dev/null 2>&1; then
  echo "✔ Docker installed: $(docker --version)"
else
  echo "❌ Docker not installed"
  ERRORS+=("Docker missing")
fi

if docker info >/dev/null 2>&1; then
  echo "✔ Docker daemon running"
else
  echo "❌ Docker daemon not running"
  ERRORS+=("Docker daemon down")
fi

# --- Caddy container ---
echo
echo "🌐 Caddy"

if docker ps --format '{{.Names}}' | grep -q '^caddy$'; then
  echo "✔ Caddy container running"
else
  echo "⚠️ Caddy container not running"
  ERRORS+=("Caddy not running")
fi

# --- CLI ---
echo
echo "⚙️ Doxo CLI"

if command -v doxo >/dev/null 2>&1; then
  echo "✔ doxo available"
else
  echo "❌ doxo not in PATH"
  ERRORS+=("CLI missing")
fi

# --- summary ---
echo
echo "=============="

if [ ${#ERRORS[@]} -eq 0 ]; then
  echo "✅ All systems healthy"
  exit 0
else
  echo "⚠️ Issues detected:"
  for e in "${ERRORS[@]}"; do
    echo " - $e"
  done
  exit 1
fi