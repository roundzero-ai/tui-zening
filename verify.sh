#!/usr/bin/env bash
# ============================================================
#  tui_zening — verification gate
#
#  Must pass before any commit is pushed (see AGENTS.md).
#  Also run by CI (.github/workflows/verify.yml).
#
#  Checks:
#    1. bash -n syntax check on every shell script
#    2. shellcheck on every shell script (when installed)
#    3. setup.sh --dry-run end-to-end against a throwaway $HOME
#    4. repo invariants (CLAUDE.md symlink, ghostty include line)
# ============================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

FAILURES=0

pass() { echo "  ok    $1"; }
fail() { echo "  FAIL  $1"; FAILURES=$((FAILURES + 1)); }

SHELL_FILES=(setup.sh bootstrap.sh sync-fleet.sh verify.sh lib/*.sh)

echo "==> 1/4 bash -n syntax check"
for f in "${SHELL_FILES[@]}"; do
    if bash -n "$f" 2>&1; then
        pass "$f"
    else
        fail "$f"
    fi
done

echo "==> 2/4 shellcheck"
if command -v shellcheck &>/dev/null; then
    if shellcheck -S error -x "${SHELL_FILES[@]}"; then
        pass "shellcheck -S error"
    else
        fail "shellcheck -S error"
    fi
else
    echo "  skip  shellcheck not installed (CI runs it; brew/apt install shellcheck locally)"
fi

echo "==> 3/4 setup.sh --dry-run (throwaway \$HOME)"
FAKE_HOME="$(mktemp -d)"
if HOME="$FAKE_HOME" bash setup.sh --dry-run --headless > "$FAKE_HOME/dry-run.log" 2>&1; then
    pass "setup.sh --dry-run --headless exits 0"
else
    fail "setup.sh --dry-run --headless failed:"
    tail -20 "$FAKE_HOME/dry-run.log" | sed 's/^/        /'
fi
# Dry run must not create anything in $HOME.
# Tool-internal caches don't count: brew/oh-my-posh write their own caches
# (e.g. Library/Caches/Homebrew) even for read-only queries.
LEAKED="$(find "$FAKE_HOME" -mindepth 1 \
    -not -name 'dry-run.log' \
    -not -path "$FAKE_HOME/Library" \
    -not -path "$FAKE_HOME/Library/Caches*" \
    -not -path "$FAKE_HOME/.cache*" \
    2>/dev/null)"
if [[ -z "$LEAKED" ]]; then
    pass "dry run wrote nothing to \$HOME"
else
    fail "dry run leaked files into \$HOME:"
    echo "$LEAKED" | sed 's/^/        /'
fi
rm -rf "$FAKE_HOME"

echo "==> 4/4 repo invariants"
if [[ -L CLAUDE.md && "$(readlink CLAUDE.md)" == "AGENTS.md" ]]; then
    pass "CLAUDE.md is a symlink to AGENTS.md"
else
    fail "CLAUDE.md must be a symlink to AGENTS.md"
fi
if grep -q '^config-file = ?zengarden-keys.conf' config/ghostty; then
    pass "config/ghostty includes zengarden-keys.conf"
else
    fail "config/ghostty is missing the 'config-file = ?zengarden-keys.conf' include"
fi
if grep -qE '^keybind' config/ghostty; then
    fail "config/ghostty defines keybinds — they belong in tmux-zengarden/ghostty-keys.conf"
else
    pass "config/ghostty defines no keybinds (keymap owned by tmux-zengarden)"
fi

echo ""
if [[ "$FAILURES" -gt 0 ]]; then
    echo "verify: $FAILURES check(s) FAILED — do not push."
    exit 1
fi
echo "verify: all checks passed."
