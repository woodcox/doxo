#!/usr/bin/env bash

DOXO_DIR="$HOME/doxo"
BIN_DIR="$HOME/.local/bin"
LINK="$BIN_DIR/doxo"
REPO="https://github.com/woodcox/doxo.git"
REPAIR_MODE=0
DOXO_NONINTERACTIVE="${DOXO_NONINTERACTIVE:-0}"

# --- helpers ---
info()    { echo -e "\033[0;34m[INFO]\033[0m $1"; }
success() { echo -e "\033[0;32m[OK]\033[0m $1"; }
error()   { echo -e "\033[0;31m[ERROR]\033[0m $1" >&2; }

yes_no() {
  local prompt="$1"
  local yn

  # non-interactive → assume YES
  if [[ "$DOXO_NONINTERACTIVE" == "1" ]]; then
    info "Running non-interactive mode (curl/bash) → defaulting YES: $prompt"
    return 0
  fi

  read -rp "$prompt (y/n): " yn || return 1
  # handle empty input explicitly
  [[ "$yn" =~ ^[Yy]$ ]]
}

exists_cmd() {
  command -v "$1" >/dev/null 2>&1
}

exists_container() {
  docker inspect "$1" >/dev/null 2>&1
}

exists_network() {
  docker network inspect "$1" >/dev/null 2>&1
}

exists_dir() {
  [ -d "$1" ]
}

# --- parse args ---
if [[ "${1:-}" == "--repair" ]]; then
  info "Running repair mode..."
  REPAIR_MODE=1
fi

# --- install docker ---
install_docker() {
  info "Installing Docker..."

  # requires root
  if [ "$(id -u)" -ne 0 ]; then
    error "Docker installation requires root. Re-run install.sh with sudo."
    return 1
  fi

  # detect distro
  if [ ! -f /etc/os-release ]; then
    error "Cannot detect distribution. Install Docker manually: https://docs.docker.com/engine/install/"
    return 1
  fi

  . /etc/os-release
  DISTRO="$ID"
  VERSION_CODENAME="${VERSION_CODENAME:-}"

  info "Detected distribution: $DISTRO"

  case "$DISTRO" in
    ubuntu|debian|linuxmint|pop|elementary|zorin)
      [[ "$DISTRO" =~ ^(linuxmint|pop|elementary|zorin)$ ]] && DISTRO="ubuntu"
      _install_docker_debian_ubuntu
      ;;
    centos|rocky|almalinux)
      DISTRO="centos"
      _install_docker_centos_rhel
      ;;
    rhel)
      _install_docker_centos_rhel
      ;;
    fedora)
      _install_docker_fedora
      ;;
    alpine)
      _install_docker_alpine
      ;;
    *)
      error "Unsupported distribution: $DISTRO. Install Docker manually: https://docs.docker.com/engine/install/"
      return 1
      ;;
  esac

  # add current user to docker group
  if [ -n "$SUDO_USER" ] && ! groups "$SUDO_USER" | grep -q docker; then
    usermod -aG docker "$SUDO_USER"
    info "Added $SUDO_USER to docker group — log out and back in for this to take effect"
  fi

  if exists_cmd docker; then
    success "Docker installed: $(docker --version)"
  else
    error "Docker installation completed but 'docker' command not found"
    return 1
  fi
}

_install_docker_debian_ubuntu() {
  apt-get update
  apt-get install -y ca-certificates curl gnupg

  install -m 0755 -d /etc/apt/keyrings
  [ -f /etc/apt/keyrings/docker.gpg ] && rm /etc/apt/keyrings/docker.gpg
  curl -fsSL "https://download.docker.com/linux/$DISTRO/gpg" \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  CODENAME="$VERSION_CODENAME"
  if [ -z "$CODENAME" ] && exists_cmd lsb_release; then
    CODENAME=$(lsb_release -cs)
  fi
  [ -z "$CODENAME" ] && { error "Cannot determine codename"; return 1; }

  ARCH=$(dpkg --print-architecture)
  echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/$DISTRO $CODENAME stable" \
    > /etc/apt/sources.list.d/docker.list

  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
  systemctl enable docker && systemctl start docker
}

