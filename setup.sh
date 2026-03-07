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
        # Linux: try official package first, fall back to building from source
        if ! command -v ghostty &>/dev/null; then
            GHOSTTY_INSTALLED=false

            # Try official installation first (apt, or distro package)
            info "Trying official Ghostty package..."
            if $PM_INSTALL ghostty 2>/dev/null && command -v ghostty &>/dev/null; then
                GHOSTTY_INSTALLED=true
                success "Ghostty installed via package manager."
            fi

            # Fallback: build from source (works on ARM64 DGX Spark GB10)
            if [[ "$GHOSTTY_INSTALLED" == false ]]; then
                info "Official package not available — building Ghostty from source (this takes a few minutes)..."

                # System build dependencies
                $PM_INSTALL libgtk-4-dev libadwaita-1-dev blueprint-compiler \
                            gettext libxml2-utils xz-utils pkg-config

                # Clone or update Ghostty source
                GHOSTTY_SRC="$HOME/Projects/ghostty_src"
                if [[ ! -d "$GHOSTTY_SRC/.git" ]]; then
                    git clone --depth=1 https://github.com/ghostty-org/ghostty.git "$GHOSTTY_SRC"
                else
                    info "Updating Ghostty source..."
                    git -C "$GHOSTTY_SRC" pull --ff-only
                fi

                # Read the exact Zig version Ghostty requires
                # (Ghostty 1.x uses minimum_zig_version in build.zig.zon, no .zig-version file)
                ZIG_VERSION=$(cat "$GHOSTTY_SRC/.zig-version" 2>/dev/null | tr -d '[:space:]') || true
                if [[ -z "$ZIG_VERSION" ]]; then
                    # Extract from build.zig.zon
                    ZIG_VERSION=$(grep -oP '(?<=minimum_zig_version = ")[^"]+' "$GHOSTTY_SRC/build.zig.zon" 2>/dev/null) || true
                fi
                [[ -z "$ZIG_VERSION" ]] && ZIG_VERSION="0.15.2"
                info "Ghostty requires Zig $ZIG_VERSION"

                # Zig arch name (uname -m returns aarch64 on DGX Spark)
                case "$ARCH" in
                    aarch64|arm64) ZIG_ARCH="aarch64" ;;
                    x86_64)        ZIG_ARCH="x86_64" ;;
                    *) die "Unsupported arch for Zig: $ARCH" ;;
                esac

                # Zig 0.13+ uses zig-ARCH-linux-VERSION naming (old: zig-linux-ARCH-VERSION)
                ZIG_TARBALL="zig-${ZIG_ARCH}-linux-${ZIG_VERSION}.tar.xz"
                ZIG_DIR="$HOME/.local/zig/zig-${ZIG_ARCH}-linux-${ZIG_VERSION}"
                ZIG_BIN="$ZIG_DIR/zig"
                if [[ ! -f "$ZIG_BIN" ]]; then
                    info "Installing Zig $ZIG_VERSION ($ZIG_ARCH)..."
                    mkdir -p "$HOME/.local/zig"
                    curl -fL "https://ziglang.org/download/${ZIG_VERSION}/${ZIG_TARBALL}" \
                        | tar -xJ -C "$HOME/.local/zig"
                else
                    info "Zig $ZIG_VERSION — already installed."
                fi

                # Build Ghostty
                # -fno-sys=gtk4-layer-shell:    Ubuntu 24.04 doesn't package this
                # -fno-sys=blueprint-compiler:  system blueprint 0.12 too old for
                #                              Ghostty 1.x which needs blueprint 1.x
                info "Compiling Ghostty (this takes several minutes)..."
                cd "$GHOSTTY_SRC"
                "$ZIG_BIN" build -Doptimize=ReleaseFast \
                    -fno-sys=gtk4-layer-shell \
                    -fno-sys=blueprint-compiler
                cd - >/dev/null

                # Install binary
                mkdir -p "$HOME/.local/bin"
                cp "$GHOSTTY_SRC/zig-out/bin/ghostty" "$HOME/.local/bin/ghostty"
                chmod +x "$HOME/.local/bin/ghostty"
                export PATH="$HOME/.local/bin:$PATH"
                success "Ghostty built → ~/.local/bin/ghostty"
            fi
        else
            info "Ghostty — already installed."
        fi

        # Deploy config (Linux path: ~/.config/ghostty/config)
        GHOSTTY_CONF_DIR="$HOME/.config/ghostty"
        GHOSTTY_CONF="$GHOSTTY_CONF_DIR/config"
        mkdir -p "$GHOSTTY_CONF_DIR"
    fi

    # Back up and deploy Ghostty config
    if [[ -f "$GHOSTTY_CONF" ]]; then
        bak="${GHOSTTY_CONF}.bak.$(date +%Y%m%d_%H%M%S)"
        cp "$GHOSTTY_CONF" "$bak"
        info "Ghostty config backed up → $bak"
    fi
    cp "$SCRIPT_DIR/config/ghostty" "$GHOSTTY_CONF"
    success "Ghostty config deployed → $GHOSTTY_CONF"
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

# ── 11. Yazi file manager (opt-in via --yazi) ─────────────────
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

# ── 12. Patch shell RC file (idempotent) ──────────────────────
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

# Disable Ctrl-s flow control (required for tmux Ctrl-s prefix)
patch_rc "stty -ixon" \
'# Disable Ctrl-s flow control so tmux Ctrl-s prefix works
stty -ixon 2>/dev/null || true'

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

# pastefile helper
patch_rc "pastefile()" \
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

# tmux auto-attach on Ghostty (local macOS)
if [[ "$OS" == "Darwin" ]]; then
    patch_rc "TERM_PROGRAM.*ghostty.*tmux" \
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
echo "  Prefix: Ctrl-s  |  Pane nav: Alt+h/j/k/l  |  Split: prefix+| / prefix+-"
echo "  Resize: prefix+H/J/K/L  |  Windows: Alt+1-9  |  Zoom: prefix+z"
echo ""
