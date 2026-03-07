#!/usr/bin/env bash
# ============================================================
#  tui_zening — terminal environment setup
#  Brings MacBook Pro, Mac Studio, and DGX Spark GB10
#  into a consistent terminal state.
#
#  Safe to run repeatedly — all steps are idempotent.
#
#  Usage:  bash setup.sh [--no-ghostty] [--no-fonts]
#    --no-ghostty   skip Ghostty config (e.g. on remote machines)
#    --no-fonts     skip font installation
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
for arg in "$@"; do
    case "$arg" in
        --no-ghostty) SKIP_GHOSTTY=true ;;
        --no-fonts)   SKIP_FONTS=true ;;
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
echo ""

# ── 0. Detect OS & environment ────────────────────────────────
OS="$(uname)"
ARCH="$(uname -m)"
[[ "$OS" == "Darwin" || "$OS" == "Linux" ]] || die "Unsupported OS: $OS"
info "Detected: $OS / $ARCH"

# Headless Linux (DGX Spark, remote servers): skip Ghostty and fonts
if [[ "$OS" == "Linux" && -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then
    SKIP_GHOSTTY=true
    SKIP_FONTS=true
    info "Headless Linux detected — skipping Ghostty config and fonts."
fi

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

# ── Helper: install a package if the command is missing ───────
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

# ── 2. Core dependencies ──────────────────────────────────────
install_pkg git  git
install_pkg curl curl
install_pkg bc   bc     # used by tmux-zengarden memory.sh

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

# ── 5. zsh + zsh-autosuggestions ─────────────────────────────
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
    install_pkg zsh zsh
    ZSH_AUTOSUGGEST_DIR="$HOME/.zsh/zsh-autosuggestions"
    if [[ ! -f "$ZSH_AUTOSUGGEST_DIR/zsh-autosuggestions.zsh" ]]; then
        info "Installing zsh-autosuggestions..."
        git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$ZSH_AUTOSUGGEST_DIR"
    else
        info "zsh-autosuggestions — already installed."
    fi
    ZSH_AUTOSUGGEST_SOURCE="source $ZSH_AUTOSUGGEST_DIR/zsh-autosuggestions.zsh"
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
fi

# ── 7. tmux ZenGarden (clone/update + deploy) ────────────────
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

# ── 8. Ghostty config (macOS only) ───────────────────────────
if [[ "$OS" == "Darwin" && "$SKIP_GHOSTTY" == false ]]; then
    GHOSTTY_CONF_DIR="$HOME/Library/Application Support/com.mitchellh.ghostty"
    GHOSTTY_CONF="$GHOSTTY_CONF_DIR/config"
    mkdir -p "$GHOSTTY_CONF_DIR"
    if [[ -f "$GHOSTTY_CONF" ]]; then
        bak="${GHOSTTY_CONF}.bak.$(date +%Y%m%d_%H%M%S)"
        cp "$GHOSTTY_CONF" "$bak"
        info "Ghostty config backed up → $bak"
    fi
    cp "$SCRIPT_DIR/config/ghostty" "$GHOSTTY_CONF"
    success "Ghostty config deployed → $GHOSTTY_CONF"
fi

# ── 9. nanorc ─────────────────────────────────────────────────
cp "$SCRIPT_DIR/config/nanorc" "$HOME/.nanorc"
info "nanorc deployed → ~/.nanorc"

# ── 10. Linux clipboard tool ──────────────────────────────────
if [[ "$OS" == "Linux" ]]; then
    if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        install_pkg wl-paste wl-clipboard
        CLIPBOARD_GET="wl-paste"
    else
        install_pkg xclip xclip
        CLIPBOARD_GET="xclip -selection clipboard -o"
    fi
else
    CLIPBOARD_GET="pbpaste"
fi

# ── 11. Patch ~/.zshrc (idempotent) ───────────────────────────
ZSHRC="$HOME/.zshrc"
OMP_CONFIG="$HOME/.config/oh-my-posh/zengarden.json"
touch "$ZSHRC"

# Add a block only if its unique marker is not already present
patch_zshrc() {
    local marker="$1" block="$2"
    if grep -qF "$marker" "$ZSHRC"; then
        info "~/.zshrc: '$marker' — already present."
    else
        info "~/.zshrc: adding '$marker'"
        printf "\n%s\n" "$block" >> "$ZSHRC"
    fi
}

# Disable Ctrl-s flow control (needed for tmux Ctrl-s prefix)
patch_zshrc "stty -ixon" \
"# Disable Ctrl-s flow control so tmux Ctrl-s prefix works
stty -ixon 2>/dev/null || true"

# oh-my-posh: migrate old ~/themes.json path → new zengarden path if present
if grep -qF "themes.json" "$ZSHRC" && ! grep -qF "$OMP_CONFIG" "$ZSHRC"; then
    info "~/.zshrc: migrating oh-my-posh path from ~/themes.json → $OMP_CONFIG"
    sed -i.bak "s|themes.json|.config/oh-my-posh/zengarden.json|g" "$ZSHRC"
    rm -f "${ZSHRC}.bak"
fi
patch_zshrc "oh-my-posh init zsh" \
"# oh-my-posh shell prompt
if [ \"\$TERM_PROGRAM\" != \"Apple_Terminal\" ]; then
  eval \"\$(oh-my-posh init zsh --config $OMP_CONFIG)\"
fi"

# zsh-autosuggestions
patch_zshrc "zsh-autosuggestions.zsh" "$ZSH_AUTOSUGGEST_SOURCE"

# pastefile helper
patch_zshrc "pastefile()" \
"# Paste clipboard into a file; validates JSON before saving
pastefile() {
  local target=\"\$1\"
  [[ -z \"\$target\" ]] && { echo \"Usage: pastefile <file>\"; return 1; }
  local content=\"\$(${CLIPBOARD_GET})\"
  if [[ \"\$target\" == *.json ]]; then
    local pretty=\"\$(echo \"\$content\" | python3 -m json.tool 2>&1)\"
    if [[ \$? -ne 0 ]]; then echo \"Invalid JSON — not saved:\"; echo \"\$pretty\"; return 1; fi
    echo \"\$pretty\" > \"\$target\"
  else
    echo \"\$content\" > \"\$target\"
  fi
  echo \"Saved to \$target\"
}"

# ~/.local/bin on PATH (oh-my-posh install target on Linux)
if [[ "$OS" == "Linux" ]]; then
    patch_zshrc ".local/bin" 'export PATH="$HOME/.local/bin:$PATH"'
fi

# Auto-attach tmux when opening Ghostty
patch_zshrc "tmux attach-session -t main" \
'# Auto-attach or start a named tmux session (skip if already inside tmux)
if [ -z "$TMUX" ] && [ "$TERM_PROGRAM" = "ghostty" ]; then
  tmux attach-session -t main 2>/dev/null || tmux new-session -s main
fi'

# ── Done ──────────────────────────────────────────────────────
echo ""
success "All done!"
echo ""
echo -e "  ${BOLD}Deployed:${RESET}"
echo "  tmux ZenGarden    ~/.tmux.conf  (github.com/roundzero-ai/tmux-zengarden)"
echo "  oh-my-posh theme  $OMP_CONFIG"
[[ "$OS" == "Darwin" && "$SKIP_GHOSTTY" == false ]] && \
echo "  Ghostty config    ~/Library/Application Support/com.mitchellh.ghostty/config"
echo "  nanorc            ~/.nanorc"
echo ""
echo -e "  ${BOLD}Next steps:${RESET}"
[[ "$OS" == "Darwin" && "$SKIP_GHOSTTY" == false ]] && echo "  • Restart Ghostty to apply transparency and font settings"
echo "  • Reload shell:  source ~/.zshrc"
echo "  • Start tmux:    tmux new -s main"
[[ "$OS" == "Linux" ]] && echo "  • Set zsh default:  chsh -s \$(which zsh)"
echo ""
echo -e "  ${BOLD}Tmux key bindings:${RESET}"
echo "  Prefix: Ctrl-s  |  Pane nav: Alt+h/j/k/l  |  Split: prefix+| / prefix+-"
echo "  Resize: prefix+H/J/K/L  |  Windows: Alt+1-9  |  Zoom: prefix+z"
echo ""
