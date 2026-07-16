#!/usr/bin/env bash
# ============================================================
#  tui_zening — bootstrap
#
#  One-liner setup on a fresh machine:
#    curl -fsSL https://raw.githubusercontent.com/roundzero-ai/tui-zening/main/bootstrap.sh | bash
#    curl -fsSL https://raw.githubusercontent.com/roundzero-ai/tui-zening/main/bootstrap.sh | bash -s -- --headless
#
#  Clones (or updates) the repo into ~/Workspace/tui-zening, then
#  hands every argument through to setup.sh.
#  Override the location with TUI_ZENING_DIR=/some/path.
# ============================================================

set -euo pipefail

DEST="${TUI_ZENING_DIR:-$HOME/Workspace/tui-zening}"
REPO="https://github.com/roundzero-ai/tui-zening.git"

command -v git &>/dev/null || {
    echo "[bootstrap] ERROR: git is required. Install it first (macOS: xcode-select --install, Ubuntu: sudo apt-get install -y git)." >&2
    exit 1
}

if [[ -d "$DEST/.git" ]]; then
    echo "[bootstrap] Updating existing checkout: $DEST"
    if ! git -C "$DEST" pull --ff-only; then
        echo "[bootstrap] Checkout has diverged — resetting to origin/main."
        git -C "$DEST" fetch origin
        git -C "$DEST" reset --hard origin/main
    fi
else
    echo "[bootstrap] Cloning into $DEST"
    mkdir -p "$(dirname "$DEST")"
    git clone "$REPO" "$DEST"
fi

exec bash "$DEST/setup.sh" "$@"
