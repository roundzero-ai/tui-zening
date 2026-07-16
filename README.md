# tui_zening

One-command terminal environment setup for consistent coding experience across **MacBook Pro**, **Mac Studio Ultra**, **NVIDIA DGX Spark GB10**, and **Ubuntu** machines (amd64/arm64).

Installs and configures:
- **Ghostty** — terminal (transparency, blur, font)
- **oh-my-posh** — shell prompt (path · python · exit status)
- **tmux ZenGarden** — modern tmux with colored tabs, mouse-clickable outer/inner tabs, system stats, vim navigation

---

## Quick Start

One-liner on a fresh machine (clones to `~/Workspace/tui-zening`, then runs setup):

```bash
curl -fsSL https://raw.githubusercontent.com/roundzero-ai/tui-zening/main/bootstrap.sh | bash
# headless server:
curl -fsSL https://raw.githubusercontent.com/roundzero-ai/tui-zening/main/bootstrap.sh | bash -s -- --headless
```

Or manually:

```bash
git clone https://github.com/roundzero-ai/tui-zening.git
cd tui-zening
bash setup.sh
```

Reload your shell after:
```bash
source ~/.zshrc    # macOS (zsh)
source ~/.bashrc   # Linux (bash)
```

---

## Options

```
bash setup.sh [--headless] [--no-ghostty] [--no-fonts] [--yazi] [--local] [--dry-run]
```

