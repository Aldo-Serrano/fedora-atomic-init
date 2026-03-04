#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Phase 3: Create Distrobox containers for development
# =============================================================================

if ! command -v distrobox &>/dev/null; then
    echo "[SKIP] distrobox not found. Install it first (may need reboot after rpm-ostree)."
    exit 0
fi

DEV_HOME="$HOME/Dev/containers"
mkdir -p "$DEV_HOME"

# -----------------------------------------------------------------------------
# dev-web container
# -----------------------------------------------------------------------------
if distrobox list | grep -q "dev-web"; then
    echo "[OK] dev-web container already exists"
else
    echo "[INFO] Creating dev-web container..."
    distrobox create \
        --name dev-web \
        --image registry.fedoraproject.org/fedora-toolbox:latest \
        --home "$DEV_HOME/web" \
        --yes
    echo "[OK] dev-web container created"
fi

# -----------------------------------------------------------------------------
# dev-flutter container
# -----------------------------------------------------------------------------
if distrobox list | grep -q "dev-flutter"; then
    echo "[OK] dev-flutter container already exists"
else
    echo "[INFO] Creating dev-flutter container..."
    distrobox create \
        --name dev-flutter \
        --image registry.fedoraproject.org/fedora-toolbox:latest \
        --home "$DEV_HOME/flutter" \
        --yes
    echo "[OK] dev-flutter container created"
fi

echo "[OK] All containers created"
