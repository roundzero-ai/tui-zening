#!/usr/bin/env bash
set -e

BOLD="\033[1m"
GREEN="\033[0;32m"
CYAN="\033[0;36m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
RESET="\033[0m"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info()    { echo -e "${CYAN}[tmux-cool]${RESET} $1"; }
success() { echo -e "${GREEN}[tmux-cool]${RESET} $1"; }
warn()    { echo -e "${YELLOW}[tmux-cool]${RESET} $1"; }
die()     { echo -e "${RED}[tmux-cool] ERROR:${RESET} $1"; exit 1; }

echo -e "${BOLD}"
echo "  ████████╗███╗   ███╗██╗   ██╗██╗  ██╗      ██████╗ ██████╗  ██████╗ ██╗     "
echo "     ██╔══╝████╗ ████║██║   ██║╚██╗██╔╝     ██╔════╝██╔═══██╗██╔═══██╗██║     "
echo "     ██║   ██╔████╔██║██║   ██║ ╚███╔╝      ██║     ██║   ██║██║   ██║██║     "
echo "     ██║   ██║╚██╔╝██║██║   ██║ ██╔██╗      ██║     ██║   ██║██║   ██║██║     "
echo "     ██║   ██║ ╚═╝ ██║╚██████╔╝██╔╝ ██╗     ╚██████╗╚██████╔╝╚██████╔╝███████╗"
echo "     ╚═╝   ╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═╝      ╚═════╝ ╚═════╝  ╚═════╝ ╚══════╝"
echo -e "${RESET}"
echo "  Pinned top-bar terminal setup for macOS and Linux"
echo ""

# ── 0. Detect OS ──────────────────────────────────────────────────────────────
OS="$(uname)"
[[ "$OS" == "Darwin" || "$OS" == "Linux" ]] || die "Unsupported OS: $OS"
info "Detected OS: $OS"

# ── Linux: detect package manager ────────────────────────────────────────────
if [[ "$OS" == "Linux" ]]; then
  if command -v apt-get &>/dev/null; then
    PM="apt"
    PM_INSTALL="sudo apt-get install -y"
    PM_UPDATE="sudo apt-get update -y"
  elif command -v dnf &>/dev/null; then
    PM="dnf"
    PM_INSTALL="sudo dnf install -y"
    PM_UPDATE="sudo dnf check-update -y || true"
  elif command -v pacman &>/dev/null; then
    PM="pacman"
    PM_INSTALL="sudo pacman -S --noconfirm"
    PM_UPDATE="sudo pacman -Sy"
  elif command -v zypper &>/dev/null; then
    PM="zypper"
    PM_INSTALL="sudo zypper install -y"
    PM_UPDATE="sudo zypper refresh"
  else
    die "No supported package manager found (apt, dnf, pacman, zypper)."
  fi
  info "Package manager: $PM"
  $PM_UPDATE
fi

