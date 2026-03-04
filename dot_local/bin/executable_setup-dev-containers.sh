#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Setup Toolbx dev containers
# Idempotent: safe to run multiple times
# Creates dev-web and dev-flutter containers with full terminal + dev tools
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${RED}[WARN]${NC} $*"; }

# Packages to install in ALL containers (terminal environment)
TERMINAL_PACKAGES=(
    zsh
    fzf
    zoxide
    tmux
    git
    curl
    wget
    unzip
    util-linux-user
    fontconfig
)

# -----------------------------------------------------------------------------
# Install terminal environment inside a container
# Since Toolbx shares $HOME, dotfiles (.zshrc, .config/ohmyposh, etc.)
# and user-level tools (oh-my-posh, zinit, fnm) are already available.
# We only need the system-level binaries.
# -----------------------------------------------------------------------------
setup_terminal_in_container() {
    local container="$1"

    info "Installing terminal tools in $container..."
    toolbox run --container "$container" sudo dnf install -y "${TERMINAL_PACKAGES[@]}" 2>/dev/null || \
        warn "Some terminal packages may have failed in $container"

    # Set ZSH as default shell inside container
    toolbox run --container "$container" bash -c '
        CURRENT_SHELL="$(getent passwd "$USER" | cut -d: -f7)"
        if [[ "$CURRENT_SHELL" != */zsh ]]; then
            sudo chsh -s /usr/bin/zsh "$USER" 2>/dev/null || \
            sudo usermod -s /usr/bin/zsh "$USER" 2>/dev/null || true
        fi
    '
    ok "Terminal environment configured in $container"
}

# -----------------------------------------------------------------------------
# dev-web container
# -----------------------------------------------------------------------------
setup_dev_web() {
    local container="dev-web"

    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN} Setting up $container${NC}"
    echo -e "${CYAN}============================================${NC}"

    # Create container if it doesn't exist
    if toolbox list --containers 2>/dev/null | grep -q "$container"; then
        ok "$container container already exists"
    else
        info "Creating $container container..."
        toolbox create --name "$container" 2>/dev/null || toolbox create "$container"
        ok "$container container created"
    fi

    # Terminal environment
    setup_terminal_in_container "$container"

    # Dev tools: fnm + Node.js are in ~/.local (shared via home)
    # Just install global npm packages inside the container
    info "Setting up Node.js dev tools in $container..."
    toolbox run --container "$container" bash -c '
        export PATH="$HOME/.local/bin:$PATH"

        # fnm is already in ~/.local/bin (shared from host)
        if command -v fnm &>/dev/null; then
            eval "$(fnm env)" 2>/dev/null || true

            # Install global npm packages
            npm install -g typescript eslint prettier 2>/dev/null || \
                echo "[WARN] Some npm packages may have failed"
        else
            echo "[WARN] fnm not found. Run setup-tools on host first."
        fi

        # AI coding tools
        if command -v fnm &>/dev/null; then
            eval "$(fnm env)" 2>/dev/null || true

            if ! command -v claude &>/dev/null; then
                echo "[INFO] Installing Claude Code..."
                npm install -g @anthropic-ai/claude-code 2>/dev/null || \
                    echo "[WARN] Claude Code installation failed (known ARM64 issues)"
            fi

            if ! command -v codex &>/dev/null; then
                echo "[INFO] Installing OpenAI Codex CLI..."
                npm install -g @openai/codex 2>/dev/null || \
                    echo "[WARN] Codex CLI installation failed"
            fi
        fi
    '
    ok "$container fully configured"
}

