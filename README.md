# tui_zening

One-command terminal environment setup for consistent coding experience across **MacBook Pro**, **Mac Studio Ultra**, **NVIDIA DGX Spark GB10**, and **Ubuntu** machines (amd64/arm64).

Installs and configures:
- **Ghostty** — terminal (transparency, blur, font)
- **oh-my-posh** — shell prompt (path · python · exit status)
- **tmux ZenGarden** — modern tmux with colored tabs, mouse-clickable outer/inner tabs, system stats, vim navigation

---

## Quick Start

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
bash setup.sh [--headless] [--no-ghostty] [--no-fonts] [--yazi]
```

| Flag | Effect |
|---|---|
| `--headless` | SSH-only mode: skip Ghostty install and fonts. Use on machines accessed only via SSH. |
| `--no-ghostty` | Skip Ghostty installation and config deployment |
| `--no-fonts` | Skip JetBrainsMono Nerd Font installation |
| `--yazi` | Install [yazi](https://github.com/sxyazi/yazi) + [lazygit](https://github.com/jesseduffield/lazygit), deploy yazi config to `~/.config/yazi/`, add `y` shell wrapper, and add in-yazi `g l` lazygit shortcut (opt-in) |

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

Or deploy from your MacBook:
```bash
rsync -av tui-zening/ mac-studio:~/tui-zening/
ssh mac-studio "bash ~/tui-zening/setup.sh --headless"
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

This setup has three layers:

- `outer tmux`: your local tmux session in Ghostty
- `inner tmux`: the nested tmux session, usually on an SSH host
- `Ghostty shortcut layer`: optional terminal shortcuts that skip the outer prefix for selected actions

#### Outer tmux

Core controls:

| Action | Key |
|---|---|
| Prefix | `Ctrl+Space` |
| Toggle nested passthrough | `F12` |
| Reload config | `prefix + r` |
| Copy mode | `prefix + [` -> `v` select -> `y` yank |

Panes:

| Action | Key |
|---|---|
| Move focus | `Alt+h/j/k/l` or `prefix + h/j/k/l` |
| Resize coarse | `prefix + ←/↓/↑/→` |
| Split horizontal | `prefix + \` |
| Split vertical | `prefix + -` |
| Bottom pane 25% | `prefix + =` |
| Right pane 33% | `prefix + /` |
| Swap pane down / up | `prefix + .` / `prefix + ,` |
| Zoom pane | `prefix + z` |
| Close pane | `prefix + x` |

Windows:

| Action | Key |
|---|---|
| New window | `prefix + c` |
| Select window 1..9 | `Alt+1..9` |
| Next window | `Alt+Tab` |
| Swap window left / right | `prefix + p` / `prefix + n` |

#### Inner tmux - Ctrl-key layer

Use this when you want to control the inner tmux session **without** enabling `F12` REMOTE mode.

Rule of thumb:

- prefix-free inner actions use `Ctrl+Alt+...`
- prefix-based inner actions use outer `Ctrl+Space`, then the matching `Ctrl+...` key
- plain keys after prefix still target the outer tmux session

Prefix-free inner actions:

| Action | Key |
|---|---|
| Move inner pane focus | `Ctrl+Alt+h/j/k/l` |
| Select inner window 1..9 | `Ctrl+Alt+1..9` |
| Next inner window | `Ctrl+Alt+Tab` |

Prefix-based inner actions after outer `Ctrl+Space`:

| Action | Key after prefix |
|---|---|
| New inner window | `Ctrl+c` |
| Close inner pane | `Ctrl+x` |
| Toggle inner zoom | `Ctrl+z` |
| Reload inner config | `Ctrl+r` |
| Inner split horizontal | `Ctrl+\` |
| Inner split vertical | `Ctrl+-` |
| Inner bottom pane 25% | `Ctrl+=` |
| Inner right pane 33% | `Ctrl+/` |
| Swap inner pane down / up | `Ctrl+.` / `Ctrl+,` |
| Swap inner window left / right | `Ctrl+p` / `Ctrl+n` |
| Resize inner pane coarse | `Ctrl+←/↓/↑/→` |
| Inner copy mode | `Ctrl+[` |

How it works:

- `prefix + c` acts on outer tmux
- `prefix + Ctrl+c` forwards `prefix + c` to inner tmux
- this keeps both layers usable at the same time

#### Ghostty single-keystroke shortcuts

Ghostty adds a helper layer on top of tmux:

- `Alt+...` skips the prefix for the full outer prefix-based binding set
- `Ctrl+Alt+...` skips the prefix for selected inner tmux bindings
- prefix-free inner navigation like `Ctrl+Alt+h/j/k/l` still works natively via tmux extended-keys

| Action | Ghostty shortcut | Equivalent tmux input |
|---|---|---|
| Outer split horizontal | `Alt+\` | `prefix + \` |
| Outer split vertical | `Alt+-` | `prefix + -` |
| Outer bottom pane 25% | `Alt+=` | `prefix + =` |
| Outer right pane 33% | `Alt+/` | `prefix + /` |
| Outer zoom pane | `Alt+z` | `prefix + z` |
| Outer new window | `Alt+c` | `prefix + c` |
| Outer close pane | `Alt+x` | `prefix + x` |
| Outer swap pane down / up | `Alt+.` / `Alt+,` | `prefix + .` / `prefix + ,` |
| Outer swap window L/R | `Alt+p` / `Alt+n` | `prefix + p` / `prefix + n` |
| Outer resize coarse | `Alt+←/↓/↑/→` | `prefix + ←/↓/↑/→` |
| Outer reload config | `Alt+r` | `prefix + r` |
| Outer copy mode | `Alt+[` | `prefix + [` |
| Inner select window 1..9 | `Ctrl+Alt+1..9` | `Ctrl+Alt+1..9` |
| Inner next window | `Ctrl+Alt+Tab` | `Ctrl+Alt+Tab` |
| Inner new window | `Ctrl+Alt+c` | `prefix + Ctrl+c` |
| Inner close pane | `Ctrl+Alt+x` | `prefix + Ctrl+x` |
| Inner zoom toggle | `Ctrl+Alt+z` | `prefix + Ctrl+z` |
| Inner reload config | `Ctrl+Alt+r` | `prefix + Ctrl+r` |
| Inner split horizontal | `Ctrl+Alt+\` | `prefix + Ctrl+\` |
| Inner split vertical | `Ctrl+Alt+-` | `prefix + Ctrl+-` |
| Inner bottom pane 25% | `Ctrl+Alt+=` | `prefix + Ctrl+=` |
| Inner right pane 33% | `Ctrl+Alt+/` | `prefix + Ctrl+/` |
| Inner swap pane down / up | `Ctrl+Alt+.` / `Ctrl+Alt+,` | `prefix + Ctrl+.` / `prefix + Ctrl+,` |
| Inner copy mode | `Ctrl+Alt+[` | `prefix + Ctrl+[` |
| Inner swap window L/R | `Ctrl+Alt+p` / `Ctrl+Alt+n` | `prefix + Ctrl+p` / `prefix + Ctrl+n` |
| Inner resize coarse | `Ctrl+Alt+←/↓/↑/→` | `prefix + Ctrl+←/↓/↑/→` |

Maintenance rules for future updates:

- Treat `tmux-zengarden/tmux.conf` as the source of truth for the key map.
- Keep the same semantic pattern across all layers: outer tmux, inner tmux, then Ghostty convenience shortcut.
- Avoid new bindings that require `Shift` for regular use; prefer letters, arrows, and unshifted punctuation.
- If an outer binding changes and it has an inner equivalent, update the matching `Ctrl+...` inner form too.
- Keep the full outer Ghostty alias set aligned with prefix-based outer actions: resize, split, pane-layout toggles, zoom, new/close, swaps, reload, and copy mode.
- If an inner action has a Ghostty shortcut, update `config/ghostty` and this README in the same change.
- Document tmux-native behavior first; document Ghostty as an optional alias layer second.

F12 REMOTE mode remains the universal fallback when you want all keys to pass straight through to the inner tmux.

Mouse behavior:

- clicking outer tmux window tabs selects outer windows
- clicking inner tmux window tabs also works from nested sessions (mouse events are forwarded when inner tmux mouse mode is active)

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

Theme file: `~/.config/oh-my-posh/zengarden.json`

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

The config also unbinds Ghostty's default `Ctrl+Tab` / `Ctrl+Shift+Tab` (Ghostty tab switching) so `Ctrl+Alt+Tab` can be used for inner tmux window cycling.

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

All steps are idempotent. To update everything:

```bash
cd ~/tui-zening
git pull
bash setup.sh           # full
bash setup.sh --headless  # headless
```

This will pull the latest `tmux-zengarden`, re-deploy configs, and skip already-installed tools.

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
├── setup.sh          # main setup script
├── config/
│   ├── ghostty       # Ghostty terminal config + inner tmux keybindings
│   ├── nanorc        # nano editor config
│   └── yazi/
│       ├── yazi.toml    # manager, preview, tasks settings
│       ├── keymap.toml  # custom keybindings (prepend_keymap)
│       └── theme.toml   # theme/flavor stub
└── README.md
```

tmux config and oh-my-posh theme:
→ **[roundzero-ai/tmux-zengarden](https://github.com/roundzero-ai/tmux-zengarden)**