# ── 1. Homebrew (macOS only) ──────────────────────────────────────────────────
if [[ "$OS" == "Darwin" ]]; then
  if ! command -v brew &>/dev/null; then
    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [[ -f /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
  else
    info "Homebrew already installed — skipping."
  fi
fi

# ── 2. tmux ───────────────────────────────────────────────────────────────────
if ! command -v tmux &>/dev/null; then
  info "Installing tmux..."
  if [[ "$OS" == "Darwin" ]]; then
    brew install tmux
  else
    $PM_INSTALL tmux
  fi
else
  info "tmux $(tmux -V) already installed — skipping."
fi

# ── 3. oh-my-posh ─────────────────────────────────────────────────────────────
if ! command -v oh-my-posh &>/dev/null; then
  info "Installing oh-my-posh..."
  if [[ "$OS" == "Darwin" ]]; then
    brew install jandedobbeleer/oh-my-posh/oh-my-posh
  else
    curl -s https://ohmyposh.dev/install.sh | bash -s -- -d ~/.local/bin
    export PATH="$HOME/.local/bin:$PATH"
  fi
else
  info "oh-my-posh already installed — skipping."
fi

# ── 4. zsh + zsh-autosuggestions ─────────────────────────────────────────────
if [[ "$OS" == "Darwin" ]]; then
  ZSH_AUTOSUGGEST_PATH="$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
  if [[ ! -f "$ZSH_AUTOSUGGEST_PATH" ]]; then
    info "Installing zsh-autosuggestions..."
    brew install zsh-autosuggestions
  else
    info "zsh-autosuggestions already installed — skipping."
  fi
  ZSH_AUTOSUGGEST_SOURCE="source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
else
  # Ensure zsh is installed
  if ! command -v zsh &>/dev/null; then
    info "Installing zsh..."
    $PM_INSTALL zsh
  fi
  ZSH_AUTOSUGGEST_DIR="$HOME/.zsh/zsh-autosuggestions"
  if [[ ! -f "$ZSH_AUTOSUGGEST_DIR/zsh-autosuggestions.zsh" ]]; then
    info "Installing zsh-autosuggestions..."
    git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_AUTOSUGGEST_DIR"
  else
    info "zsh-autosuggestions already installed — skipping."
  fi
  ZSH_AUTOSUGGEST_SOURCE="source $ZSH_AUTOSUGGEST_DIR/zsh-autosuggestions.zsh"
fi

# ── 5. Nerd Font (JetBrainsMono) ─────────────────────────────────────────────
if ! fc-list 2>/dev/null | grep -qi "JetBrainsMono"; then
  info "Installing JetBrainsMono Nerd Font..."
  if [[ "$OS" == "Darwin" ]]; then
    brew install --cask font-jetbrains-mono-nerd-font
  else
    FONT_DIR="$HOME/.local/share/fonts/JetBrainsMono"
    mkdir -p "$FONT_DIR"
    FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz"
    curl -fL "$FONT_URL" | tar -xJ -C "$FONT_DIR"
    fc-cache -fv "$FONT_DIR" &>/dev/null
    info "Font installed to $FONT_DIR"
  fi
else
  info "JetBrainsMono Nerd Font already installed — skipping."
fi

# ── 6. clipboard tool (Linux only) ───────────────────────────────────────────
if [[ "$OS" == "Linux" ]]; then
  if [[ -n "$WAYLAND_DISPLAY" ]]; then
    if ! command -v wl-paste &>/dev/null; then
      info "Installing wl-clipboard (Wayland)..."
      $PM_INSTALL wl-clipboard
    fi
    CLIPBOARD_GET="wl-paste"
  else
    if ! command -v xclip &>/dev/null; then
      info "Installing xclip (X11)..."
      $PM_INSTALL xclip
    fi
    CLIPBOARD_GET="xclip -selection clipboard -o"
  fi
fi

# ── 7. TPM (Tmux Plugin Manager) ─────────────────────────────────────────────
if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
  info "Installing TPM..."
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
else
  info "TPM already installed — skipping."
fi

# ── 8. Copy config files ──────────────────────────────────────────────────────
info "Copying tmux.conf → ~/.tmux.conf"
cp "$SCRIPT_DIR/config/tmux.conf" "$HOME/.tmux.conf"

info "Copying themes.json → ~/themes.json"
cp "$SCRIPT_DIR/config/themes.json" "$HOME/themes.json"

info "Installing RAM script → ~/.config/tmux/scripts/ram_usage.sh"
mkdir -p "$HOME/.config/tmux/scripts"
cp "$SCRIPT_DIR/config/scripts/ram_usage.sh" "$HOME/.config/tmux/scripts/ram_usage.sh"
chmod +x "$HOME/.config/tmux/scripts/ram_usage.sh"

info "Copying nanorc → ~/.nanorc"
cp "$SCRIPT_DIR/config/nanorc" "$HOME/.nanorc"

# ── 9. Install tmux plugins ───────────────────────────────────────────────────
info "Installing tmux plugins via TPM..."
"$HOME/.tmux/plugins/tpm/bin/install_plugins"

# ── 10. Patch ~/.zshrc ────────────────────────────────────────────────────────
ZSHRC="$HOME/.zshrc"
touch "$ZSHRC"

patch_zshrc() {
  local marker="$1"
  local block="$2"
  if grep -qF "$marker" "$ZSHRC"; then
    warn "~/.zshrc already contains '$marker' — skipping."
  else
    info "Patching ~/.zshrc: $marker"
    printf "\n%s\n" "$block" >> "$ZSHRC"
  fi
}

patch_zshrc "oh-my-posh init zsh" \
'if [ "$TERM_PROGRAM" != "Apple_Terminal" ]; then
  eval "$(oh-my-posh init zsh --config ~/themes.json)"
fi'

patch_zshrc "zsh-autosuggestions.zsh" \
"$ZSH_AUTOSUGGEST_SOURCE"

# pastefile: use pbpaste on macOS, detect clipboard tool on Linux
if [[ "$OS" == "Darwin" ]]; then
  PASTEFILE_GET='pbpaste'
else
  PASTEFILE_GET="$CLIPBOARD_GET"
fi

patch_zshrc "pastefile()" \
"# Paste clipboard content directly into a file (bypasses nano paste corruption)
# Usage: pastefile ~/themes.json
# For JSON: validates and pretty-prints before saving
pastefile() {
  local target=\"\$1\"
  [[ -z \"\$target\" ]] && { echo \"Usage: pastefile <file>\"; return 1; }
  local content
  content=\"\$(${PASTEFILE_GET})\"
  if [[ \"\$target\" == *.json ]]; then
    local pretty
    pretty=\"\$(echo \"\$content\" | python3 -m json.tool 2>&1)\"
    if [[ \$? -ne 0 ]]; then
      echo \"Invalid JSON — not saved. Error:\"
      echo \"\$pretty\"
      return 1
    fi
    echo \"\$pretty\" > \"\$target\"
  else
    echo \"\$content\" > \"\$target\"
  fi
  echo \"Saved to \$target\"
}"

patch_zshrc "tmux attach-session -t main" \
'# Auto-attach or start a tmux session (skip if already inside tmux)
if [ -z "$TMUX" ] && [ "$TERM_PROGRAM" = "ghostty" ]; then
  tmux attach-session -t main 2>/dev/null || tmux new-session -s main
fi'

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
success "Setup complete!"
echo ""
echo -e "  ${BOLD}Next steps:${RESET}"
echo "  1. Set your Ghostty font to 'JetBrainsMono Nerd Font' for icons to render"
echo "  2. Restart Ghostty — tmux will auto-start and the top bar will be pinned"
echo "  3. To reload tmux config manually: tmux source-file ~/.tmux.conf"
if [[ "$OS" == "Linux" ]]; then
  echo "  4. If zsh is not your default shell, run: chsh -s \$(which zsh)"
fi
echo ""
