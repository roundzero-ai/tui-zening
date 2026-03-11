# tui_zening

One-command terminal environment setup for consistent coding experience across **MacBook Pro**, **Mac Studio**, and **NVIDIA DGX Spark GB10**.

Installs and configures:
- **Ghostty** — terminal (transparency, blur, font)
- **oh-my-posh** — shell prompt (path · python · exit status)
- **tmux ZenGarden** — modern tmux with colored tabs, system stats, vim navigation

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
source ~/.bashrc   # DGX Spark / Linux (bash)
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
| `--yazi` | Install [yazi](https://github.com/sxyazi/yazi) file manager, deploy config to `~/.config/yazi/`, and add `y` shell wrapper (opt-in) |

> **Note:** Unlike previous versions, Ghostty and fonts are no longer auto-skipped on headless Linux. Pass `--headless` explicitly when you want SSH-only setup.

---

## Per-machine Usage

### MacBook Pro (local, zsh)

```bash
bash setup.sh
```

- Installs Ghostty via Homebrew cask
- Deploys Ghostty config (transparency, blur, JetBrainsMono)
- Installs zsh-autosuggestions
- Patches `~/.zshrc`
- Sets up tmux auto-attach when opening a Ghostty window

### Mac Studio (remote via SSH, zsh)

Full setup (run when connected to display):
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

On Linux, the script first tries to install Ghostty via the system package manager (`apt install ghostty`). If that fails (package not available), it falls back to **building from source** using Zig. The source build:
1. Installs build dependencies (`libgtk-4-dev`, `libadwaita-1-dev`, etc.)
2. Clones `github.com/ghostty-org/ghostty`
3. Downloads the exact Zig version required (read from `.zig-version` in source)
4. Compiles with `zig build -Doptimize=ReleaseFast`
5. Installs binary to `~/.local/bin/ghostty`

On subsequent runs, the source is updated with `git pull` and only rebuilt if needed.

With yazi:
```bash
bash setup.sh --yazi
```

---

## What Gets Installed

| Component | macOS (zsh) | DGX Spark / Linux (bash) | Headless (`--headless`) |
|---|---|---|---|
| tmux | ✓ | ✓ | ✓ |
| oh-my-posh | ✓ | ✓ | ✓ |
| tmux ZenGarden config | ✓ | ✓ | ✓ |
| zsh-autosuggestions | ✓ | — (bash) | — |
| JetBrainsMono Nerd Font | ✓ | ✓ | — |
| Ghostty | ✓ brew cask | ✓ built from source | — |
| yazi | opt-in `--yazi` | opt-in `--yazi` | opt-in `--yazi` |

---

## What Gets Added to Your Shell RC

The script patches `~/.zshrc` (macOS/zsh) or `~/.bashrc` (Linux/bash). Each block is added only once — re-running is safe.

| Block | Marker used for deduplication |
|---|---|
| `export TERM=xterm-256color` | `TERM=xterm-256color` |
| `export PATH="$HOME/.local/bin:$PATH"` | `.local/bin` (Linux only) |
| oh-my-posh prompt init | `oh-my-posh init` |
| zsh-autosuggestions source | `zsh-autosuggestions.zsh` (zsh only) |
| Ghostty tmux auto-attach (`Main \| hostname`) | `Main | $(hostname -s)` (macOS only) |
| SSH tmux auto-attach (`RZ-AI \| hostname`) | `new-session -A -s "RZ-AI \|` |
| SSH mouse-tracking reset | `ssh_mouse_reset` |

### tmux Auto-Attach Behaviour

The two snippets are independent and do not conflict.

Session names include the machine's hostname so you can identify which machine a session belongs to when tunnelling or using tmux nesting.

**Local — MacBook + Ghostty** (added to `~/.zshrc` on macOS):
```zsh
if [ -z "$TMUX" ] && [ "$TERM_PROGRAM" = "ghostty" ]; then
  _s="Main | $(hostname -s)"
  tmux attach-session -t "$_s" 2>/dev/null || tmux new-session -s "$_s"
  unset _s
fi
```
Session name: `Main | macbook-pro` (or whatever `hostname -s` returns)

**Remote — Mac Studio / DGX Spark via SSH** (added to `~/.zshrc` or `~/.bashrc`):
```bash
if [[ -z "$TMUX" ]] && [[ -n "$SSH_TTY" ]] && [[ $- =~ i ]]; then
  exec tmux new-session -A -s "RZ-AI | $(hostname -s)"
fi
```
Session name: `RZ-AI | mac-studio` or `RZ-AI | dgx-spark`

Re-running `setup.sh` on an existing machine automatically migrates the old fixed session names (`main` / `RZ-AI`) to the new hostname-suffixed format.

**SSH mouse-tracking reset** (added to `~/.zshrc` or `~/.bashrc`):
```bash
ssh() {
    command ssh "$@"
    printf '\033[?1000l\033[?1002l\033[?1003l\033[?1006l\033[?1015l'
}
```

When a remote tmux session has `set -g mouse on`, the terminal is put into mouse-reporting mode. If the SSH connection drops unexpectedly, the terminal is left in that state — causing trackpad scroll gestures to print raw SGR escape sequences (e.g. `65;146;38M`) instead of scrolling. This wrapper resets all mouse tracking modes after every SSH exit, clean or otherwise.

---

## tmux ZenGarden

The tmux config is sourced from **[roundzero-ai/tmux-zengarden](https://github.com/roundzero-ai/tmux-zengarden)** — cloned on first run, updated on every subsequent run via `git pull`.

### Status Bar

```
 ≋ ZenGarden  user@host     1:project  2:folder>nvim  3:user@remote
  session     git ⎇ branch  CPU 18%  MEM 8.2G 51%  GPU 20%  14:35 Fri
```

- **Line 0** — Brand pill + identity (left) · Colored window tabs (right)
- **Line 1** — Session pill (left) · git · CPU · RAM % · GPU · time (right)
- **Window tab labels**: idle shell → `folder` · program running → `folder>program` · SSH → `user@host`
- GPU stats: `ioreg` on Apple Silicon (no sudo) · `nvidia-smi` on DGX Spark (UMA-aware for GB10)

### Key Bindings

#### Outer tmux

| Action | Key |
|---|---|
| Prefix | `Ctrl-Space` |
| Navigate panes | `Alt+h/j/k/l` (no prefix) or `prefix + h/j/k/l` |
| Resize pane (coarse) | `prefix + H/J/K/L` |
| Resize pane (fine) | `prefix + Alt+H/J/K/L` |
| Split horizontal | `prefix + \|` |
| Split vertical | `prefix + -` |
| Bottom pane 25% | `prefix + _` — creates if none, focuses if exists |
| Right pane 33% | `prefix + \` — creates if none, focuses if exists |
| Zoom pane | `prefix + z` |
| Switch window | `Alt+1` – `Alt+9` |
| Prev / next window | `Alt+[` / `Alt+]` |
| Cycle window | `Alt+Tab` / `Alt+Shift+Tab` |
| Last window | `prefix + Tab` |
| Reload config | `prefix + r` |
| Copy mode | `prefix + [` → `v` select → `y` yank |
| Nested tmux toggle (REMOTE mode) | `F12` — suspend/resume local key interception |

#### Inner tmux — Ctrl-key layer (Ghostty + MacBook, no REMOTE mode needed)

| Action | Key |
|---|---|
| Inner select window 1..9 | `Ctrl+Alt+1..9` (prefix-free) |
| Inner next window | `Ctrl+Alt+Tab` (prefix-free) |
| Inner prev window | `Ctrl+Alt+Shift+Tab` (prefix-free) |
| Inner new window | `prefix + Ctrl+c` |
| Inner close pane | `prefix + Ctrl+x` |
| Inner split horizontal | `prefix + Ctrl+\|` |
| Inner split vertical | `prefix + Ctrl+-` |
| Inner bottom pane 25% | `prefix + Ctrl+_` |
| Inner right pane 33% | `prefix + Ctrl+\` |
| Inner swap window left/right | `prefix + Ctrl+Shift+←` / `prefix + Ctrl+Shift+→` |
| Inner resize pane (coarse) | `prefix + Ctrl+H/J/K/L` (repeatable) |
| Inner resize pane (fine) | `prefix + Ctrl+Alt+H/J/K/L` (repeatable) |

> Ghostty keybindings can optionally map single keystrokes (e.g. `Ctrl+Alt+n`) to trigger inner tmux commands without manually pressing the outer prefix — see [tmux-zengarden README](https://github.com/roundzero-ai/tmux-zengarden) for details.

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

**Note on `oh-my-posh font install meslo`:** Running this installs MesloLGS NF, which is the font recommended by oh-my-posh's own docs. It is not needed here — we use **JetBrainsMono NFM** (a Nerd Font) which includes all required glyphs. Having both fonts installed is harmless.

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

## Yazi File Manager

Installed opt-in via `--yazi`. Configures:

| File | Purpose |
|---|---|
| `~/.config/yazi/yazi.toml` | Manager layout, sorting, preview settings |
| `~/.config/yazi/keymap.toml` | Custom keybindings (adds to defaults, never replaces) |
| `~/.config/yazi/theme.toml` | Color theme stub (points to flavor docs) |

The `y` shell function is added to your RC file — use it instead of `yazi` to automatically `cd` into the directory you were browsing when you quit.

### Key Bindings Added

| Key | Action |
|---|---|
| `.` | Toggle hidden files |
| `c c` / `c d` / `c f` / `c n` | Copy full path / dir / filename / name-no-ext |
| `, m` / `, s` / `, n` / `, e` | Sort by modified / size / natural / extension |
| `g h` / `g d` / `g p` / `g c` / `g t` | Jump to home / Downloads / Projects / .config / /tmp |
| `Ctrl+t` | New tab (current directory) |
| `←` / `→` | Parent dir / enter directory (arrow-key fallback) |

All default yazi bindings (`hjkl`, `q`, `y`/`x`/`p`, `d`, etc.) remain unchanged.

---

## Project Structure

```
tui-zening/
├── setup.sh          # main setup script
├── config/
│   ├── ghostty       # Ghostty terminal config
│   ├── nanorc        # nano editor config
│   └── yazi/
│       ├── yazi.toml    # manager, preview, tasks settings
│       ├── keymap.toml  # custom keybindings (prepend_keymap)
│       └── theme.toml   # theme/flavor stub
└── README.md
```

tmux config and oh-my-posh theme:
→ **[roundzero-ai/tmux-zengarden](https://github.com/roundzero-ai/tmux-zengarden)**
