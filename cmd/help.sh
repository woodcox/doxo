#!/usr/bin/env bash

gum style \
  --foreground 212 --border-foreground 212 --border rounded \
  --padding "0 1" "  doxo — Docker + Haloy app manager"
echo

gum style --foreground 212 --bold "Usage"
gum style --foreground 240 "  doxo <command> [args]"
echo

gum style --foreground 212 --bold "Commands"
gum style --foreground 240 "  create              Scaffold and start a new app"
gum style --foreground 240 "  delete  [app]       Stop and delete an app"
gum style --foreground 240 "  expose  [app]       Expose an app via Tailscale"
gum style --foreground 240 "  unexpose [app]      Remove exposure of an app"
gum style --foreground 240 "  list                List all apps and status"
gum style --foreground 240 "  open    [app]       Open the app in a browser"
gum style --foreground 240 "  doctor              Check dependencies and configuration"
gum style --foreground 240 "  install             Install doxo"
gum style --foreground 240 "  uninstall           Uninstall doxo"
gum style --foreground 240 "  help                Show this help message"
echo

gum style --foreground 212 --bold "Flags"
gum style --foreground 240 "  doxo --version, -v             Show the doxo version number"
gum style --foreground 240 "  create [app] --port <n>        Set the host port"
gum style --foreground 240 "  create [app] --image <image>   Set the Docker image"
gum style --foreground 240 "  expose [app] --public          Expose publicly via Tailscale Funnel + custom domain"
gum style --foreground 240 "  expose [app] --private         Expose on tailnet via Tailscale Serve"
gum style --foreground 240 "  unexpose [app] --force         Skip confirmation"
gum style --foreground 240 "  install --repair               Force reinstall"
echo

gum style --foreground 212 --bold "Examples"
gum style --foreground 240 "  doxo create myapp"
gum style --foreground 240 "  doxo create myapp --port 8080 --image nginx:alpine"
echo
gum style --foreground 240 "  doxo expose myapp --public     # https://myapp.yourdomain.com"
gum style --foreground 240 "  doxo expose myapp --private    # https://device.ts.net/myapp"
gum style --foreground 240 "  doxo unexpose myapp"
echo
gum style --foreground 240 "  doxo list"
gum style --foreground 240 "  doxo open myapp"
gum style --foreground 240 "  doxo doctor"
echo

gum style --foreground 212 --bold "Runtime operations"
gum style --foreground 240 "  Use the haloy CLI directly for runtime management:"
gum style --foreground 240 "  haloy status          Show running apps"
gum style --foreground 240 "  haloy logs <app>      Stream app logs"
gum style --foreground 240 "  haloy rollback <app>  Roll back to previous deploy"
echo