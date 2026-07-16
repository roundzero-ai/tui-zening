# shellcheck shell=bash
# lib/ghostty.sh — Ghostty install + config deployment (sourced by setup.sh)
#
# Two files are deployed into the Ghostty config dir:
#   config               — appearance/behavior (this repo: config/ghostty)
#   zengarden-keys.conf  — tmux keymap aliases (from tmux-zengarden: ghostty-keys.conf)
# The main config includes the keys file via `config-file = ?zengarden-keys.conf`.

setup_ghostty() {
    if [[ "$SKIP_GHOSTTY" == true ]]; then
        info "Skipping Ghostty."
        return 0
    fi

    if [[ "$OS" == "Darwin" ]]; then
        # macOS: install via Homebrew cask if not present
        if ! command -v ghostty &>/dev/null && [[ ! -d "/Applications/Ghostty.app" ]]; then
            if [[ "$DRY_RUN" == true ]]; then
                would "install Ghostty via Homebrew cask"
            else
                info "Installing Ghostty..."
                brew install --cask ghostty
            fi
        else
            info "Ghostty — already installed."
        fi
        GHOSTTY_CONF_DIR="$HOME/Library/Application Support/com.mitchellh.ghostty"
    else
        # Linux: try package manager first, then snap
        if ! command -v ghostty &>/dev/null; then
            if [[ "$DRY_RUN" == true ]]; then
                would "install Ghostty (package manager, then snap fallback)"
            # On headless Pi 4: skip PM/snap entirely (no sudo TTY available)
            elif [[ ! -t 0 ]] && _is_raspi4; then
                warn "Ghostty not available on headless Pi 4 (no sudo TTY) — skipping."
                warn "Install manually: https://ghostty.org/docs/install/binary"
                SKIP_GHOSTTY=true
            else
                info "Trying official Ghostty package..."
                if $PM_INSTALL ghostty 2>/dev/null && command -v ghostty &>/dev/null; then
                    success "Ghostty installed via package manager."
                elif command -v snap &>/dev/null && [[ -t 0 || "$EUID" -eq 0 ]]; then
                    info "Package manager failed — trying snap..."
                    $SUDO snap install ghostty --classic
                    success "Ghostty installed via snap."
                else
                    warn "Ghostty not available — skipping."
                    warn "Install manually: https://ghostty.org/docs/install/binary"
                    SKIP_GHOSTTY=true
                fi
            fi
        else
            info "Ghostty — already installed."
        fi
        GHOSTTY_CONF_DIR="$HOME/.config/ghostty"
    fi

    [[ "$SKIP_GHOSTTY" == true ]] && return 0

    GHOSTTY_CONF="$GHOSTTY_CONF_DIR/config"
    deploy_file "$SCRIPT_DIR/config/ghostty" "$GHOSTTY_CONF" "Ghostty config"

    # Keymap layer from tmux-zengarden (see header comment)
    if [[ -n "$ZENGARDEN_DIR" && -f "$ZENGARDEN_DIR/ghostty-keys.conf" ]]; then
        deploy_file "$ZENGARDEN_DIR/ghostty-keys.conf" "$GHOSTTY_CONF_DIR/zengarden-keys.conf" "Ghostty ZenGarden keymap"
    elif [[ "$DRY_RUN" == true ]]; then
        would "deploy zengarden-keys.conf (after tmux-zengarden clone)"
    else
        warn "ghostty-keys.conf not found in tmux-zengarden checkout — Ghostty keymap layer not deployed."
    fi
}
