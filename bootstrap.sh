#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Fedora COSMIC Atomic - Bootstrap Script
# Configures a fresh Fedora Atomic install with dev environment from scratch
# Usage: curl -fsSL https://raw.githubusercontent.com/<user>/fedora-atomic-init/main/bootstrap.sh | bash
# =============================================================================

REPO_URL="${REPO_URL:-https://github.com/<user>/fedora-atomic-init.git}"
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
    info "Initializing chezmoi with source repo..."
    info "You will be prompted for API keys and git identity."
    echo ""

    chezmoi init "$CHEZMOI_SOURCE"
    chezmoi apply --verbose

    ok "chezmoi configuration applied!"
}

# -----------------------------------------------------------------------------
# Post-apply: check if reboot is needed
# -----------------------------------------------------------------------------
check_reboot() {
    if rpm-ostree status | grep -q "pending"; then
        echo ""
        warn "================================================================"
        warn " rpm-ostree has pending changes that require a REBOOT."
        warn " After rebooting, run this script again to continue setup:"
        warn ""
        warn "   chezmoi apply"
        warn "================================================================"
        echo ""

        read -rp "Reboot now? [y/N] " answer
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            systemctl reboot
        else
            info "Reboot when ready, then run: chezmoi apply"
        fi
    else
        ok "No reboot needed. Setup complete!"
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
    check_reboot

    echo ""
    ok "Bootstrap finished!"
    echo ""
    info "Next steps:"
    echo "  1. If a reboot was requested, reboot and run: chezmoi apply"
    echo "  2. Open Ghostty terminal to see your configured shell"
    echo "  3. Enter dev containers: distrobox enter dev-web"
    echo "  4. Enter dev containers: distrobox enter dev-flutter"
    echo ""
}

main "$@"
