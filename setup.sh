#!/usr/bin/env bash
# ============================================================
#  tui_zening — terminal environment setup
#  Brings MacBook Pro, Mac Studio, DGX Spark GB10, and Ubuntu
#  machines into a consistent terminal state.
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
#    --yazi         Install yazi + lazygit integration (opt-in)
#    --local        Use sibling ../tmux-zengarden checkout instead of
#                   the GitHub cache (test unpushed changes end-to-end)
#    --dry-run      Report what would be installed/patched; change nothing
#
#  Implementation lives in lib/*.sh; this file is the orchestrator.
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/log.sh
source "$SCRIPT_DIR/lib/log.sh"
# shellcheck source=lib/detect.sh
source "$SCRIPT_DIR/lib/detect.sh"
# shellcheck source=lib/packages.sh
source "$SCRIPT_DIR/lib/packages.sh"
# shellcheck source=lib/ghostty.sh
source "$SCRIPT_DIR/lib/ghostty.sh"
# shellcheck source=lib/zengarden.sh
source "$SCRIPT_DIR/lib/zengarden.sh"
# shellcheck source=lib/yazi.sh
source "$SCRIPT_DIR/lib/yazi.sh"
# shellcheck source=lib/rc.sh
source "$SCRIPT_DIR/lib/rc.sh"

# ── Parse flags ───────────────────────────────────────────────
SKIP_GHOSTTY=false
SKIP_FONTS=false
INSTALL_YAZI=false
HEADLESS=false
LOCAL_MODE=false
DRY_RUN=false
for arg in "$@"; do
    case "$arg" in
        --headless)   HEADLESS=true; SKIP_GHOSTTY=true; SKIP_FONTS=true ;;
        --no-ghostty) SKIP_GHOSTTY=true ;;
        --no-fonts)   SKIP_FONTS=true ;;
        --yazi)       INSTALL_YAZI=true ;;
        --local)      LOCAL_MODE=true ;;
        --dry-run)    DRY_RUN=true ;;
        -h|--help)    grep '^#' "$0" | sed -n '2,22p'; exit 0 ;;
        *)            die "Unknown option: $arg (see --help)" ;;
    esac
done

# Globals set by the lib modules as setup progresses
OS="" ARCH="" CURRENT_SHELL="" RC_FILE=""
SUDO="" PM_INSTALL="" PM_UPDATE="" PM_UPDATED=false
ZENGARDEN_DIR="" GHOSTTY_CONF="" ZSH_AUTOSUGGEST_SOURCE="" OMP_CONFIG=""

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
[[ "$DRY_RUN"  == true ]] && echo -e "  ${MAGENTA}Dry-run mode — nothing will be changed${RESET}"
echo ""

# ── Run ───────────────────────────────────────────────────────
detect_platform
setup_package_manager          # Linux only (no-op on macOS)
install_homebrew               # macOS only (no-op on Linux)
install_core_packages          # git, curl, unzip, nano, tmux
install_oh_my_posh
install_zsh_autosuggestions
install_fonts
resolve_zengarden              # clone/update .cache, or --local sibling
setup_ghostty                  # app + config + zengarden-keys.conf
deploy_zengarden               # ~/.tmux.conf + ~/.tmux/scripts + live reload
deploy_posh_theme              # config/oh-my-posh.json → ~/.config/oh-my-posh/
deploy_file "$SCRIPT_DIR/config/nanorc" "$HOME/.nanorc" "nanorc"
setup_yazi                     # opt-in via --yazi
patch_shell_rc

# ── Done ──────────────────────────────────────────────────────
echo ""
if [[ "$DRY_RUN" == true ]]; then
    success "Dry run complete — nothing was changed."
    exit 0
fi
success "All done!"
echo ""
echo -e "  ${BOLD}Deployed:${RESET}"
echo "  tmux ZenGarden    ~/.tmux.conf  (github.com/roundzero-ai/tmux-zengarden)"
echo "  oh-my-posh theme  $OMP_CONFIG"
[[ "$SKIP_GHOSTTY" == false ]] && echo "  Ghostty config    $GHOSTTY_CONF (+ zengarden-keys.conf)"
echo "  nanorc            ~/.nanorc"
[[ "$INSTALL_YAZI" == true ]] && echo "  yazi              $(command -v yazi 2>/dev/null || echo '~/.local/bin/yazi')"
[[ "$INSTALL_YAZI" == true ]] && echo "  lazygit           $(command -v lazygit 2>/dev/null || echo '~/.local/bin/lazygit')"
[[ "$INSTALL_YAZI" == true ]] && echo "  yazi config       ~/.config/yazi/"
echo ""
echo -e "  ${BOLD}Next steps:${RESET}"
[[ "$SKIP_GHOSTTY" == false && "$OS" == "Darwin" ]] && echo "  • Restart Ghostty to apply transparency and font settings"
[[ "$SKIP_GHOSTTY" == false && "$OS" == "Linux" ]]  && echo "  • Launch Ghostty from your desktop environment"
echo "  • Reload shell:  source $RC_FILE"
echo "  • Start tmux:    tmux new -s \"\$(hostname -s)\""
[[ "$INSTALL_YAZI" == true ]] && echo "  • Launch yazi:   y   (or 'yazi' to skip CWD change on exit)"
[[ "$INSTALL_YAZI" == true ]] && echo "  • In yazi, press g then l to open lazygit"
echo ""
echo -e "  ${BOLD}Tmux key bindings:${RESET}"
echo "  Prefix: Ctrl-Space  |  Pane nav: Alt+h/j/k/l  |  Split: prefix+\\ / prefix+-"
echo "  Bottom pane 25%: prefix+=  |  Right pane 33%: prefix+/"
echo "  Resize: prefix+Arrow keys  |  Windows: Alt+1-9  |  Zoom: prefix+z"
echo "  Window cycle: Alt+Tab"
echo "  Nested tmux: F12 (REMOTE mode) or Ctrl+Alt combos (inner without REMOTE)"
echo "  Inner window select: Ctrl+Alt+1-9  |  Inner cycle: Ctrl+Alt+Tab"
echo "  Inner new window: prefix+Ctrl+c  |  Inner close pane: prefix+Ctrl+x"
echo ""
echo "  Full keybinding reference: github.com/roundzero-ai/tmux-zengarden"
echo ""
