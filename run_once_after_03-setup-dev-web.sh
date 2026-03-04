#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Phase 5: Configure dev-web Distrobox container
# Node.js (fnm), React tooling, AI coding assistants
# =============================================================================

CONTAINER="dev-web"

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
sudo dnf install -y git curl wget 2>/dev/null || echo "[WARN] Some packages may have failed"

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
# Global npm packages
# -------------------------------------------------------------------------
export PATH="$HOME/.local/bin:$PATH"
eval "$(fnm env)" 2>/dev/null || true

echo "[INFO] Installing global npm packages..."
npm install -g \
    typescript \
    eslint \
    prettier \
    2>/dev/null || echo "[WARN] Some npm packages may have failed"

# -------------------------------------------------------------------------
# AI coding tools
# -------------------------------------------------------------------------
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

echo ""
echo "[OK] dev-web container setup complete!"
echo "  Node.js: $(node --version)"
echo "  npm: $(npm --version)"
'

# Mark as done
mkdir -p "$(dirname "$MARKER")"
touch "$MARKER"

echo "[OK] $CONTAINER fully configured"
