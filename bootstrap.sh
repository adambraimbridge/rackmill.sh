#!/usr/bin/env bash
# set -euo pipefail

GREEN="\e[32m"; CYAN="\e[36m"; RESET="\e[0m"
section(){ echo -e "${CYAN}\n========== $1 ==========${RESET}"; }
step(){ echo -e "${GREEN}>>> $1${RESET}"; }

[ "$(id -u)" -ne 0 ] && {
  if command -v sudo >/dev/null 2>&1; then
    echo "Not running as root — re-running with sudo..."
    exec sudo bash "$0" "$@"
  else
    echo "Please run as root."
    exit 1
  fi
}

export DEBIAN_FRONTEND=noninteractive

section "Hostname"
step "Setting hostname to rackmill..."
hostnamectl set-hostname rackmill || true

# Remove or comment out any APT sources referencing 'xenial' to avoid GPG errors
section "APT sources"
step "Backing up sources.list..."
cp /etc/apt/sources.list /etc/apt/sources.list.bak || true
sed -i 's|http://.*.ubuntu.com|http://archive.ubuntu.com|g' /etc/apt/sources.list
sed -i 's|http://security.ubuntu.com|http://archive.ubuntu.com|g' /etc/apt/sources.list

step "Clearing stale indices..."
rm -rf /var/lib/apt/lists/*

step "apt-get update (primary mirrors)..."
apt-get update

section "System upgrade"
step "Applying upgrades that may add/remove deps (dist-upgrade)..."
apt-get dist-upgrade

step "Removing unneeded packages..."
apt-get autoremove
apt-get autoclean

section "Timezone & Locale"
step "Setting timezone to Australia/Perth..."
timedatectl set-timezone Australia/Perth || true

step "Installing locales..."
apt-get install locales
locale-gen en_AU.UTF-8
update-locale LANG=en_AU.UTF-8 LANGUAGE="en_AU:en" LC_TIME=en_AU.UTF-8

step "Current locale:"
locale | sed 's/^/   /'

# -------------------------------
# Essentials & tools
# -------------------------------
section "Essentials & tools"

step "Installing essentials (git, curl, wget, zsh, traceroute, mtr)..."
apt install -y git curl wget zsh traceroute mtr

# -------------------------------
# Oh My Zsh
# -------------------------------
# Determine the target (non-root) user to install Oh My Zsh for.
# Priority:
# 1. SUDO_USER (when the script was sudo'd)
# 2. logname (login name)
# 3. first user in /etc/passwd with UID >= 1000 (typical non-system user)
TARGET_USER=""
if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then
  TARGET_USER="${SUDO_USER}"
else
  if command -v logname >/dev/null 2>&1; then
    TARGET_USER="$(logname 2>/dev/null || true)"
  fi
  if [ -z "${TARGET_USER:-}" ] || [ "${TARGET_USER}" = "root" ]; then
    TARGET_USER="$(whoami 2>/dev/null || true)"
  fi
  if [ -z "${TARGET_USER:-}" ] || [ "${TARGET_USER}" = "root" ]; then
    TARGET_USER="$(awk -F: '($3>=1000)&&($1!="nobody"){print $1; exit}' /etc/passwd || true)"
  fi
fi

# Fallback to 'adam' if detection fails
TARGET_USER="${TARGET_USER}"
USER_HOME="/home/${TARGET_USER}"

section "Oh My Zsh"

if id -u "${TARGET_USER}" >/dev/null 2>&1; then
  if [ -d "${USER_HOME}/.oh-my-zsh" ]; then
    step "Oh My Zsh already installed for ${TARGET_USER}, skipping installation."
  else
    step "Installing Oh My Zsh for ${TARGET_USER} (will not change shell or run zsh now)..."
    curl -fsSL -o /tmp/omz_install.sh https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh
    sudo -u "${TARGET_USER}" -H env RUNZSH=no CHSH=no bash /tmp/omz_install.sh
    rm -f /tmp/omz_install.sh
  fi

  step "Setting zsh as default shell for ${TARGET_USER}..."
  chsh -s "$(which zsh)" "${TARGET_USER}" || true
else
  step "User ${TARGET_USER} does not exist; skipping Oh My Zsh installation."
fi

# -------------------------------
# Done
# -------------------------------
section "Done"
step "Setup complete! User ${TARGET_USER} will use zsh as their default shell from next login."
