#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Phase 2: Install external tools not available in Fedora repos
# Oh My Posh, Zinit, JetBrains Mono Nerd Font, fnm (Node.js)
# =============================================================================

ARCH="$(uname -m)"
LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"

# -----------------------------------------------------------------------------
# Oh My Posh
# -----------------------------------------------------------------------------
install_ohmyposh() {
    if command -v oh-my-posh &>/dev/null; then
        echo "[OK] Oh My Posh already installed: $(oh-my-posh version)"
        return
    fi

    echo "[INFO] Installing Oh My Posh..."

    local omp_arch
    case "$ARCH" in
        aarch64) omp_arch="arm64" ;;
        x86_64)  omp_arch="amd64" ;;
        *)       echo "[ERROR] Unsupported arch: $ARCH"; return 1 ;;
    esac

    curl -fsSL "https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-linux-${omp_arch}" -o "$LOCAL_BIN/oh-my-posh"
    chmod +x "$LOCAL_BIN/oh-my-posh"
    echo "[OK] Oh My Posh installed"
}

# -----------------------------------------------------------------------------
# Zinit (ZSH plugin manager)
# -----------------------------------------------------------------------------
install_zinit() {
    local zinit_home="$HOME/.local/share/zinit/zinit.git"

    if [[ -d "$zinit_home" ]]; then
        echo "[OK] Zinit already installed"
        return
    fi

    echo "[INFO] Installing Zinit..."
    mkdir -p "$(dirname "$zinit_home")"
    git clone https://github.com/zdharma-continuum/zinit.git "$zinit_home"
    echo "[OK] Zinit installed"
}

# -----------------------------------------------------------------------------
# JetBrains Mono Nerd Font
# -----------------------------------------------------------------------------
install_nerd_font() {
    local font_dir="$HOME/.local/share/fonts/JetBrainsMonoNerd"

    if [[ -d "$font_dir" ]] && ls "$font_dir"/*.ttf &>/dev/null; then
        echo "[OK] JetBrains Mono Nerd Font already installed"
        return
    fi

    echo "[INFO] Installing JetBrains Mono Nerd Font..."
    mkdir -p "$font_dir"

    local tmp_dir
    tmp_dir="$(mktemp -d)"
    curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz" -o "$tmp_dir/JetBrainsMono.tar.xz"
    tar -xf "$tmp_dir/JetBrainsMono.tar.xz" -C "$font_dir"
    rm -rf "$tmp_dir"

    # Refresh font cache
    if command -v fc-cache &>/dev/null; then
        fc-cache -fv "$font_dir" >/dev/null 2>&1
    fi

    echo "[OK] JetBrains Mono Nerd Font installed"
}

# -----------------------------------------------------------------------------
# fnm (Fast Node Manager) - needed on host for npx/MCP servers
# -----------------------------------------------------------------------------
install_fnm() {
    if command -v fnm &>/dev/null; then
        echo "[OK] fnm already installed: $(fnm --version)"
        return
    fi

    echo "[INFO] Installing fnm (Fast Node Manager)..."
    curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir "$LOCAL_BIN" --skip-shell
    echo "[OK] fnm installed"

    # Install Node.js LTS
    export PATH="$LOCAL_BIN:$PATH"
    eval "$(fnm env)"
    echo "[INFO] Installing Node.js LTS via fnm..."
    fnm install --lts
    fnm default lts-latest
    echo "[OK] Node.js $(node --version) installed"
}

# -----------------------------------------------------------------------------
# Ghostty terminal (via COPR)
# -----------------------------------------------------------------------------
install_ghostty() {
    if command -v ghostty &>/dev/null; then
        echo "[OK] Ghostty already installed"
        return
    fi

    if ! command -v rpm-ostree &>/dev/null; then
        echo "[SKIP] Not on Fedora Atomic, skipping Ghostty"
        return
    fi

    echo "[INFO] Installing Ghostty via COPR..."
    # Enable COPR repo and install
    sudo tee /etc/yum.repos.d/ghostty.repo > /dev/null <<'REPO'
[copr:copr.fedorainfracloud.org:pgdev:ghostty]
name=Copr repo for ghostty owned by pgdev
baseurl=https://download.copr.fedorainfracloud.org/results/pgdev/ghostty/fedora-$releasever-$basearch/
type=rpm-md
skip_if_unavailable=True
gpgcheck=1
gpgkey=https://download.copr.fedorainfracloud.org/results/pgdev/ghostty/pubkey.gpg
repo_gpgcheck=0
enabled=1
enabled_metadata=1
REPO

    sudo rpm-ostree install --idempotent --allow-inactive ghostty
    echo "[OK] Ghostty installed (may require reboot)"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
echo "============================================"
echo " Installing external tools"
echo "============================================"

install_ohmyposh
install_zinit
install_nerd_font
install_fnm
install_ghostty

echo ""
echo "[OK] All external tools installed"
