#!/usr/bin/env bash

set -euo pipefail

DOXO_DIR="${DOXO_DIR:-$HOME/doxo}"
SERVICE_DIR="$DOXO_DIR/cmd/service"

SERVICE="${1:-}"
ACTION="${2:-}"

if [[ -z "$SERVICE" ]]; then
  echo "Usage: doxo service <name> <action>"
  exit 1
fi

SCRIPT="$SERVICE_DIR/$SERVICE/$ACTION.sh"

if [[ ! -f "$SCRIPT" ]]; then
  echo "Unknown service/action: $SERVICE $ACTION"
  exit 1
fi

shift 2
bash "$SCRIPT" "$@"