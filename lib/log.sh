# shellcheck shell=bash
# lib/log.sh — output helpers and dry-run primitives (sourced by setup.sh)

BOLD="\033[1m"
GREEN="\033[0;32m"
CYAN="\033[0;36m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
MAGENTA="\033[0;35m"
RESET="\033[0m"

info()    { echo -e "${CYAN}[tui_zening]${RESET} $1"; }
success() { echo -e "${GREEN}[tui_zening]${RESET} $1"; }
warn()    { echo -e "${YELLOW}[tui_zening]${RESET} $1"; }
die()     { echo -e "${RED}[tui_zening] ERROR:${RESET} $1"; exit 1; }

# Dry-run: announce a mutation that is being skipped.
would()   { echo -e "${MAGENTA}[dry-run]${RESET} would $1"; }

# Copy a file into place, backing up any existing non-identical target.
# Usage: deploy_file <src> <dst> <label>
deploy_file() {
    local src="$1" dst="$2" label="$3"
    if [[ "$DRY_RUN" == true ]]; then
        would "deploy $label → $dst"
        return 0
    fi
    mkdir -p "$(dirname "$dst")"
    if [[ -f "$dst" ]] && ! cmp -s "$src" "$dst"; then
        local bak="${dst}.bak.$(date +%Y%m%d_%H%M%S)"
        cp "$dst" "$bak"
        info "$label backed up → $bak"
    fi
    cp "$src" "$dst"
    success "$label deployed → $dst"
}
