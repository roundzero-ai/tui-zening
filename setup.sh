#!/usr/bin/env bash
# ============================================================
#  tui_zening — terminal environment setup
#  Brings MacBook Pro, Mac Studio, and DGX Spark GB10
#  into a consistent terminal state.
#
#  Safe to run repeatedly — all steps are idempotent.
#
#  Usage:  bash setup.sh [options]
#
#  Options:
#    --headless     SSH/remote-only mode: skip Ghostty and fonts
#                   Use this on machines you only access via SSH
#    --no-ghostty   Skip Ghostty installation and config
#    --no-fonts     Skip font installation
#    --yazi         Install yazi file manager (opt-in)
# ============================================================

set -euo pipefail

BOLD="\033[1m"
GREEN="\033[0;32m"
CYAN="\033[0;36m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
RESET="\033[0m"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info()    { echo -e "${CYAN}[tui_zening]${RESET} $1"; }
success() { echo -e "${GREEN}[tui_zening]${RESET} $1"; }
warn()    { echo -e "${YELLOW}[tui_zening]${RESET} $1"; }
die()     { echo -e "${RED}[tui_zening] ERROR:${RESET} $1"; exit 1; }

# ── Parse flags ───────────────────────────────────────────────
SKIP_GHOSTTY=false
SKIP_FONTS=false
INSTALL_YAZI=false
HEADLESS=false
for arg in "$@"; do
    case "$arg" in
        --headless)   HEADLESS=true; SKIP_GHOSTTY=true; SKIP_FONTS=true ;;
        --no-ghostty) SKIP_GHOSTTY=true ;;
        --no-fonts)   SKIP_FONTS=true ;;
        --yazi)       INSTALL_YAZI=true ;;
    esac
done

echo -e "${BOLD}"
echo "  ████████╗██╗   ██╗██╗    ███████╗███████╗███╗   ██╗██╗███╗   ██╗ ██████╗ "
echo "     ██╔══╝██║   ██║██║    ╚══███╔╝██╔════╝████╗  ██║██║████╗  ██║██╔════╝ "
echo "     ██║   ██║   ██║██║      ███╔╝ █████╗  ██╔██╗ ██║██║██╔██╗ ██║██║  ███╗"
echo "     ██║   ██║   ██║██║     ███╔╝  ██╔══╝  ██║╚██╗██║██║██║╚██╗██║██║   ██║"
echo "     ██║   ╚██████╔╝██║    ███████╗███████╗██║ ╚████║██║██║ ╚████║╚██████╔╝"
echo "     ╚═╝    ╚═════╝ ╚═╝    ╚══════╝╚══════╝╚═╝  ╚═══╝╚═╝╚═╝  ╚═══╝ ╚═════╝ "
echo -e "${RESET}"
echo "  Ghostty · oh-my-posh · tmux ZenGarden — Mac + DGX Spark"
[[ "$HEADLESS" == true ]] && echo -e "  ${YELLOW}Headless mode — Ghostty and fonts skipped${RESET}"
echo ""

# ── 0. Detect OS, architecture, and shell ────────────────────
OS="$(uname)"
ARCH="$(uname -m)"
[[ "$OS" == "Darwin" || "$OS" == "Linux" ]] || die "Unsupported OS: $OS"

CURRENT_SHELL="$(basename "${SHELL:-bash}")"
if [[ "$CURRENT_SHELL" == "zsh" ]]; then
    RC_FILE="$HOME/.zshrc"
else
    RC_FILE="$HOME/.bashrc"
    CURRENT_SHELL="bash"
fi

info "Detected: $OS / $ARCH / $CURRENT_SHELL → patching $RC_FILE"

# ── Linux: package manager ────────────────────────────────────
if [[ "$OS" == "Linux" ]]; then
    if command -v apt-get &>/dev/null; then
        PM_INSTALL="sudo apt-get install -y"
        PM_UPDATE="sudo apt-get update -y"
    elif command -v dnf &>/dev/null; then
        PM_INSTALL="sudo dnf install -y"
        PM_UPDATE="sudo dnf check-update -y || true"
    elif command -v pacman &>/dev/null; then
        PM_INSTALL="sudo pacman -S --noconfirm"
        PM_UPDATE="sudo pacman -Sy"
    else
        die "No supported package manager found (apt, dnf, pacman)."
    fi
    info "Updating package index..."
    $PM_UPDATE
fi

