#!/usr/bin/env bash

BASE_DIR="$HOME/docker"
NETWORK="caddy"
CADDY_DIR="$BASE_DIR/caddy"
SITES_DIR="$CADDY_DIR/sites"
PROTECTED=("caddy")

prompt() {
  local message="$1"
  local default="$2"
  read -rp "$message [$default]: " input
  echo "${input:-$default}"
}

yes_no() {
  local message="$1"
  read -rp "$message (y/n): " yn
  [[ "$yn" =~ ^[Yy]$ ]]
}

validate_name() {
  [[ "$1" =~ ^[a-zA-Z0-9_-]+$ ]]
}

is_protected() {
  for name in "${PROTECTED[@]}"; do
    [[ "$1" == "$name" ]] && return 0
  done
  return 1
}

load_meta() {
  local app_dir="$1"
  IMAGE="-"
  INTERNAL_PORT="-"
  PORT="-"
  DOMAIN="-"
  CREATED_AT="-"
  if [ -f "$app_dir/.meta" ]; then
    source "$app_dir/.meta"
  fi
}

reload_caddy() {
  if docker ps --format '{{.Names}}' | grep -q '^caddy$'; then
    docker exec caddy caddy reload --config /etc/caddy/Caddyfile >/dev/null 2>&1 \
      && echo "Caddy reloaded" \
      || return 1
  else
    echo "⚠️  Caddy not running, reload skipped"
  fi
}

report_errors() {
  local app_name="$1"
  local action="$2"
  shift 2
  local errors=("$@")

  echo
  if [ ${#errors[@]} -gt 0 ]; then
    echo "⚠️  '$app_name' $action with errors:"
    for err in "${errors[@]}"; do
      echo "   • $err"
    done
  else
    echo "✅ '$app_name' $action successfully"
  fi
  echo
}