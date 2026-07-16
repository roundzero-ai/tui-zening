# shellcheck shell=bash
# lib/zengarden.sh — tmux-zengarden source resolution + deployment, oh-my-posh theme
# (sourced by setup.sh)

ZENGARDEN_REPO="https://github.com/roundzero-ai/tmux-zengarden.git"

# Decide where tmux-zengarden comes from and make sure it's current.
# Normal mode: GitHub clone in .cache/, updated every run.
# --local mode: sibling checkout ../tmux-zengarden, used as-is (for testing
# unpushed changes end-to-end before they reach GitHub main).
resolve_zengarden() {
    if [[ "$LOCAL_MODE" == true ]]; then
        ZENGARDEN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)/tmux-zengarden"
        if [[ ! -f "$ZENGARDEN_DIR/tmux.conf" ]]; then
            die "--local: no tmux-zengarden checkout found at $ZENGARDEN_DIR
       Clone it next to tui-zening:  git clone $ZENGARDEN_REPO $ZENGARDEN_DIR"
        fi
        warn "--local mode: using sibling checkout $ZENGARDEN_DIR (no git pull; may differ from GitHub main)."
        return 0
    fi

    ZENGARDEN_DIR="$SCRIPT_DIR/.cache/tmux-zengarden"
    if [[ ! -d "$ZENGARDEN_DIR/.git" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            would "clone tmux-zengarden → $ZENGARDEN_DIR"
            [[ -f "$ZENGARDEN_DIR/tmux.conf" ]] || ZENGARDEN_DIR=""
            return 0
        fi
        info "Cloning tmux-zengarden..."
        mkdir -p "$(dirname "$ZENGARDEN_DIR")"
        git clone "$ZENGARDEN_REPO" "$ZENGARDEN_DIR"
    else
        if [[ "$DRY_RUN" == true ]]; then
            would "update tmux-zengarden cache (git pull --ff-only)"
            return 0
        fi
        info "Updating tmux-zengarden..."
        if ! git -C "$ZENGARDEN_DIR" pull --ff-only 2>/dev/null; then
            warn "Cache diverged from upstream — resetting to origin/main."
            git -C "$ZENGARDEN_DIR" fetch origin
            git -C "$ZENGARDEN_DIR" reset --hard origin/main
        fi
    fi
}

deploy_zengarden() {
    if [[ "$DRY_RUN" == true ]]; then
        would "run tmux-zengarden deploy.sh (installs ~/.tmux.conf + ~/.tmux/scripts/)"
        would "reload live tmux session if one is running"
        return 0
    fi
    info "Deploying tmux ZenGarden config..."
    bash "$ZENGARDEN_DIR/deploy.sh"

    if tmux list-sessions &>/dev/null 2>&1; then
        tmux source-file "$HOME/.tmux.conf" && info "Live tmux session reloaded."
    fi
}

# oh-my-posh theme (lives in this repo: config/oh-my-posh.json)
deploy_posh_theme() {
    OMP_CONFIG="$HOME/.config/oh-my-posh/zengarden.json"
    deploy_file "$SCRIPT_DIR/config/oh-my-posh.json" "$OMP_CONFIG" "oh-my-posh theme"
}
