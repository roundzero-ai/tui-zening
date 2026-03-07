# tui_zening

One-command terminal environment setup for consistent coding experience across **MacBook Pro**, **Mac Studio**, and **NVIDIA DGX Spark GB10**.

Installs and configures:
- **Ghostty** — terminal config (transparency, blur, font)
- **oh-my-posh** — shell prompt (path · python · exit status)
- **tmux ZenGarden** — modern tmux with colored tabs, system stats, vim navigation

---

## Quick Start

```bash
git clone https://github.com/roundzero-ai/tui-zening.git
cd tui-zening
bash setup.sh
```

After setup, reload your shell:
```bash
source ~/.zshrc    # macOS
source ~/.bashrc   # DGX Spark / Linux
```

---

## What Gets Installed

| Component | macOS (zsh) | DGX Spark / Linux (bash) |
|---|---|---|
| tmux | ✓ | ✓ |
| oh-my-posh | ✓ | ✓ |
| tmux ZenGarden config | ✓ | ✓ |
| zsh-autosuggestions | ✓ | — (bash) |
| JetBrainsMono Nerd Font | ✓ | — (headless) |
| Ghostty config | ✓ | — (headless) |
| yazi file manager | opt-in `--yazi` | opt-in `--yazi` |

On **headless Linux** (no `$DISPLAY`), Ghostty config and fonts are automatically skipped.

---

## Options

```
bash setup.sh [--no-ghostty] [--no-fonts] [--yazi]
```

| Flag | Effect |
|---|---|
| `--no-ghostty` | Skip Ghostty config deployment |
| `--no-fonts` | Skip JetBrainsMono Nerd Font installation |
| `--yazi` | Install [yazi](https://github.com/sxyazi/yazi) terminal file manager |

---

## Per-machine Usage

### MacBook Pro (local machine)

```bash
bash setup.sh
```

- Deploys Ghostty config (transparency, blur, JetBrainsMono)
- Installs zsh-autosuggestions
- Sets up tmux auto-attach on Ghostty launch
- Patches `~/.zshrc`

### Mac Studio (remote via SSH)

```bash
# From your MacBook, copy and run:
rsync -av tui-zening/ mac-studio:~/tui-zening/
ssh mac-studio "bash ~/tui-zening/setup.sh"
```

Or clone directly on the machine:
```bash
ssh mac-studio
git clone https://github.com/roundzero-ai/tui-zening.git
bash tui-zening/setup.sh
```

- Skips Ghostty config automatically (headless)
- Sets up SSH tmux auto-attach (`tmux new-session -A -s RZ-AI`)
- Patches `~/.zshrc`

### DGX Spark GB10 (remote via SSH, Ubuntu + bash)

```bash
ssh dgx-spark
git clone https://github.com/roundzero-ai/tui-zening.git
bash tui-zening/setup.sh
```

With yazi:
```bash
bash tui-zening/setup.sh --yazi
```

- Detects bash → patches `~/.bashrc`, skips zsh-specific steps
- Skips Ghostty config and fonts automatically (headless)
- Installs oh-my-posh with `init bash`
- Downloads pre-built yazi binary for `aarch64` (GB10 ARM64)
- Sets up SSH tmux auto-attach (`tmux new-session -A -s RZ-AI`)

---

## What Gets Added to Your Shell RC

The script patches `~/.zshrc` (macOS/zsh) or `~/.bashrc` (Linux/bash). Each block is added only once — safe to re-run.

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

**Local (MacBook + Ghostty)** — added to `~/.zshrc`:
```zsh
if [ -z "$TMUX" ] && [ "$TERM_PROGRAM" = "ghostty" ]; then
  tmux attach-session -t main 2>/dev/null || tmux new-session -s main
fi
```

**Remote (Mac Studio, DGX Spark via SSH)** — added to `~/.zshrc` / `~/.bashrc`:
```bash
if [[ -z "$TMUX" ]] && [[ -n "$SSH_TTY" ]] && [[ $- =~ i ]]; then
  exec tmux new-session -A -s RZ-AI
fi
```

These two blocks are independent and do not conflict.

---

## tmux ZenGarden

The tmux config is sourced from **[roundzero-ai/tmux-zengarden](https://github.com/roundzero-ai/tmux-zengarden)** and kept up to date on every run via `git pull`.

### Status Bar

```
 ≋ ZenGarden │ user@host        dim-1:win  dim-2:win  ╭ 3:active ╮  dim-4:win
  session                           git ⎇ branch  CPU 18%  MEM 12G  GPU 20%  14:35 Fri
```

- **Line 0** — Brand + identity (left) · Colored window tabs (right)
- **Line 1** — Session pill (left) · git · CPU · RAM · GPU · time (right)
- GPU: `ioreg` on Apple Silicon (no sudo), `nvidia-smi` on DGX Spark (UMA-aware)

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

The prompt shows only what tmux doesn't already display:

```
 ~/Projects/tui_zening   3.12.2  ✓
```

| Segment | Shows |
|---|---|
| `root` | Lightning bolt when running as root |
| `path` | Current directory (agnoster style) |
| `python` | Active venv + Python version |
| `status` | Exit code of last command (on failure) |

> git branch and hostname are intentionally omitted — they're in the tmux banner.

Theme file: `~/.config/oh-my-posh/zengarden.json`

---

## Ghostty Config

Deployed to `~/Library/Application Support/com.mitchellh.ghostty/config` on macOS.

Key settings:
```
theme              = Bright Lights
font-family        = JetBrainsMono NFM Regular
font-size          = 13
background-opacity = 0.8
background-blur    = 90
macos-titlebar-style = transparent
```

The blur + transparency is what makes tmux's `bg=default` pane backgrounds look frosted.

---

## Re-running / Updating

All steps are idempotent. To update tmux ZenGarden and re-deploy everything:

```bash
cd ~/tui-zening
git pull
bash setup.sh
```

This will:
- `git pull` the latest tmux-zengarden config
- Re-deploy tmux config and oh-my-posh theme
- Skip all already-installed tools
- Skip already-present shell RC blocks

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

tmux config and oh-my-posh theme live in a separate repo:
→ [roundzero-ai/tmux-zengarden](https://github.com/roundzero-ai/tmux-zengarden)
