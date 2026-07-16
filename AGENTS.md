# AGENTS.md — tui-zening

Instructions for coding agents (Claude Code, Codex CLI, …). `CLAUDE.md` is a
symlink to this file — edit this file only.

## What this repo is

The **distribution repo** for the ZenGarden terminal environment: the thing
that gets synced to the local device and every homelab server to set up (and
keep updating) the development environment. One `setup.sh` run brings a
machine to the full state; re-runs are idempotent updates.

| Path | Owns |
|---|---|
| `setup.sh` | orchestrator — flags, ordering, summary (logic lives in `lib/`) |
| `lib/log.sh` | logging, `die`, dry-run `would`, `deploy_file` (backup + copy) |
| `lib/detect.sh` | OS/arch/shell detection, sudo/package-manager plumbing, `install_pkg` |
| `lib/packages.sh` | Homebrew, git/curl/nano, tmux, oh-my-posh, zsh-autosuggestions, fonts |
| `lib/ghostty.sh` | Ghostty install + config deploy (incl. `zengarden-keys.conf`) |
| `lib/zengarden.sh` | tmux-zengarden clone/update/`--local`, deploy, posh theme deploy |
| `lib/yazi.sh` | yazi + lazygit (opt-in `--yazi`) |
| `lib/rc.sh` | idempotent shell-RC patching (`patch_rc` marker system) |
| `config/ghostty` | Ghostty **appearance only** — keybinds are forbidden here |
| `config/oh-my-posh.json` | prompt theme (designed to complement the tmux status bar) |
| `config/nanorc`, `config/yazi/` | editor / file-manager configs |
| `bootstrap.sh` | curl-able first-run entry: clones to `~/Workspace/tui-zening`, runs setup |
| `sync-fleet.sh` | SSH to every host in `machines.local` (gitignored): pull + setup |

## Repo relationship (read this before any change)

- **tmux-zengarden** (`github.com/roundzero-ai/tmux-zengarden`) is the source
  of truth for the ENTIRE keymap and tmux experience: `tmux.conf`, status
  scripts, `ghostty-keys.conf`, and the canonical keybinding reference in its
  README. Never define tmux/Ghostty keybindings in this repo, and never
  duplicate its keymap tables into this README — link instead.
- `setup.sh` consumes it by cloning GitHub `main` into `.cache/tmux-zengarden`
  (updated every run), running its `deploy.sh`, and copying its
  `ghostty-keys.conf` next to the Ghostty config as `zengarden-keys.conf`.
- `--local` switches the source to a sibling checkout `../tmux-zengarden` —
  use this (usually with `--dry-run`) to test unpushed cross-repo changes.
- Consequence: **anything pushed to `main` in either repo reaches every
  machine on its next `setup.sh` run.** Never push unverified changes.

## Invariants (verify.sh enforces some of these)

- Every step must stay **idempotent** — `setup.sh` is re-run on live machines
  as the update mechanism. RC edits go through `patch_rc` with a marker that
  appears verbatim in the block; retired RC blocks are removed via
  `remove_rc_block` migrations, never left to rot.
- `--dry-run` must remain truthful and side-effect free: every mutation path
  in `lib/` is gated (`would "..."` + return). New mutations need the same
  gate — verify.sh runs a dry-run against a throwaway `$HOME` and fails if
  anything is written.
- `config/ghostty` contains no `keybind` lines and must keep the
  `config-file = ?zengarden-keys.conf` include.
- Machine lists (`machines.local`) are gitignored — never commit hostnames or
  IPs; `machines.example` is the committed template.

## Workflow

1. Edit.
2. Run `bash verify.sh` — syntax, shellcheck (if installed), dry-run against
   a throwaway `$HOME`, repo invariants. **Must pass.**
3. For cross-repo changes: also run tmux-zengarden's `verify.sh`, and test
   end-to-end with `bash setup.sh --local --dry-run`.
4. Commit using conventional-commit style (`feat(setup): …`, `fix: …`,
   `docs: …`), matching existing history.
5. **Push policy: auto-push to `main` once verify passes.** Push order when
   both repos changed: **tmux-zengarden first, then this repo.**
6. After pushing, offer to run `bash sync-fleet.sh` to roll the update out to
   the machines in `machines.local`.

Do **not** run `setup.sh` for real on the development machine as part of
verification unless the user asks — it rewrites live configs (`~/.tmux.conf`,
Ghostty config, shell RC). `--dry-run` is the agent-safe mode.

## Platform matrix

`setup.sh` must keep working on all of these; only the Mac is testable
locally — CI (ubuntu-latest) covers the Linux syntax/dry-run path:

| Class | OS/arch | Shell | Notes |
|---|---|---|---|
| MacBook Pro / Mac Studio | macOS arm64 | zsh | Homebrew; Ghostty via cask; full setup |
| DGX Spark GB10 | Ubuntu arm64 | bash | usually `--headless`; UMA GPU stats |
| Jetson / Orin | Ubuntu arm64 | bash | `--headless`; tegrastats |
| Ubuntu PC (discrete NVIDIA) | Ubuntu amd64 | bash | apt, snap fallback for Ghostty |
| Raspberry Pi 4 | Ubuntu/Raspbian arm64 | bash | headless, **no sudo TTY** — special-cased (`_is_raspi4`); binary installs for yazi/lazygit |

Portability traps: BSD vs GNU `sed -i`, no `timeout` on some hosts, apt vs
dnf vs pacman, `~/.local/bin` not on PATH until the RC block lands.
