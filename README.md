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
| `--yazi` | Install [yazi](https://github.com/sxyazi/yazi) terminal file manager (opt-in) |

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

Ghostty is **built from source** on Linux using Zig. This takes a few minutes on first run. The script:
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
| Disable Ctrl-s flow control | `stty -ixon` |
| `export PATH="$HOME/.local/bin:$PATH"` | `.local/bin` (Linux only) |
| oh-my-posh prompt init | `oh-my-posh init` |
| zsh-autosuggestions source | `zsh-autosuggestions.zsh` (zsh only) |
| `pastefile` helper function | `pastefile()` |
| Ghostty tmux auto-attach | `TERM_PROGRAM.*ghostty.*tmux` (macOS only) |
| SSH tmux auto-attach | `new-session -A -s RZ-AI` |

### tmux Auto-Attach Behaviour

The two snippets are independent and do not conflict.

**Local — MacBook + Ghostty** (added to `~/.zshrc` on macOS):
```zsh
if [ -z "$TMUX" ] && [ "$TERM_PROGRAM" = "ghostty" ]; then
  tmux attach-session -t main 2>/dev/null || tmux new-session -s main
fi
```

**Remote — Mac Studio / DGX Spark via SSH** (added to `~/.zshrc` or `~/.bashrc`):
```bash
if [[ -z "$TMUX" ]] && [[ -n "$SSH_TTY" ]] && [[ $- =~ i ]]; then
  exec tmux new-session -A -s RZ-AI
fi
```

---

## tmux ZenGarden

The tmux config is sourced from **[roundzero-ai/tmux-zengarden](https://github.com/roundzero-ai/tmux-zengarden)** — cloned on first run, updated on every subsequent run via `git pull`.

### Status Bar

```
 ≋ ZenGarden │ user@host        dim-1:win  dim-2:win  ╭ 3:active ╮  dim-4:win
  session                      git ⎇ branch  CPU 18%  MEM 12G  GPU 20%  14:35 Fri
```

- **Line 0** — Brand pill + identity (left) · Colored window tabs per window (right)
- **Line 1** — Session pill (left) · git · CPU · RAM · GPU · time (right)
- GPU stats: `ioreg` on Apple Silicon (no sudo) · `nvidia-smi` on DGX Spark (UMA-aware for GB10)

### Key Bindings

| Action | Key |
|---|---|
| Prefix | `Ctrl-s` |
| Navigate panes | `Alt+h/j/k/l` (no prefix) or `prefix + h/j/k/l` |
| Resize pane (coarse) | `prefix + H/J/K/L` |
| Split horizontal | `prefix + \|` |
| Split vertical | `prefix + -` |
| Zoom pane | `prefix + z` |
| Switch window | `Alt+1` – `Alt+9` |
| Prev / next window | `Alt+[` / `Alt+]` |
| Last window | `prefix + Tab` |
| Reload config | `prefix + r` |
| Copy mode | `prefix + [` → `v` select → `y` yank |

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

## Project Structure

```
tui-zening/
├── setup.sh          # main setup script
├── config/
│   ├── ghostty       # Ghostty terminal config
│   └── nanorc        # nano editor config
└── README.md
```

tmux config and oh-my-posh theme:
→ **[roundzero-ai/tmux-zengarden](https://github.com/roundzero-ai/tmux-zengarden)**
