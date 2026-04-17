#!/usr/bin/env bash

BASE_DIR="$HOME/docker"
NETWORK="caddy"
CADDY_DIR="$BASE_DIR/caddy"
SITES_DIR="$CADDY_DIR/sites"
PROTECTED=("caddy")
DOXO_NONINTERACTIVE="${DOXO_NONINTERACTIVE:-0}"

prompt() {
  local message="$1"
  local default="$2"
  read -rp "$message [$default]: " input
  echo "${input:-$default}"
}

yes_no() {
  local prompt="$1"
  local yn

  if [[ "$DOXO_NONINTERACTIVE" == "1" || ! -t 0 ]]; then
    info "Non-interactive mode → defaulting YES: $prompt"
    return 0
  fi

  read -rp "$prompt (y/n): " yn || return 1
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
  IMAGE=""
  CONTAINER_PORT=""
  PORT=""
  DOMAIN=""
  CREATED_AT=""
  if [ -f "$app_dir/.meta" ]; then
    source "$app_dir/.meta"
  fi
}

update_meta() {
  local key="$1"
  local value="$2"
  local meta_file="$APP_DIR/.meta"
  if [ ! -f "$meta_file" ]; then
    echo "❌ .meta file not found at $meta_file"
    return 1
  fi
  if grep -q "^${key}=" "$meta_file"; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$meta_file"
  else
    echo "${key}=${value}" >> "$meta_file"
  fi
}

remove_meta() {
  local key="$1"
  local meta_file="$APP_DIR/.meta"
  if [ ! -f "$meta_file" ]; then
    echo "❌ .meta file not found at $meta_file"
    return 1
  fi
  sed -i "/^${key}=/d" "$meta_file"
}

get_local_ip() {
  if [ -n "$DOXO_HOST_IP" ]; then
    echo "$DOXO_HOST_IP"
  else
    hostname -I | awk '{print $1}'
  fi
}

add_to_hosts() {
  local domain="$1"
  local ip="${2:-$(get_local_ip)}"
  if grep -qE "[[:space:]]$domain$" /etc/hosts; then
    echo "ℹ️  Hosts entry already exists for $domain"
    return
  fi
  echo "Adding $domain → $ip to /etc/hosts..."
  echo "$ip $domain" | sudo tee -a /etc/hosts >/dev/null \
    || { echo "❌ Failed to update /etc/hosts — try running with sudo"; return 1; }
  echo "✅ Hosts entry added"
}

remove_from_hosts() {
  local domain="$1"
  if grep -qE "[[:space:]]$domain$" /etc/hosts; then
    echo "Removing $domain from /etc/hosts..."
    sudo sed -i "/[[:space:]]$domain$/d" /etc/hosts \
      || { echo "❌ Failed to update /etc/hosts — try running with sudo"; return 1; }
    echo "✅ Hosts entry removed"
  else
    echo "ℹ️  No hosts entry found for $domain"
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