# ── Helper: install a package if command is missing ───────────
install_pkg() {
    local cmd="$1" pkg="${2:-$1}"
    if ! command -v "$cmd" &>/dev/null; then
        info "Installing $pkg..."
        if [[ "$OS" == "Darwin" ]]; then brew install "$pkg"
        else $PM_INSTALL "$pkg"; fi
    else
        info "$cmd — already installed."
    fi
}

# ── 1. Homebrew (macOS only) ──────────────────────────────────
if [[ "$OS" == "Darwin" ]]; then
    if ! command -v brew &>/dev/null; then
        info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        [[ -f /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        info "Homebrew $(brew --version | head -1) — already installed."
    fi
fi

# ── 2. Core dependencies ──────────────────────────────────────
install_pkg git  git
install_pkg curl curl
install_pkg bc   bc      # required by tmux-zengarden memory.sh
[[ "$OS" == "Linux" ]] && install_pkg unzip unzip   # needed for yazi binary

# ── 3. tmux ───────────────────────────────────────────────────
install_pkg tmux tmux

# ── 4. oh-my-posh ─────────────────────────────────────────────
if ! command -v oh-my-posh &>/dev/null; then
    info "Installing oh-my-posh..."
    if [[ "$OS" == "Darwin" ]]; then
        brew install jandedobbeleer/oh-my-posh/oh-my-posh
    else
        curl -fsSL https://ohmyposh.dev/install.sh | bash -s -- -d ~/.local/bin
        export PATH="$HOME/.local/bin:$PATH"
    fi
else
    info "oh-my-posh — already installed."
fi

# ── 5. zsh-autosuggestions (zsh only) ─────────────────────────
ZSH_AUTOSUGGEST_SOURCE=""
if [[ "$CURRENT_SHELL" == "zsh" ]]; then
    if [[ "$OS" == "Darwin" ]]; then
        ZSH_AUTOSUGGEST_PATH="$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
        if [[ ! -f "$ZSH_AUTOSUGGEST_PATH" ]]; then
            info "Installing zsh-autosuggestions..."
            brew install zsh-autosuggestions
        else
            info "zsh-autosuggestions — already installed."
        fi
        ZSH_AUTOSUGGEST_SOURCE="source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
    else
        ZSH_AUTOSUGGEST_DIR="$HOME/.zsh/zsh-autosuggestions"
        if [[ ! -f "$ZSH_AUTOSUGGEST_DIR/zsh-autosuggestions.zsh" ]]; then
            info "Installing zsh-autosuggestions..."
            git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$ZSH_AUTOSUGGEST_DIR"
        else
            info "zsh-autosuggestions — already installed."
        fi
        ZSH_AUTOSUGGEST_SOURCE="source $ZSH_AUTOSUGGEST_DIR/zsh-autosuggestions.zsh"
    fi
else
    info "bash detected — skipping zsh-autosuggestions."
fi

# ── 6. JetBrainsMono Nerd Font ────────────────────────────────
if [[ "$SKIP_FONTS" == false ]]; then
    if ! fc-list 2>/dev/null | grep -qi "JetBrainsMono"; then
        info "Installing JetBrainsMono Nerd Font..."
        if [[ "$OS" == "Darwin" ]]; then
            brew install --cask font-jetbrains-mono-nerd-font
        else
            FONT_DIR="$HOME/.local/share/fonts/JetBrainsMono"
            mkdir -p "$FONT_DIR"
            curl -fL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz" \
                | tar -xJ -C "$FONT_DIR"
            fc-cache -fv "$FONT_DIR" &>/dev/null
            info "Font installed → $FONT_DIR"
        fi
    else
        info "JetBrainsMono Nerd Font — already installed."
    fi
else
    info "Skipping fonts."
fi

# ── 7. Ghostty ────────────────────────────────────────────────
if [[ "$SKIP_GHOSTTY" == false ]]; then
    if [[ "$OS" == "Darwin" ]]; then
        # macOS: install via Homebrew cask if not present
        if ! command -v ghostty &>/dev/null && [[ ! -d "/Applications/Ghostty.app" ]]; then
            info "Installing Ghostty..."
            brew install --cask ghostty
        else
            info "Ghostty — already installed."
        fi
        # Deploy config
        GHOSTTY_CONF_DIR="$HOME/Library/Application Support/com.mitchellh.ghostty"
        GHOSTTY_CONF="$GHOSTTY_CONF_DIR/config"
        mkdir -p "$GHOSTTY_CONF_DIR"
    else
        # Linux: try package manager first, then snap
        if ! command -v ghostty &>/dev/null; then
            info "Trying official Ghostty package..."
            if $PM_INSTALL ghostty 2>/dev/null && command -v ghostty &>/dev/null; then
                success "Ghostty installed via package manager."
            elif command -v snap &>/dev/null; then
                info "Package manager failed — trying snap..."
                sudo snap install ghostty --classic
                success "Ghostty installed via snap."
            else
                warn "Ghostty not available — skipping."
                warn "Install manually: https://ghostty.org/docs/install/binary"
                SKIP_GHOSTTY=true
            fi
        else
            info "Ghostty — already installed."
        fi

        if [[ "$SKIP_GHOSTTY" == false ]]; then
            # Deploy config (Linux path: ~/.config/ghostty/config)
            GHOSTTY_CONF_DIR="$HOME/.config/ghostty"
            GHOSTTY_CONF="$GHOSTTY_CONF_DIR/config"
            mkdir -p "$GHOSTTY_CONF_DIR"
        fi
    fi

    # Back up and deploy Ghostty config
    if [[ "$SKIP_GHOSTTY" == false ]]; then
        if [[ -f "$GHOSTTY_CONF" ]]; then
            bak="${GHOSTTY_CONF}.bak.$(date +%Y%m%d_%H%M%S)"
            cp "$GHOSTTY_CONF" "$bak"
            info "Ghostty config backed up → $bak"
        fi
        cp "$SCRIPT_DIR/config/ghostty" "$GHOSTTY_CONF"
        success "Ghostty config deployed → $GHOSTTY_CONF"
    fi
else
    info "Skipping Ghostty."
fi

# ── 8. tmux ZenGarden (clone/update + deploy) ─────────────────
ZENGARDEN_DIR="$HOME/Projects/tmux_zengarden"
ZENGARDEN_REPO="https://github.com/roundzero-ai/tmux-zengarden.git"

if [[ ! -d "$ZENGARDEN_DIR/.git" ]]; then
    info "Cloning tmux-zengarden..."
    mkdir -p "$HOME/Projects"
    git clone "$ZENGARDEN_REPO" "$ZENGARDEN_DIR"
else
    info "Updating tmux-zengarden..."
    git -C "$ZENGARDEN_DIR" pull --ff-only
fi

info "Deploying tmux ZenGarden config..."
bash "$ZENGARDEN_DIR/deploy.sh" --posh

if tmux list-sessions &>/dev/null 2>&1; then
    tmux source-file "$HOME/.tmux.conf" && info "Live tmux session reloaded."
fi

# ── 9. nanorc ─────────────────────────────────────────────────
cp "$SCRIPT_DIR/config/nanorc" "$HOME/.nanorc"
info "nanorc deployed → ~/.nanorc"

# ── 10. Yazi file manager (opt-in via --yazi) ────────────────
if [[ "$INSTALL_YAZI" == true ]]; then
    if command -v yazi &>/dev/null; then
        info "yazi — already installed."
    else
        info "Installing yazi..."
        if [[ "$OS" == "Darwin" ]]; then
            brew install yazi
        else
            case "$ARCH" in
                aarch64|arm64) YAZI_ARCH="aarch64-unknown-linux-musl" ;;
                x86_64)        YAZI_ARCH="x86_64-unknown-linux-musl" ;;
                *) die "Unsupported arch for yazi binary: $ARCH. See https://github.com/sxyazi/yazi" ;;
            esac
            YAZI_TMP="$(mktemp -d)"
            curl -fL "https://github.com/sxyazi/yazi/releases/latest/download/yazi-${YAZI_ARCH}.zip" \
                -o "$YAZI_TMP/yazi.zip"
            unzip -q "$YAZI_TMP/yazi.zip" -d "$YAZI_TMP"
            mkdir -p "$HOME/.local/bin"
            cp "$YAZI_TMP/yazi-${YAZI_ARCH}/yazi" "$HOME/.local/bin/yazi"
            chmod +x "$HOME/.local/bin/yazi"
            rm -rf "$YAZI_TMP"
            success "yazi installed → ~/.local/bin/yazi"
        fi
    fi
