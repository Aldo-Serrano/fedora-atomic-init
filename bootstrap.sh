#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Fedora COSMIC Atomic - Bootstrap Script
# Configures a fresh Fedora Atomic install with dev environment from scratch
# Usage: curl -fsSL https://raw.githubusercontent.com/Aldo-Serrano/fedora-atomic-init/main/bootstrap.sh | bash
# =============================================================================

REPO_URL="${REPO_URL:-https://github.com/Aldo-Serrano/fedora-atomic-init.git}"
CHEZMOI_SOURCE="${CHEZMOI_SOURCE:-$REPO_URL}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# -----------------------------------------------------------------------------
# Pre-flight checks
# -----------------------------------------------------------------------------
check_system() {
    info "Checking system requirements..."

    if [[ "$(uname -s)" != "Linux" ]]; then
        error "This script is designed for Linux. Detected: $(uname -s)"
        exit 1
    fi

    if ! command -v rpm-ostree &>/dev/null; then
        error "rpm-ostree not found. This script requires Fedora Atomic (Silverblue/Kinoite/COSMIC Atomic)."
        exit 1
    fi

    ARCH="$(uname -m)"
    if [[ "$ARCH" != "aarch64" && "$ARCH" != "x86_64" ]]; then
        error "Unsupported architecture: $ARCH. Expected aarch64 or x86_64."
        exit 1
    fi

    ok "System: Fedora Atomic on $ARCH"
}

# -----------------------------------------------------------------------------
# Install chezmoi
# -----------------------------------------------------------------------------
install_chezmoi() {
    if command -v chezmoi &>/dev/null; then
        ok "chezmoi already installed: $(chezmoi --version)"
        return
    fi

    info "Installing chezmoi..."
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
    export PATH="$HOME/.local/bin:$PATH"
    ok "chezmoi installed: $(chezmoi --version)"
}

# -----------------------------------------------------------------------------
# Initialize and apply chezmoi
# -----------------------------------------------------------------------------
apply_chezmoi() {
    if [[ -d "$HOME/.local/share/chezmoi" ]]; then
        info "chezmoi already initialized. Applying updates..."
        chezmoi apply --verbose
    else
        info "Initializing chezmoi with source repo..."
        info "You will be prompted for API keys and git identity."
        echo ""
        chezmoi init "$CHEZMOI_SOURCE"
        chezmoi apply --verbose
    fi

    ok "chezmoi configuration applied!"
}

# -----------------------------------------------------------------------------
# Setup dev containers
# -----------------------------------------------------------------------------
setup_containers() {
    local setup_script="$HOME/.local/bin/setup-dev-containers.sh"

    if [[ ! -f "$setup_script" ]]; then
        warn "Container setup script not found at $setup_script"
        warn "Run 'chezmoi apply' first to install it."
        return 1
    fi

    if ! command -v toolbox &>/dev/null; then
        warn "toolbox not available. May need a reboot first."
        return 1
    fi

    info "Setting up dev containers..."
    bash "$setup_script"
}

# -----------------------------------------------------------------------------
# Post-apply: check if reboot is needed
# -----------------------------------------------------------------------------
check_reboot_and_continue() {
    if rpm-ostree status | grep -q "pending"; then
        echo ""
        warn "================================================================"
        warn " rpm-ostree has pending changes that require a REBOOT."
        warn " After rebooting, run this script again to finish setup:"
        warn ""
        warn "   ~/.local/bin/bootstrap-fedora.sh"
        warn ""
        warn " Or manually:"
        warn "   chezmoi apply && setup-dev-containers.sh"
        warn "================================================================"
        echo ""

        # Save bootstrap script for re-run after reboot
        mkdir -p "$HOME/.local/bin"
        SCRIPT_PATH="$HOME/.local/bin/bootstrap-fedora.sh"
        if [[ ! -f "$SCRIPT_PATH" ]] || [[ "$0" != "$SCRIPT_PATH" ]]; then
            cp "$0" "$SCRIPT_PATH" 2>/dev/null || \
                curl -fsSL "https://raw.githubusercontent.com/Aldo-Serrano/fedora-atomic-init/main/bootstrap.sh" -o "$SCRIPT_PATH"
            chmod +x "$SCRIPT_PATH"
        fi

        read -rp "Reboot now? [y/N] " answer
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            systemctl reboot
        fi
    else
        # No reboot needed - continue with container setup
        setup_containers
    fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN} Fedora COSMIC Atomic - Bootstrap${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""

    check_system
    install_chezmoi
    apply_chezmoi
    check_reboot_and_continue

    echo ""
    ok "Bootstrap finished!"
    echo ""
    info "Quick reference:"
    echo "  Enter web dev:      dev-web  (or: toolbox enter dev-web)"
    echo "  Enter flutter dev:  dev-flutter  (or: toolbox enter dev-flutter)"
    echo "  Update everything:  fedora-update.sh"
    echo "  Sync dotfiles:      chezmoi update"
    echo ""
}

main "$@"
