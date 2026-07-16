#!/usr/bin/env bash
# ============================================================
#  tui_zening — fleet sync
#
#  Pushes the current GitHub main to every machine listed in
#  machines.local: SSH in, clone-or-pull ~/Workspace/tui-zening,
#  run setup.sh with that machine's flags.
#
#  Usage:
#    bash sync-fleet.sh              # all machines in machines.local
#    bash sync-fleet.sh dgx-spark    # only targets whose ssh-target matches
#
#  machines.local format (gitignored — see machines.example):
#    <ssh-target> [setup.sh flags...]
#    e.g.:  taozhang@mac-studio --headless
#
#  Requires: local commits already pushed (machines pull from GitHub),
#  SSH access to each target. Uses ssh -t so sudo prompts work.
# ============================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTS_FILE="$SCRIPT_DIR/machines.local"
REPO="https://github.com/roundzero-ai/tui-zening.git"
REMOTE_DIR="\$HOME/Workspace/tui-zening"

[[ -f "$HOSTS_FILE" ]] || {
    echo "ERROR: $HOSTS_FILE not found."
    echo "Create it from the template:  cp machines.example machines.local"
    exit 1
}

# Warn (don't block) if local work hasn't reached GitHub — machines pull from there.
if [[ -n "$(git -C "$SCRIPT_DIR" status --porcelain 2>/dev/null)" ]]; then
    echo "[!] Working tree has uncommitted changes — machines will NOT get them (they pull GitHub main)."
fi
if [[ -n "$(git -C "$SCRIPT_DIR" log origin/main..HEAD --oneline 2>/dev/null)" ]]; then
    echo "[!] Local commits not pushed to origin/main — machines will NOT get them. Push first."
fi

FILTER=("$@")

PASSED=()
FAILED=()

# Read the hosts file on FD 3 so ssh keeps the terminal as stdin
# (needed for -t / interactive sudo; plain `< file` would feed ssh the list).
while IFS= read -r -u 3 line; do
    # Strip comments and blank lines
    line="${line%%#*}"
    [[ -z "${line// /}" ]] && continue

    read -r target flags <<< "$line"

    # Optional positional filters: only sync targets matching any argument
    if [[ ${#FILTER[@]} -gt 0 ]]; then
        match=false
        for f in "${FILTER[@]}"; do
            [[ "$target" == *"$f"* ]] && match=true
        done
        [[ "$match" == false ]] && continue
    fi

    echo ""
    echo "════════════════════════════════════════════════════════"
    echo "  ⇒ $target   (setup.sh ${flags:-<no flags>})"
    echo "════════════════════════════════════════════════════════"

    # shellcheck disable=SC2029  # REMOTE_DIR expands on the remote by design
    if ssh -t -o ConnectTimeout=10 "$target" \
        "set -e
         if [ -d ${REMOTE_DIR}/.git ]; then
             git -C ${REMOTE_DIR} pull --ff-only || { git -C ${REMOTE_DIR} fetch origin && git -C ${REMOTE_DIR} reset --hard origin/main; }
         else
             mkdir -p \$(dirname ${REMOTE_DIR})
             git clone $REPO ${REMOTE_DIR}
         fi
         bash ${REMOTE_DIR}/setup.sh ${flags}"; then
        PASSED+=("$target")
    else
        FAILED+=("$target")
    fi
done 3< "$HOSTS_FILE"

echo ""
echo "════════════════════════════════════════════════════════"
echo "  Fleet sync summary"
echo "════════════════════════════════════════════════════════"
for t in ${PASSED[@]+"${PASSED[@]}"}; do echo "  ok    $t"; done
for t in ${FAILED[@]+"${FAILED[@]}"}; do echo "  FAIL  $t"; done
[[ ${#PASSED[@]} -eq 0 && ${#FAILED[@]} -eq 0 ]] && echo "  (no machines matched)"

[[ ${#FAILED[@]} -gt 0 ]] && exit 1
exit 0