# -----------------------------------------------------------------------------
# dev-flutter container
# -----------------------------------------------------------------------------
setup_dev_flutter() {
    local container="dev-flutter"

    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN} Setting up $container${NC}"
    echo -e "${CYAN}============================================${NC}"

    # Create container if it doesn't exist
    if toolbox list --containers 2>/dev/null | grep -q "$container"; then
        ok "$container container already exists"
    else
        info "Creating $container container..."
        toolbox create --name "$container" 2>/dev/null || toolbox create "$container"
        ok "$container container created"
    fi

    # Terminal environment
    setup_terminal_in_container "$container"

    # Flutter-specific system dependencies
    info "Installing Flutter dependencies in $container..."
    toolbox run --container "$container" sudo dnf install -y \
        clang cmake ninja-build \
        gtk3-devel \
        pkg-config \
        mesa-libGLU-devel \
        java-17-openjdk-devel \
        xz \
        2>/dev/null || warn "Some Flutter dependencies may have failed"

    # Flutter SDK + Android tools + AI tools
    info "Setting up Flutter SDK and dev tools in $container..."
    toolbox run --container "$container" bash -c '
        export PATH="$HOME/.local/bin:$PATH"

        # -----------------------------------------------------------------
        # Flutter SDK
        # -----------------------------------------------------------------
        FLUTTER_DIR="$HOME/.flutter-sdk"
        if [[ ! -d "$FLUTTER_DIR" ]]; then
            echo "[INFO] Installing Flutter SDK..."
            git clone https://github.com/flutter/flutter.git -b stable "$FLUTTER_DIR"
            export PATH="$FLUTTER_DIR/bin:$PATH"
            flutter precache
            echo "[OK] Flutter SDK installed"
        else
            echo "[OK] Flutter SDK already exists"
            export PATH="$FLUTTER_DIR/bin:$PATH"
        fi

        # -----------------------------------------------------------------
        # Android command-line tools
        # -----------------------------------------------------------------
        ANDROID_HOME="$HOME/.android-sdk"
        if [[ ! -d "$ANDROID_HOME/cmdline-tools" ]]; then
            echo "[INFO] Installing Android command-line tools..."
            mkdir -p "$ANDROID_HOME"
            CMDLINE_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
            wget -q "$CMDLINE_TOOLS_URL" -O /tmp/cmdline-tools.zip
            unzip -q /tmp/cmdline-tools.zip -d "$ANDROID_HOME/cmdline-tools-tmp"
            mkdir -p "$ANDROID_HOME/cmdline-tools/latest"
            mv "$ANDROID_HOME/cmdline-tools-tmp/cmdline-tools/"* "$ANDROID_HOME/cmdline-tools/latest/"
            rm -rf "$ANDROID_HOME/cmdline-tools-tmp" /tmp/cmdline-tools.zip

            export ANDROID_HOME
            export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

            yes | sdkmanager --licenses 2>/dev/null || true
            sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0" 2>/dev/null || \
                echo "[WARN] Some Android SDK components may have failed"
            echo "[OK] Android SDK installed"
        else
            echo "[OK] Android SDK already exists"
        fi

        # -----------------------------------------------------------------
        # AI coding tools (fnm is in ~/.local/bin, shared from host)
        # -----------------------------------------------------------------
        if command -v fnm &>/dev/null; then
            eval "$(fnm env)" 2>/dev/null || true

            if ! command -v claude &>/dev/null; then
                echo "[INFO] Installing Claude Code..."
                npm install -g @anthropic-ai/claude-code 2>/dev/null || \
                    echo "[WARN] Claude Code installation failed (known ARM64 issues)"
            fi

            if ! command -v codex &>/dev/null; then
                echo "[INFO] Installing OpenAI Codex CLI..."
                npm install -g @openai/codex 2>/dev/null || \
                    echo "[WARN] Codex CLI installation failed"
            fi
        fi

        # -----------------------------------------------------------------
        # Flutter doctor
        # -----------------------------------------------------------------
        export PATH="$FLUTTER_DIR/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
        export ANDROID_HOME
        echo ""
        echo "[INFO] Running flutter doctor..."
        flutter doctor || true
    '
    ok "$container fully configured"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN} Dev Container Setup (Toolbx)${NC}"
    echo -e "${CYAN}========================================${NC}"

    if ! command -v toolbox &>/dev/null; then
        warn "toolbox not found. Is this Fedora Atomic?"
        exit 1
    fi

    setup_dev_web
    setup_dev_flutter

    echo ""
    ok "All containers ready!"
    echo ""
    echo "  Enter web container:     toolbox enter dev-web"
    echo "  Enter flutter container:  toolbox enter dev-flutter"
    echo ""
}

main "$@"