| Flag | Effect |
|---|---|
| `--headless` | SSH-only mode: skip Ghostty install and fonts. Use on machines accessed only via SSH. |
| `--no-ghostty` | Skip Ghostty installation and config deployment |
| `--no-fonts` | Skip JetBrainsMono Nerd Font installation |
| `--yazi` | Install [yazi](https://github.com/sxyazi/yazi) + [lazygit](https://github.com/jesseduffield/lazygit), deploy yazi config to `~/.config/yazi/`, add `y` shell wrapper, and add in-yazi `g l` lazygit shortcut (opt-in) |
| `--local` | Use a sibling `../tmux-zengarden` checkout instead of the GitHub cache — for testing unpushed tmux-zengarden changes end-to-end |
| `--dry-run` | Report every install/deploy/RC-patch that would happen without changing anything |

---

## Per-machine Usage

### MacBook Pro (local, zsh)

```bash
bash setup.sh
```

- Installs Ghostty via Homebrew cask
- Deploys Ghostty config with inner-tmux keybindings (transparency, blur, JetBrainsMono)
- Installs zsh-autosuggestions
- Patches `~/.zshrc`
- Sets up tmux auto-attach: opens Ghostty → attaches to live tmux session if any, else outer tmux session named after the short hostname

### Mac Studio Ultra (local or remote via SSH, zsh)

Full setup (when connected to display):
```bash
bash setup.sh
```

SSH-only headless setup:
```bash
bash setup.sh --headless
```

Or deploy from your MacBook (see also [Fleet Sync](#fleet-sync)):
```bash
ssh mac-studio "curl -fsSL https://raw.githubusercontent.com/roundzero-ai/tui-zening/main/bootstrap.sh | bash -s -- --headless"
```

### DGX Spark GB10 (Ubuntu, bash)

**Headless SSH-only** (recommended for server-only use):
```bash
bash setup.sh --headless
```

**Full setup** (with Ghostty when using DGX Spark with a display):
```bash
bash setup.sh
```

On Linux, the script first tries to install Ghostty via the system package manager (`apt install ghostty`). If that fails (package not available), it falls back to **snap** (`snap install ghostty --classic`). If neither works, the script warns you and skips Ghostty — install it manually from [ghostty.org](https://ghostty.org/docs/install/binary).

### amd64 / arm64 Ubuntu (remote via SSH, bash)

```bash
bash setup.sh --headless
```

With yazi:
```bash
bash setup.sh --yazi
```

---

## What Gets Installed

| Component | macOS (zsh) | Linux (bash) | Headless (`--headless`) |
|---|---|---|---|
| tmux | ✓ | ✓ | ✓ |
| oh-my-posh | ✓ | ✓ | ✓ |
| tmux ZenGarden config | ✓ | ✓ | ✓ |
| zsh-autosuggestions | ✓ | — (bash) | — |
| JetBrainsMono Nerd Font | ✓ | ✓ | — |
| Ghostty | ✓ brew cask | ✓ pkg manager / snap | — |
| yazi | opt-in `--yazi` | opt-in `--yazi` | opt-in `--yazi` |
| lazygit | opt-in `--yazi` | opt-in `--yazi` | opt-in `--yazi` |

---

## Workflow: Nested tmux via SSH

The intended workflow:

1. **Local device** (MacBook Pro / Mac Studio): Ghostty opens → outer tmux session named `hostname`
2. **Each tmux window** SSHs to a remote device
3. **Remote device** runs inner tmux session named `hostname` (same rule — attach to any live session, else create one)

Session naming is now unified across both local and SSH entry points: a single block in your RC file attaches to whatever tmux session is already live on the machine, or creates one named after the short hostname if none exists. No more `Main | …` vs `RZ-AI | …` split.

Two ways to control the inner tmux:

- **F12 REMOTE mode**: toggle on to pass ALL keys to inner tmux, toggle off to resume local control
- **Ctrl-key layer**: add Ctrl to any outer binding to operate the inner tmux (REMOTE mode stays off)

Ghostty keybindings further reduce prefix-based inner operations to single keystrokes.

---

## What Gets Added to Your Shell RC

The script patches `~/.zshrc` (macOS/zsh) or `~/.bashrc` (Linux/bash). Each block is added only once — re-running is safe.

| Block | Marker used for deduplication |
|---|---|
| `export TERM=xterm-256color` | `TERM=xterm-256color` |
| `export CLICOLOR=1` | `CLICOLOR=1` (macOS only) |
| `export PATH="$HOME/.local/bin:$PATH"` | `.local/bin` (Linux only) |
| oh-my-posh prompt init | `oh-my-posh init` |
| zsh-autosuggestions source | `zsh-autosuggestions.zsh` (zsh only) |
| tmux auto-attach (unified Ghostty + SSH) | `tui_zening: auto-attach tmux` |
| SSH mouse-tracking reset | `ssh_mouse_reset` |

On upgrade, `setup.sh` also removes the two legacy blocks (`# Auto-attach or start tmux when opening a local Ghostty window` and `# Auto-attach or start tmux on SSH login`) before adding the unified one.

### tmux Auto-Attach Behaviour

A single block is appended to your RC file — same logic on macOS Ghostty and over SSH:

```bash
# tui_zening: auto-attach tmux on interactive Ghostty or SSH shell.
# Attaches to any existing session if one is live; otherwise starts a new
# one named after the short hostname.
if [ -z "$TMUX" ] && [ -t 1 ] && { [ -n "$SSH_TTY" ] || [ "$TERM_PROGRAM" = "ghostty" ]; }; then
  if tmux ls >/dev/null 2>&1; then
    exec tmux attach
  else
    exec tmux new-session -s "$(hostname -s)"
  fi
fi
```

Resulting session name (when newly created): the short hostname, e.g. `macbook-pro`, `mac-studio`, or `dgx-spark`. If a session is already live (regardless of how it was named), the shell attaches to it instead of creating a duplicate.

**SSH mouse-tracking reset** (added to `~/.zshrc` or `~/.bashrc`):
```bash
ssh() {
    command ssh "$@"
    printf '\033[?1000l\033[?1002l\033[?1003l\033[?1006l\033[?1015l'
}
```

Resets mouse tracking modes after every SSH exit to prevent raw escape sequences appearing when a remote tmux session drops unexpectedly.

---

## tmux ZenGarden

The tmux config is sourced from **[roundzero-ai/tmux-zengarden](https://github.com/roundzero-ai/tmux-zengarden)** — cloned into `./.cache/tmux-zengarden` on first run and updated on every subsequent run via `git pull`.

### Status Bar

```
 ≋ ZenGarden  user@host     1:project  2:folder>nvim  3:user@remote
  session                   CPU 18% | UMA 8.2G/16G 51% | GPU 20%      14:35 Fri
  session                   CPU 22% | RAM 12G/64G 19% | GPU 31% | VRAM 4.8G/16G 30%      14:35 Fri
```

- **Line 0** — Brand pill + identity (left) · Colored window tabs (right)
- **Line 1** — Session pill (left) · cached CPU · RAM/UMA · GPU · VRAM · time (right)
- **Window tab labels**: idle shell → `folder` · program running → `folder>program` · SSH → `user@host`
- GPU stats: `top` + `vm_stat` + `ioreg` on Apple Silicon, `tegrastats` on Jetson/Orin, `top` + `free` + `nvidia-smi` on NVIDIA Linux; UMA machines render `CPU | UMA | GPU`, discrete NVIDIA hosts render `CPU | RAM | GPU | VRAM`

### Key Bindings

The **canonical keybinding reference** — outer tmux, the inner Ctrl-key layer for
nested tmux, and the Ghostty single-keystroke shortcuts — lives in
**[tmux-zengarden's README](https://github.com/roundzero-ai/tmux-zengarden#key-bindings)**.
That repo owns the entire keymap (`tmux.conf` + `ghostty-keys.conf`); this repo
only deploys it. The tables are intentionally not duplicated here.

The 30-second version:

- Prefix is `Ctrl+Space`; pane nav `Alt+h/j/k/l`; windows `Alt+1..9` / `Alt+Tab`.
- `Alt+<key>` in Ghostty = `prefix + <key>` on the **outer** tmux.
- `Ctrl+Alt+<key>` in Ghostty targets the **inner** (SSH) tmux without leaving local control.
- `F12` toggles full REMOTE passthrough to the inner tmux.

Ghostty keybindings are deployed as `zengarden-keys.conf` next to the Ghostty
config (see below) — sourced from `tmux-zengarden/ghostty-keys.conf`.

---

## oh-my-posh Theme

Prompt shows only what the tmux banner doesn't already display:

```
 ~/Projects/myproject   3.12.2  ✓
```

| Segment | What it shows |
|---|---|
| `root` | Lightning bolt when running as root |
| `path` | Current directory (agnoster style) |
| `python` | Active venv + Python version |
| `status` | Exit code on failure only |

> git branch and hostname are intentionally absent — they live in the tmux status bar.

Theme source: `config/oh-my-posh.json` (this repo) → deployed to `~/.config/oh-my-posh/zengarden.json`

---

## Ghostty Config

Deployed to:
- **macOS**: `~/Library/Application Support/com.mitchellh.ghostty/config`
- **Linux**: `~/.config/ghostty/config`

Key settings:
```
theme              = Bright Lights
font-family        = JetBrainsMono NFM Regular
font-size          = 13
background-opacity = 0.8
background-blur    = 90
macos-titlebar-style = transparent
```

The blur + transparency is what makes tmux's `bg=default` pane backgrounds look frosted against the wallpaper.

`config/ghostty` in this repo holds **appearance only**. All keybindings come from
`tmux-zengarden/ghostty-keys.conf`, deployed alongside as `zengarden-keys.conf` and
pulled in by the `config-file = ?zengarden-keys.conf` include (the `?` keeps Ghostty
booting even if the keys file is missing). That file also unbinds Ghostty's default
`Ctrl+Tab` / `Ctrl+Shift+Tab` so `Ctrl+Alt+Tab` can cycle inner tmux windows.

---

## SSH Typing Lag

If keystrokes feel laggy when working inside tmux over SSH, the tmux side is already tuned: `escape-time 0` and `focus-events on` are set in the server scope by tmux-zengarden (so there is no ESC-meta wait, and pane/app focus events still flow through). Any remaining lag is network latency between local Ghostty and the remote shell.

What helps further (configure on your local Mac, not the remote):

1. **SSH ControlMaster** — reuses a single TCP/encryption channel across all connections to the same host. Add to `~/.ssh/config`:
   ```
   Host *
     ControlMaster auto
     ControlPath ~/.ssh/cm-%r@%h:%p
     ControlPersist 10m
     ServerAliveInterval 30
     ServerAliveCountMax 3
   ```
   First SSH to a host pays the handshake cost; subsequent connections (including the ones tmux opens for new windows) reuse the existing channel.
2. **TCP keepalive** — `ServerAliveInterval 30` above also prevents idle-disconnects that look like sudden lag spikes.
3. **Compression** — only useful on slow links; on a LAN it adds CPU cost without benefit. Add `Compression yes` per-host if needed.
4. **Avoid double-nested status bars** — if you SSH from a remote tmux back into another tmux, every keystroke crosses two status-redraw paths. Use F12 REMOTE mode or the Ctrl-key inner layer instead of opening yet another wrapping tmux.

---

## Re-running / Updating

All steps are idempotent. To update one machine:

```bash
cd ~/Workspace/tui-zening
git pull
bash setup.sh           # full
bash setup.sh --headless  # headless
```

This will pull the latest `tmux-zengarden`, re-deploy configs, and skip already-installed tools.

---

## Fleet Sync

Update every machine in one shot from your Mac:

```bash
cp machines.example machines.local   # once: list your hosts (gitignored)
bash sync-fleet.sh                   # all machines
bash sync-fleet.sh dgx-spark         # only targets matching "dgx-spark"
```

`machines.local` holds one `<ssh-target> [setup.sh flags...]` per line, e.g.
`user@mac-studio --headless`. For each host, sync-fleet SSHes in,
clones-or-pulls `~/Workspace/tui-zening`, and runs `setup.sh` with that host's
flags. Machines pull from GitHub `main` — push your changes first (the script
warns if local work hasn't been pushed).

---

## Development

- `bash verify.sh` — the verification gate (syntax, shellcheck, `--dry-run`
  against a throwaway `$HOME`, repo invariants). CI runs the same script.
- `bash setup.sh --local --dry-run` — test unpushed `../tmux-zengarden`
  changes end-to-end without touching your system.
- Agent workflow and cross-repo rules: see [AGENTS.md](AGENTS.md).

---

## Yazi + LazyGit

Installed opt-in via `--yazi`. Configures:

| File | Purpose |
|---|---|
| `~/.config/yazi/yazi.toml` | Manager layout, sorting, preview settings |
| `~/.config/yazi/keymap.toml` | Custom keybindings (adds to defaults, never replaces) |
| `~/.config/yazi/theme.toml` | Color theme stub (points to flavor docs) |

The `y` shell function is added to your RC file — use it instead of `yazi` to automatically `cd` into the directory you were browsing when you quit.

`lazygit` is also installed, and is bound in yazi to `g l` (press `g`, then `l`) using a blocking shell command.

### Launch Flow

```bash
y                    # or: yazi /path/to/repo
# inside yazi, press g then l
```

In lazygit, press `q` to return to yazi.

### Key Bindings Added

| Key | Action |
|---|---|
| `.` | Toggle hidden files |
| `c c` / `c d` / `c f` / `c n` | Copy full path / dir / filename / name-no-ext |
| `, m` / `, s` / `, n` / `, e` | Sort by modified / size / natural / extension |
| `g h` / `g d` / `g p` / `g c` / `g t` | Jump to home / Downloads / Projects / .config / /tmp |
| `g l` | Open lazygit (returns to yazi on quit) |
| `Ctrl+t` | New tab (current directory) |
| `←` / `→` | Parent dir / enter directory (arrow-key fallback) |

All default yazi bindings (`hjkl`, `q`, `y`/`x`/`p`, `d`, etc.) remain unchanged.

---

## Project Structure

```
tui-zening/
├── setup.sh          # orchestrator — flags, ordering, summary
├── bootstrap.sh      # curl-able first-run entry (clone + setup)
├── sync-fleet.sh     # update all machines in machines.local via SSH
├── verify.sh         # verification gate (also run by CI)
├── machines.example  # template for machines.local (gitignored)
├── lib/
│   ├── log.sh        # logging, dry-run helpers, deploy_file
│   ├── detect.sh     # OS/arch/shell detection, package-manager plumbing
│   ├── packages.sh   # Homebrew, core tools, oh-my-posh, fonts
│   ├── ghostty.sh    # Ghostty install + config deploy
│   ├── zengarden.sh  # tmux-zengarden clone/update/--local + deploy
│   ├── yazi.sh       # yazi + lazygit (opt-in)
│   └── rc.sh         # idempotent shell-RC patching
├── config/
│   ├── ghostty          # Ghostty appearance config (keybinds live in tmux-zengarden)
│   ├── oh-my-posh.json  # prompt theme
│   ├── nanorc           # nano editor config
│   └── yazi/
│       ├── yazi.toml    # manager, preview, tasks settings
│       ├── keymap.toml  # custom keybindings (prepend_keymap)
│       └── theme.toml   # theme/flavor stub
├── AGENTS.md         # agent instructions (CLAUDE.md symlinks here)
└── README.md
```

tmux config, status scripts, and the full keymap (including Ghostty keybindings):
→ **[roundzero-ai/tmux-zengarden](https://github.com/roundzero-ai/tmux-zengarden)**