fi

# ── 11. Patch shell RC file (idempotent) ──────────────────────
OMP_CONFIG="$HOME/.config/oh-my-posh/zengarden.json"
touch "$RC_FILE"

patch_rc() {
    local marker="$1" block="$2"
    if grep -qF "$marker" "$RC_FILE"; then
        info "$RC_FILE: '$marker' — already present."
    else
        info "$RC_FILE: adding '$marker'"
        printf "\n%s\n" "$block" >> "$RC_FILE"
    fi
}

# TERM — 256-color over SSH
patch_rc "TERM=xterm-256color" \
'export TERM=xterm-256color'

# CLICOLOR — enable color ls on macOS (BSD ls uses CLICOLOR, not --color)
if [[ "$OS" == "Darwin" ]]; then
    patch_rc "CLICOLOR=1" \
'export CLICOLOR=1'
fi

# PATH — ~/.local/bin for oh-my-posh + yazi on Linux
if [[ "$OS" == "Linux" ]]; then
    patch_rc ".local/bin" \
'export PATH="$HOME/.local/bin:$PATH"'
fi

# oh-my-posh — migrate old ~/themes.json path if present
if grep -qF "themes.json" "$RC_FILE" && ! grep -qF "$OMP_CONFIG" "$RC_FILE"; then
    info "$RC_FILE: migrating oh-my-posh config path → $OMP_CONFIG"
    sed -i.bak "s|themes.json|.config/oh-my-posh/zengarden.json|g" "$RC_FILE"
    rm -f "${RC_FILE}.bak"
