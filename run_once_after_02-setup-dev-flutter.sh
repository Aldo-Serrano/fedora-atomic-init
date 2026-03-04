#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Phase 4: Configure dev-flutter Distrobox container
# Flutter SDK, Android CLI tools, AI coding assistants
# =============================================================================

CONTAINER="dev-flutter"

if ! distrobox list | grep -q "$CONTAINER"; then
    echo "[SKIP] $CONTAINER container not found. Run setup-containers first."
    exit 0
fi

# Marker to avoid re-running
MARKER="$HOME/.config/fedora-atomic-init/${CONTAINER}-setup-done"
if [[ -f "$MARKER" ]]; then
    echo "[OK] $CONTAINER already configured"
    exit 0
fi

echo "============================================"
echo " Configuring $CONTAINER container"
echo "============================================"

# Run all setup commands inside the container
distrobox enter "$CONTAINER" -- bash -c '
set -euo pipefail

echo "[INFO] Installing system dependencies..."
sudo dnf install -y \
    git curl wget unzip xz \
    clang cmake ninja-build \
    gtk3-devel \
    pkg-config \
    mesa-libGLU-devel \
    java-17-openjdk-devel \
    2>/dev/null || echo "[WARN] Some packages may have failed"

# -------------------------------------------------------------------------
# fnm + Node.js
# -------------------------------------------------------------------------
if ! command -v fnm &>/dev/null; then
    echo "[INFO] Installing fnm..."
    curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir "$HOME/.local/bin" --skip-shell
    export PATH="$HOME/.local/bin:$PATH"
    eval "$(fnm env)"
    fnm install --lts
    fnm default lts-latest
    echo "[OK] Node.js $(node --version) installed"
else
    echo "[OK] fnm already installed"
    export PATH="$HOME/.local/bin:$PATH"
    eval "$(fnm env)" 2>/dev/null || true
fi

# -------------------------------------------------------------------------
# Flutter SDK
# -------------------------------------------------------------------------
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

# -------------------------------------------------------------------------
# Android command-line tools
# -------------------------------------------------------------------------
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
        echo "[WARN] Some Android SDK components may have failed to install"
    echo "[OK] Android SDK installed"
else
    echo "[OK] Android SDK already exists"
fi

# -------------------------------------------------------------------------
# AI coding tools
# -------------------------------------------------------------------------
export PATH="$HOME/.local/bin:$PATH"
eval "$(fnm env)" 2>/dev/null || true

if ! command -v claude &>/dev/null; then
    echo "[INFO] Installing Claude Code..."
    npm install -g @anthropic-ai/claude-code 2>/dev/null || \
        echo "[WARN] Claude Code installation failed (known ARM64 issues). Try again later."
else
    echo "[OK] Claude Code already installed"
fi

if ! command -v codex &>/dev/null; then
    echo "[INFO] Installing OpenAI Codex CLI..."
    npm install -g @openai/codex 2>/dev/null || \
        echo "[WARN] Codex CLI installation failed"
else
    echo "[OK] Codex CLI already installed"
fi

# -------------------------------------------------------------------------
# Flutter doctor check
# -------------------------------------------------------------------------
export PATH="$FLUTTER_DIR/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
export ANDROID_HOME
echo ""
echo "[INFO] Running flutter doctor..."
flutter doctor || true

echo ""
echo "[OK] dev-flutter container setup complete!"
'

# Mark as done
mkdir -p "$(dirname "$MARKER")"
touch "$MARKER"

# Export key binaries to host
echo "[INFO] Exporting flutter binary to host..."
distrobox enter "$CONTAINER" -- distrobox-export --bin "$HOME/.flutter-sdk/bin/flutter" --export-path "$HOME/.local/bin" 2>/dev/null || \
    echo "[WARN] Could not export flutter binary"
distrobox enter "$CONTAINER" -- distrobox-export --bin "$HOME/.flutter-sdk/bin/dart" --export-path "$HOME/.local/bin" 2>/dev/null || \
    echo "[WARN] Could not export dart binary"

echo "[OK] $CONTAINER fully configured"
