#!/usr/bin/env bash

echo "🐳 Doxo — Docker + Caddy app manager"
echo
echo "Usage: doxo <command> [args]"
echo
echo "Commands:"
echo "---------"
echo "  create              Scaffold and start a new app"
echo "  delete <app>        Stop and delete an app"
echo "  list                List all apps and status"
echo "  restart <app>       Restart an app (docker compose restart)"
echo "  expose <app>        Expose an app via Caddy route (domain/subdomain)"
echo "  unexpose <app>      Remove public exposure of an app (removes a caddy route)"
echo "  help                Show this help message"
echo "  uninstall           Uninstall Doxo"
echo
echo "Flags:"
echo "---------"
echo "  --version, -v               Show the doxo version number"
echo "  restart <app> --recreate    Recreate app (docker compose down && up -d)"
echo "  expose <app> --local        Expose locally using /etc/hosts"
echo "  expose <app> --tailnet      Expose via Tailscale MagicDNS"
echo "  expose <app> <domain>       Expose publicly"
echo "  unexpose <app> --force      Skip confirmation"
echo
echo "Examples:"
echo "---------"
echo "  doxo create myapp"
echo "  doxo create myapp 8080 nginx:alpine"
echo
echo "  doxo list"
echo
echo "  doxo restart myapp"
echo "  doxo restart myapp --recreate"
echo
echo "  doxo expose myapp"
echo "  doxo expose myapp myapp.local"
echo "  doxo expose myapp app.example.com"
echo "  doxo expose myapp --local"
echo
echo "  doxo unexpose myapp"
echo
echo "  doxo delete myapp"
echo