fi
patch_rc "oh-my-posh init" \
"# oh-my-posh shell prompt
if [ \"\$TERM_PROGRAM\" != \"Apple_Terminal\" ]; then
  eval \"\$(oh-my-posh init ${CURRENT_SHELL} --config ${OMP_CONFIG})\"
fi"

# zsh-autosuggestions (zsh only)
if [[ -n "$ZSH_AUTOSUGGEST_SOURCE" ]]; then
    patch_rc "zsh-autosuggestions.zsh" "$ZSH_AUTOSUGGEST_SOURCE"
fi

# tmux auto-attach on Ghostty (local macOS)
if [[ "$OS" == "Darwin" ]]; then
    patch_rc "attach-session -t main" \
'# Auto-attach or start tmux when opening a local Ghostty window
if [ -z "$TMUX" ] && [ "$TERM_PROGRAM" = "ghostty" ]; then
  tmux attach-session -t main 2>/dev/null || tmux new-session -s main
fi'
fi

# tmux auto-attach on SSH login (Mac Studio, DGX Spark)
patch_rc "new-session -A -s RZ-AI" \
'# Auto-attach or start tmux on SSH login
if [[ -z "$TMUX" ]] && [[ -n "$SSH_TTY" ]] && [[ $- =~ i ]]; then
  exec tmux new-session -A -s RZ-AI
fi'

# ── Done ──────────────────────────────────────────────────────
echo ""
success "All done!"
echo ""
echo -e "  ${BOLD}Deployed:${RESET}"
echo "  tmux ZenGarden    ~/.tmux.conf  (github.com/roundzero-ai/tmux-zengarden)"
echo "  oh-my-posh theme  $OMP_CONFIG"
[[ "$SKIP_GHOSTTY" == false ]] && echo "  Ghostty config    $GHOSTTY_CONF"
echo "  nanorc            ~/.nanorc"
[[ "$INSTALL_YAZI" == true ]] && echo "  yazi              $(command -v yazi 2>/dev/null || echo '~/.local/bin/yazi')"
echo ""
echo -e "  ${BOLD}Next steps:${RESET}"
[[ "$SKIP_GHOSTTY" == false && "$OS" == "Darwin" ]] && echo "  • Restart Ghostty to apply transparency and font settings"
[[ "$SKIP_GHOSTTY" == false && "$OS" == "Linux" ]]  && echo "  • Launch Ghostty from your desktop environment"
echo "  • Reload shell:  source $RC_FILE"
echo "  • Start tmux:    tmux new -s main"
echo ""
echo -e "  ${BOLD}Tmux key bindings:${RESET}"
echo "  Prefix: Ctrl-Space  |  Pane nav: Alt+h/j/k/l  |  Split: prefix+| / prefix+-"
echo "  Bottom pane 25%: prefix+_  |  Right pane 33%: prefix+\\"
echo "  Resize: prefix+H/J/K/L  |  Windows: Alt+1-9  |  Zoom: prefix+z"
echo "  Nested tmux: F12 toggles key passthrough to inner session"
echo ""
