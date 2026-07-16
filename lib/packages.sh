# shellcheck shell=bash
# lib/packages.sh — Homebrew, core tools, tmux, oh-my-posh, autosuggestions, fonts
# (sourced by setup.sh)

install_homebrew() {
    [[ "$OS" == "Darwin" ]] || return 0
    if ! command -v brew &>/dev/null; then
        if [[ "$DRY_RUN" == true ]]; then
            would "install Homebrew"
            return 0
        fi
        info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        [[ -f /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        info "Homebrew $(brew --version | head -1) — already installed."
    fi
}

install_core_packages() {
    install_pkg git  git
    install_pkg curl curl
    [[ "$OS" == "Linux" ]] && install_pkg unzip unzip   # needed for yazi binary

    # macOS ships pico 5.09 as /usr/bin/nano — it lacks bracketed paste support,
    # which causes multi-line paste into nano (inside tmux) to lose line breaks.
    # Install GNU nano via Homebrew so the modern version takes precedence.
    if [[ "$OS" == "Darwin" ]]; then
        if ! brew list nano &>/dev/null; then
            if [[ "$DRY_RUN" == true ]]; then
                would "install GNU nano via Homebrew"
            else
                info "Installing GNU nano (macOS system nano lacks bracketed paste)..."
                brew install nano
            fi
        else
            info "GNU nano (brew) — already installed."
        fi
    fi

    install_pkg tmux tmux
}

install_oh_my_posh() {
    if ! command -v oh-my-posh &>/dev/null; then
        if [[ "$DRY_RUN" == true ]]; then
            would "install oh-my-posh"
            return 0
        fi
        info "Installing oh-my-posh..."
        if [[ "$OS" == "Darwin" ]]; then
            brew install jandedobbeleer/oh-my-posh/oh-my-posh
        else
            mkdir -p "$HOME/.local/bin"
            export PATH="$HOME/.local/bin:$PATH"
            curl -fsSL https://ohmyposh.dev/install.sh | bash -s -- -d ~/.local/bin
        fi
    else
        info "oh-my-posh — already installed."
    fi
}

install_zsh_autosuggestions() {
    ZSH_AUTOSUGGEST_SOURCE=""
    if [[ "$CURRENT_SHELL" != "zsh" ]]; then
        info "bash detected — skipping zsh-autosuggestions."
        return 0
    fi
    if [[ "$OS" == "Darwin" ]]; then
        if ! command -v brew &>/dev/null; then
            # Fresh Mac in dry-run: Homebrew itself is still pending
            would "install zsh-autosuggestions via Homebrew"
            return 0
        fi
        local path
        path="$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
        if [[ ! -f "$path" ]]; then
            if [[ "$DRY_RUN" == true ]]; then
                would "install zsh-autosuggestions via Homebrew"
            else
                info "Installing zsh-autosuggestions..."
                brew install zsh-autosuggestions
            fi
        else
            info "zsh-autosuggestions — already installed."
        fi
        ZSH_AUTOSUGGEST_SOURCE="source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
    else
        local dir="$HOME/.zsh/zsh-autosuggestions"
        if [[ ! -f "$dir/zsh-autosuggestions.zsh" ]]; then
            if [[ "$DRY_RUN" == true ]]; then
                would "clone zsh-autosuggestions → $dir"
            else
                info "Installing zsh-autosuggestions..."
                git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$dir"
            fi
        else
            info "zsh-autosuggestions — already installed."
        fi
        ZSH_AUTOSUGGEST_SOURCE="source $dir/zsh-autosuggestions.zsh"
    fi
}

install_fonts() {
    if [[ "$SKIP_FONTS" == true ]]; then
        info "Skipping fonts."
        return 0
    fi
    if fc-list 2>/dev/null | grep -qi "JetBrainsMono"; then
        info "JetBrainsMono Nerd Font — already installed."
        return 0
    fi
    if [[ "$DRY_RUN" == true ]]; then
        would "install JetBrainsMono Nerd Font"
        return 0
    fi
    info "Installing JetBrainsMono Nerd Font..."
    if [[ "$OS" == "Darwin" ]]; then
        brew install --cask font-jetbrains-mono-nerd-font
    else
        local font_dir="$HOME/.local/share/fonts/JetBrainsMono"
        mkdir -p "$font_dir"
        curl -fL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz" \
            | tar -xJ -C "$font_dir"
        if command -v fc-cache &>/dev/null; then
            fc-cache -fv "$font_dir" &>/dev/null
        fi
        info "Font installed → $font_dir"
    fi
}
