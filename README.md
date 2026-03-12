# tui_zening

One-command terminal environment setup for consistent coding experience across **MacBook Pro**, **Mac Studio Ultra**, **NVIDIA DGX Spark GB10**, and **Ubuntu** machines (amd64/arm64).

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
| `--yazi` | Install [yazi](https://github.com/sxyazi/yazi) file manager, deploy config to `~/.config/yazi/`, and add `y` shell wrapper (opt-in) |

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
- Sets up tmux auto-attach: opens Ghostty → outer tmux session `Main | hostname`

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

---

## Workflow: Nested tmux via SSH

The intended workflow:

1. **Local device** (MacBook Pro / Mac Studio): Ghostty opens → outer tmux session `Main | hostname`
2. **Each tmux window** SSHs to a remote device
3. **Remote device** runs inner tmux session `RZ-AI | hostname`

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
| Ghostty tmux auto-attach (`Main \| hostname`) | `Main | $(hostname -s)` (macOS only) |
| SSH tmux auto-attach (`RZ-AI \| hostname`) | `new-session -A -s "RZ-AI \|` |
| SSH mouse-tracking reset | `ssh_mouse_reset` |

### tmux Auto-Attach Behaviour

**Local — MacBook + Ghostty** (added to `~/.zshrc` on macOS):
```zsh
if [ -z "$TMUX" ] && [ "$TERM_PROGRAM" = "ghostty" ]; then
  _s="Main | $(hostname -s)"
  tmux attach-session -t "$_s" 2>/dev/null || tmux new-session -s "$_s"
  unset _s
fi
```
Session name: `Main | macbook-pro`

**Remote — via SSH** (added to `~/.zshrc` or `~/.bashrc`):
```bash
if [[ -z "$TMUX" ]] && [[ -n "$SSH_TTY" ]] && [[ $- =~ i ]]; then
  exec tmux new-session -A -s "RZ-AI | $(hostname -s)"
fi
```
Session name: `RZ-AI | mac-studio` or `RZ-AI | dgx-spark`

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

The tmux config is sourced from **[roundzero-ai/tmux-zengarden](https://github.com/roundzero-ai/tmux-zengarden)** — cloned on first run, updated on every subsequent run via `git pull`.

### Status Bar

```
 ≋ ZenGarden  user@host     1:project  2:folder>nvim  3:user@remote
  session                   CPU 18%  MEM 8.2G 51%  GPU 20%  14:35 Fri
```

- **Line 0** — Brand pill + identity (left) · Colored window tabs (right)
- **Line 1** — Session pill (left) · CPU · RAM · GPU · time (right)
- **Window tab labels**: idle shell → `folder` · program running → `folder>program` · SSH → `user@host`
- GPU stats: `ioreg` on Apple Silicon (no sudo) · `nvidia-smi` on DGX Spark (UMA-aware for GB10)

### Key Bindings

#### Outer tmux

| Action | Key |
|---|---|
| Prefix | `Ctrl-Space` |
| Navigate panes | `Alt+h/j/k/l` (no prefix) or `prefix + h/j/k/l` |
| Resize pane (coarse) | `prefix + ←/↓/↑/→` (repeatable) |
| Resize pane (fine) | `prefix + Alt+←/↓/↑/→` (repeatable) |
| Split horizontal | `prefix + \` |
| Split vertical | `prefix + -` |
| Bottom pane 25% | `prefix + =` — creates if none, focuses if exists |
| Right pane 33% | `prefix + /` — creates if none, focuses if exists |
| Zoom pane | `prefix + z` |
| New window | `prefix + c` |
| Close pane (confirm) | `prefix + x` |
| Switch window | `Alt+1..9` |
| Cycle window | `Alt+Tab` |
| Swap pane down / up | `prefix + .` / `prefix + ,` |
| Swap window left / right | `prefix + p` / `prefix + n` |
| Reload config | `prefix + r` |
| Copy mode | `prefix + [` → `v` select → `y` yank |
| Nested tmux toggle (REMOTE mode) | `F12` — suspend/resume local key interception |

#### Inner tmux — Ctrl-key layer (no REMOTE mode needed)

Pattern: add **Ctrl** to the outer binding. All outer bindings stay active.

**Prefix-free** — tmux root-table bindings:

| Action | Key |
|---|---|
| Inner pane navigation | `Ctrl+Alt+h/j/k/l` |
| Inner select window 1..9 | `Ctrl+Alt+1..9` |
| Inner next window | `Ctrl+Alt+Tab` |

**Prefix-based** — require outer prefix (`Ctrl-Space`) first:

| Action | Key (after prefix) |
|---|---|
| Inner new window | `Ctrl+c` |
| Inner close pane | `Ctrl+x` |
| Inner zoom toggle | `Ctrl+z` |
| Inner reload config | `Ctrl+r` |
| Inner split horizontal | `Ctrl+\` |
| Inner split vertical | `Ctrl+-` |
| Inner bottom pane 25% | `Ctrl+=` |
| Inner right pane 33% | `Ctrl+/` |
| Inner swap pane down / up | `Ctrl+.` / `Ctrl+,` |
| Inner copy mode | `Ctrl+[` |
| Inner swap window left / right | `Ctrl+p` / `Ctrl+n` |
| Inner resize coarse | `Ctrl+←/↓/↑/→` (repeatable) |
| Inner resize fine | `Ctrl+Alt+←/↓/↑/→` (repeatable) |

#### Ghostty single-keystroke shortcuts

Ghostty keybinds now serve three purposes:
1. Send proper CSI u sequences for combos macOS can't produce natively (digits, `Tab`)
2. Keep `Ctrl+Alt+...` as the inner-tmux skip-prefix layer
3. Add `Alt+...` skip-prefix shortcuts for the outer tmux bindings that were changed to avoid Shift

| Action | Ghostty shortcut | Without Ghostty |
|---|---|---|
| Outer split horizontal | `Alt+\` | `prefix + \` |
| Outer bottom pane 25% | `Alt+=` | `prefix + =` |
| Outer swap pane down / up | `Alt+.` / `Alt+;` | `prefix + .` / `prefix + ,` |
| Outer swap window L/R | `Alt+p` / `Alt+n` | `prefix + p` / `prefix + n` |
| Outer resize coarse | `Alt+←/↓/↑/→` | `prefix + ←/↓/↑/→` |
| Inner window select 1..9 | `Ctrl+Alt+1..9` | `Ctrl+Alt+1..9` (needs CSI u) |
| Inner next window | `Ctrl+Alt+Tab` | `Ctrl+Alt+Tab` (needs CSI u) |
| Inner new window | `Ctrl+Alt+c` | `prefix + Ctrl+c` |
| Inner close pane | `Ctrl+Alt+x` | `prefix + Ctrl+x` |
| Inner zoom toggle | `Ctrl+Alt+z` | `prefix + Ctrl+z` |
| Inner reload config | `Ctrl+Alt+r` | `prefix + Ctrl+r` |
| Inner split horizontal | `Ctrl+Alt+\` | `prefix + Ctrl+\` |
| Inner split vertical | `Ctrl+Alt+-` | `prefix + Ctrl+-` |
| Inner bottom pane 25% | `Ctrl+Alt+=` | `prefix + Ctrl+=` |
| Inner right pane 33% | `Ctrl+Alt+/` | `prefix + Ctrl+/` |
| Inner swap pane down / up | `Ctrl+Alt+.` / `Ctrl+Alt+;` | `prefix + Ctrl+.` / `prefix + Ctrl+,` |
| Inner copy mode | `Ctrl+Alt+[` | `prefix + Ctrl+[` |
| Inner swap window L/R | `Ctrl+Alt+p` / `Ctrl+Alt+n` | `prefix + Ctrl+p` / `prefix + Ctrl+n` |
| Inner resize coarse | `Ctrl+Alt+←/↓/↑/→` | `prefix + Ctrl+←/↓/↑/→` |

> **Note:** Inner pane navigation (`Ctrl+Alt+h/j/k/l`) needs no Ghostty keybind - it works natively via tmux extended-keys. Inner fine resize (`prefix + Ctrl+Alt+←/↓/↑/→`) still uses the manual tmux binding. F12 REMOTE mode remains the universal fallback.

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