_install_docker_centos_rhel() {
  PKG_MGR=$(exists_cmd dnf || exists_cmd yum)
  [ -z "$PKG_MGR" ] && { error "Neither dnf nor yum found"; return 1; }

  $PKG_MGR remove -y docker docker-client docker-client-latest docker-common \
    docker-latest docker-latest-logrotate docker-logrotate docker-engine 2>/dev/null || true
  $PKG_MGR install -y yum-utils

  REPO_DISTRO="$DISTRO"
  [ "$DISTRO" = "rhel" ] && REPO_DISTRO="centos"
  yum-config-manager --add-repo \
    "https://download.docker.com/linux/$REPO_DISTRO/docker-ce.repo"

  $PKG_MGR install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
  systemctl enable docker && systemctl start docker
}

_install_docker_fedora() {
  dnf remove -y docker docker-client docker-client-latest docker-common \
    docker-latest docker-latest-logrotate docker-logrotate docker-selinux \
    docker-engine-selinux docker-engine 2>/dev/null || true
  dnf install -y dnf-plugins-core
  dnf config-manager --add-repo \
    https://download.docker.com/linux/fedora/docker-ce.repo
  dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
  systemctl enable docker && systemctl start docker
}

_install_docker_alpine() {
  apk update
  apk add docker docker-cli
  rc-update add docker boot
  service docker start
}

# --- install doxo ---
install_doxo() {
  info "Installing doxo..."

  if [[ "$REPAIR_MODE" == "1" ]]; then
    info "Repair mode: forcing reinstall"
    rm -rf "$DOXO_DIR"
  fi

  if [ -d "$DOXO_DIR/.git" ]; then
    info "Updating existing doxo installation..."
    git -C "$DOXO_DIR" pull || { error "git pull failed"; return 1; }
  else
    git clone "$REPO" "$DOXO_DIR" || { error "git clone failed — check your internet connection"; return 1; }
  fi

  mkdir -p "$BIN_DIR"
  chmod +x "$DOXO_DIR/bin/doxo"
  find "$DOXO_DIR/cmd" -type f -name "*.sh" -exec chmod +x {} \;

  [ -L "$LINK" ] && rm "$LINK"
  ln -sf "$DOXO_DIR/bin/doxo" "$LINK"
  success "doxo installed → $LINK"
}

ensure_path() {
  local shell_rc="$HOME/.bashrc"
  local path_line='export PATH="$HOME/.local/bin:$PATH"'

  # detect zsh
  if [[ "$SHELL" == *"zsh" ]]; then
    shell_rc="$HOME/.zshrc"
  fi

  # check if already present
  if grep -Fxq "$path_line" "$shell_rc"; then
    info "PATH already configured in $shell_rc"
    return 0
  fi

  echo "" >> "$shell_rc"
  echo "# Added by doxo installer" >> "$shell_rc"
  echo "$path_line" >> "$shell_rc"
  success "Added ~/.local/bin to PATH in $shell_rc"
  info "Run: 'source $shell_rc' or restart your terminal to apply changes"
}

# --- ensure docker ---
ensure_docker() {
  if [[ "$REPAIR_MODE" == "1" ]]; then
    info "Repair mode: re-checking Docker..."
  elif exists_cmd docker && docker info >/dev/null 2>&1; then
    info "Docker already installed: $(docker --version)"
    return 0
  fi

  if yes_no "Docker is not installed. Install it now?"; then
    install_docker || { error "Docker installation failed"; exit 1; }
  else
    error "Docker is required to run doxo"
    exit 1
  fi
}

# --- main installer ---
echo "=== Doxo Installer ==="
echo

ensure_docker
install_doxo
ensure_path

# --- post install ---
echo
echo "======================================="
success "Doxo installation complete!"
echo "======================================="
echo
info "Run: doxo help"
echo
info "Then run: doxo service install caddy, as you must create a caddy container"
info "Please make sure nothing is running on port 80 an 443"
echo