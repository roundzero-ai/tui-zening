# shellcheck shell=bash
# lib/rc.sh — shell RC file patching, idempotent (sourced by setup.sh)

patch_rc() {
    local marker="$1" block="$2"
    # Safety: ensure the marker appears in the block so future runs can detect it
    if [[ "$block" != *"$marker"* ]]; then
        die "patch_rc bug: marker '$marker' not found in block — would duplicate on every run"
    fi
    if grep -qF "$marker" "$RC_FILE" 2>/dev/null; then
        info "$RC_FILE: '$marker' — already present."
    elif [[ "$DRY_RUN" == true ]]; then
        would "add '$marker' block to $RC_FILE"
    else
        info "$RC_FILE: adding '$marker'"
        printf "\n%s\n" "$block" >> "$RC_FILE"
    fi
}

# Remove a previously-installed multi-line block delimited by its comment header
# line through the first standalone `fi`. Used to migrate retired blocks.
remove_rc_block() {
    local header="$1"
    [[ -f "$RC_FILE" ]] || return 0
    if grep -qF "$header" "$RC_FILE"; then
        if [[ "$DRY_RUN" == true ]]; then
            would "remove legacy block '$header' from $RC_FILE"
            return 0
        fi
        info "$RC_FILE: removing legacy block '$header'"
        # sed -i.bak works on both GNU sed and BSD sed (macOS)
        sed -i.bak "/^${header//\//\\/}\$/,/^fi\$/d" "$RC_FILE"
        rm -f "${RC_FILE}.bak"
    fi
}

patch_shell_rc() {
    [[ "$DRY_RUN" == true ]] || touch "$RC_FILE"

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

    patch_rc "oh-my-posh init" \
"# oh-my-posh shell prompt
if [ \"\$TERM_PROGRAM\" != \"Apple_Terminal\" ]; then
  eval \"\$(oh-my-posh init ${CURRENT_SHELL} --config ${OMP_CONFIG})\"
fi"

    # zsh-autosuggestions (zsh only)
    if [[ -n "$ZSH_AUTOSUGGEST_SOURCE" ]]; then
        patch_rc "zsh-autosuggestions.zsh" "$ZSH_AUTOSUGGEST_SOURCE"
    fi

    # tmux auto-attach: unified behavior for both local Ghostty and SSH sessions
    #
    # Behavior: on entering an interactive Ghostty or SSH shell, attach to any
    # already-live tmux session on this machine. If no session exists, create one
    # named after the short hostname. Single name, single attach rule — no more
    # "Main | ..." vs "RZ-AI | ..." split.
    #
    # Migrate users who installed older versions of this script: drop the two
    # legacy blocks before adding the new unified one.
    remove_rc_block "# Auto-attach or start tmux when opening a local Ghostty window"
    remove_rc_block "# Auto-attach or start tmux on SSH login"

    patch_rc 'tui_zening: auto-attach tmux' \
'# tui_zening: auto-attach tmux on interactive Ghostty or SSH shell.
# Attaches to any existing session if one is live; otherwise starts a new
# one named after the short hostname.
if [ -z "$TMUX" ] && [ -t 1 ] && { [ -n "$SSH_TTY" ] || [ "$TERM_PROGRAM" = "ghostty" ]; }; then
  if tmux ls >/dev/null 2>&1; then
    exec tmux attach
  else
    exec tmux new-session -s "$(hostname -s)"
  fi
fi'

    # yazi `y` wrapper — changes shell CWD to directory yazi exits in
    if [[ "$INSTALL_YAZI" == true ]]; then
        patch_rc "yazi-cwd.XXXXXX" \
'# yazi shell wrapper: `y` to launch yazi and cd into the last directory on exit
function y() {
    local tmp cwd
    tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        builtin cd -- "$cwd"
    fi
    rm -f -- "$tmp"
}'
    fi

    # SSH mouse-reset wrapper — clears tmux mouse tracking on unexpected disconnect
    patch_rc "ssh_mouse_reset" \
'# ssh_mouse_reset — clear tmux mouse tracking after SSH disconnect
ssh() {
    command ssh "$@"
    printf '"'"'\033[?1000l\033[?1002l\033[?1003l\033[?1006l\033[?1015l'"'"'
}'
}
