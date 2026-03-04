#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# fedora-update: Update everything in one command
# Host packages, Flatpak, Distrobox containers, and tools
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

section() { echo -e "\n${CYAN}=== $* ===${NC}"; }
ok()      { echo -e "${GREEN}[OK]${NC} $*"; }

section "Updating rpm-ostree (host system)"
sudo rpm-ostree upgrade || echo "rpm-ostree upgrade failed or no updates available"

section "Updating Flatpak apps"
flatpak update -y 2>/dev/null || echo "No Flatpak updates"

section "Updating Distrobox containers"
if command -v distrobox &>/dev/null; then
    distrobox upgrade --all 2>/dev/null || echo "Distrobox upgrade skipped"
fi

section "Updating Oh My Posh"
if command -v oh-my-posh &>/dev/null; then
    ARCH="$(uname -m)"
    case "$ARCH" in
        aarch64) omp_arch="arm64" ;;
        x86_64)  omp_arch="amd64" ;;
    esac
    curl -fsSL "https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-linux-${omp_arch}" -o "$HOME/.local/bin/oh-my-posh"
    chmod +x "$HOME/.local/bin/oh-my-posh"
    ok "Oh My Posh updated to $(oh-my-posh version)"
fi

section "Updating chezmoi dotfiles"
if command -v chezmoi &>/dev/null; then
    chezmoi update --force || echo "chezmoi update skipped"
fi

section "Updating fnm + Node.js"
if command -v fnm &>/dev/null; then
    eval "$(fnm env)" 2>/dev/null || true
    fnm install --lts
    fnm default lts-latest
    ok "Node.js $(node --version)"
fi

echo ""
ok "All updates complete!"

if rpm-ostree status | grep -q "pending"; then
    echo -e "\n${RED}[!] rpm-ostree has pending changes. Reboot to apply: systemctl reboot${NC}"
fi
