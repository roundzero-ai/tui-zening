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
echo "  Pinned top-bar terminal setup for macOS"
echo ""

# ── 0. macOS check ────────────────────────────────────────────────────────────
[[ "$(uname)" == "Darwin" ]] || die "This setup is for macOS only."

# ── 1. Homebrew ───────────────────────────────────────────────────────────────
if ! command -v brew &>/dev/null; then
  info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Add brew to PATH for Apple Silicon
  if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
else
  info "Homebrew already installed — skipping."
fi

# ── 2. tmux ───────────────────────────────────────────────────────────────────
if ! command -v tmux &>/dev/null; then
  info "Installing tmux..."
  brew install tmux
else
  info "tmux $(tmux -V) already installed — skipping."
fi

# ── 3. oh-my-posh ─────────────────────────────────────────────────────────────
if ! command -v oh-my-posh &>/dev/null; then
  info "Installing oh-my-posh..."
  brew install jandedobbeleer/oh-my-posh/oh-my-posh
else
  info "oh-my-posh already installed — skipping."
fi

# ── 4. zsh-autosuggestions ────────────────────────────────────────────────────
if [[ ! -f "$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
  info "Installing zsh-autosuggestions..."
  brew install zsh-autosuggestions
else
  info "zsh-autosuggestions already installed — skipping."
fi

# ── 5. Nerd Font (JetBrainsMono) ─────────────────────────────────────────────
if ! fc-list | grep -qi "JetBrainsMono" 2>/dev/null; then
  info "Installing JetBrainsMono Nerd Font (required for icons)..."
  brew install --cask font-jetbrains-mono-nerd-font
else
  info "JetBrainsMono Nerd Font already installed — skipping."
fi

# ── 6. TPM (Tmux Plugin Manager) ─────────────────────────────────────────────
if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
  info "Installing TPM..."
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
else
  info "TPM already installed — skipping."
fi

# ── 7. Copy config files ──────────────────────────────────────────────────────
info "Copying tmux.conf → ~/.tmux.conf"
cp "$SCRIPT_DIR/config/tmux.conf" "$HOME/.tmux.conf"

info "Copying themes.json → ~/themes.json"
cp "$SCRIPT_DIR/config/themes.json" "$HOME/themes.json"

info "Installing RAM script → ~/.config/tmux/scripts/ram_usage.sh"
mkdir -p "$HOME/.config/tmux/scripts"
cp "$SCRIPT_DIR/config/scripts/ram_usage.sh" "$HOME/.config/tmux/scripts/ram_usage.sh"
chmod +x "$HOME/.config/tmux/scripts/ram_usage.sh"

# ── 8. Install tmux plugins ───────────────────────────────────────────────────
info "Installing tmux plugins via TPM..."
"$HOME/.tmux/plugins/tpm/bin/install_plugins"

# ── 9. Patch ~/.zshrc ─────────────────────────────────────────────────────────
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
'source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh'

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
echo ""
