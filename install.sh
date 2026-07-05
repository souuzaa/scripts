#!/usr/bin/env bash
#
# General install script for a fresh Linux install.
# Supports: Arch, Ubuntu/Debian, Fedora.
#
# Installs: docker, tmux, visual studio code, bun.js, git + gh (GitHub CLI),
#           discord, draw.io, btop, google chrome.
#
# Snap is only ever used on Ubuntu, and never for chrome or docker.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log()  { printf '\033[1;34m[*]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[X]\033[0m %s\n' "$*" >&2; exit 1; }

is_installed() { command -v "$1" >/dev/null 2>&1; }

require_sudo() {
  is_installed sudo || die "sudo is required but not installed"
}

load_os_release() {
  [[ -r /etc/os-release ]] || die "Cannot detect distro: /etc/os-release not found"
  . /etc/os-release
}

detect_distro() {
  local id="${ID:-}" like="${ID_LIKE:-}"
  if [[ "$id" == "arch" || "$like" == *arch* ]]; then
    echo arch
  elif [[ "$id" == "ubuntu" || "$id" == "debian" || "$like" == *ubuntu* || "$like" == *debian* ]]; then
    echo ubuntu
  elif [[ "$id" == "fedora" || "$like" == *fedora* ]]; then
    echo fedora
  else
    die "Unsupported distro: ${id:-unknown}"
  fi
}

pkg_update() {
  case "$DISTRO" in
    arch) sudo pacman -Syu --noconfirm ;;
    ubuntu) sudo apt-get update -y ;;
    fedora) sudo dnf makecache -y ;;
  esac
}

pkg_install() {
  case "$DISTRO" in
    arch) sudo pacman -S --noconfirm --needed "$@" ;;
    ubuntu) sudo apt-get install -y "$@" ;;
    fedora) sudo dnf install -y "$@" ;;
  esac
}

# --- AUR helper (Arch only, used for packages not in the official repos) ---

ensure_yay() {
  is_installed yay && return
  log "Installing yay (AUR helper)"
  pkg_install --needed git base-devel
  local tmp
  tmp="$(mktemp -d)"
  git clone --depth=1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
  (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
  rm -rf "$tmp"
}

aur_install() {
  ensure_yay
  yay -S --noconfirm --needed "$@"
}

# --- Flatpak helper (Fedora only, used for desktop apps not in the repos) ---

ensure_flatpak() {
  is_installed flatpak || pkg_install flatpak
  flatpak remote-list 2>/dev/null | grep -q flathub || \
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
}

# --- App installers ---

install_tmux() {
  if is_installed tmux; then
    ok "tmux already installed"
  else
    log "Installing tmux"
    pkg_install tmux
  fi

  local conf="$SCRIPT_DIR/tmux/tmux.conf"
  if [[ -f "$conf" ]]; then
    ln -sf "$conf" "$HOME/.tmux.conf"
    ok "Linked tmux.conf -> ~/.tmux.conf"
  fi
}

install_github_cli() {
  is_installed git || { log "Installing git"; pkg_install git; }

  if is_installed gh; then
    ok "gh already installed"
    return
  fi

  log "Installing GitHub CLI (gh)"
  case "$DISTRO" in
    arch)
      pkg_install github-cli
      ;;
    ubuntu)
      sudo mkdir -p -m 755 /etc/apt/keyrings
      wget -nv -O- https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
        sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
      sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
        sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
      sudo apt-get update -y
      pkg_install gh
      ;;
    fedora)
      sudo dnf install -y 'dnf-command(config-manager)'
      sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
      pkg_install gh
      ;;
  esac
}

# Docker: never installed via snap, on any distro.
install_docker() {
  if is_installed docker; then
    ok "docker already installed"
  else
    log "Installing docker"
    case "$DISTRO" in
      arch)
        pkg_install docker docker-compose
        ;;
      ubuntu)
        pkg_install ca-certificates curl gnupg
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" | \
          sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
        sudo apt-get update -y
        pkg_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        ;;
      fedora)
        sudo dnf install -y 'dnf-command(config-manager)'
        sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
        pkg_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        ;;
    esac
  fi

  sudo systemctl enable --now docker
  if ! groups "$USER" | grep -q '\bdocker\b'; then
    sudo usermod -aG docker "$USER"
    warn "Added $USER to the docker group. Log out and back in for it to take effect."
  fi
}

install_vscode() {
  if is_installed code; then
    ok "VS Code already installed"
    return
  fi

  log "Installing Visual Studio Code"
  case "$DISTRO" in
    arch)
      aur_install visual-studio-code-bin
      ;;
    ubuntu)
      sudo snap install code --classic
      ;;
    fedora)
      sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
      cat <<'EOF' | sudo tee /etc/yum.repos.d/vscode.repo >/dev/null
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
      pkg_install code
      ;;
  esac
}

install_bun() {
  if is_installed bun; then
    ok "bun already installed"
    return
  fi
  log "Installing bun.js"
  curl -fsSL https://bun.sh/install | bash
}

install_discord() {
  if is_installed discord; then
    ok "Discord already installed"
    return
  fi

  log "Installing Discord"
  case "$DISTRO" in
    arch)
      pkg_install discord
      ;;
    ubuntu)
      sudo snap install discord
      ;;
    fedora)
      ensure_flatpak
      flatpak install -y flathub com.discordapp.Discord
      ;;
  esac
}

install_drawio() {
  if is_installed drawio; then
    ok "draw.io already installed"
    return
  fi

  log "Installing draw.io"
  case "$DISTRO" in
    arch)
      aur_install drawio-desktop-bin
      ;;
    ubuntu)
      sudo snap install drawio
      ;;
    fedora)
      ensure_flatpak
      flatpak install -y flathub org.drawio.DrawIO
      ;;
  esac
}

install_btop() {
  if is_installed btop; then
    ok "btop already installed"
    return
  fi
  log "Installing btop"
  pkg_install btop
}

# Chrome: never installed via snap, on any distro.
install_chrome() {
  if is_installed google-chrome-stable || is_installed google-chrome; then
    ok "Google Chrome already installed"
    return
  fi

  log "Installing Google Chrome"
  case "$DISTRO" in
    arch)
      aur_install google-chrome
      ;;
    ubuntu)
      local tmp
      tmp="$(mktemp -d)"
      curl -fsSL -o "$tmp/chrome.deb" https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
      sudo apt-get install -y "$tmp/chrome.deb"
      rm -rf "$tmp"
      ;;
    fedora)
      cat <<'EOF' | sudo tee /etc/yum.repos.d/google-chrome.repo >/dev/null
[google-chrome]
name=google-chrome
baseurl=https://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub
EOF
      pkg_install google-chrome-stable
      ;;
  esac
}

main() {
  require_sudo
  load_os_release
  DISTRO="$(detect_distro)"
  log "Detected distro: $DISTRO"

  log "Updating package index"
  pkg_update

  install_tmux
  install_github_cli
  install_docker
  install_vscode
  install_bun
  install_discord
  install_drawio
  install_btop
  install_chrome

  ok "All done."
  warn "Log out/in for the docker group change to apply, and restart your shell for bun's PATH update."
}

main "$@"
