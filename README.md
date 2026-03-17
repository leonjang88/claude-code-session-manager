# claude-code-tmux

Tmux session manager for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Manages multiple Claude conversations across project directories using named tmux sessions.

## Setup

1. Clone this repo:
   ```bash
   git clone https://github.com/ljang0/claude-code-tmux.git ~/claude-code-tmux
   ```

2. Edit project paths at the top of `cc-helpers.sh` to match your machine:
   ```bash
   _CC_HA="$HOME/pezbox/infra/homeAssistant"
   _CC_HW="$HOME/pezbox/hiveworth"
   _CC_RS="$HOME/pezbox/redfin-scraper"
   _CC_DEFAULT="$HOME/pezbox"
   ```

3. Add to your `~/.bashrc` (or `~/.zshrc`):
   ```bash
   source ~/claude-code-tmux/cc-helpers.sh
   ```

4. Reload your shell:
   ```bash
   source ~/.bashrc
   ```

## Commands

| Command | What it does |
|---------|-------------|
| `cc` | New Claude session in default project |
| `cc ha` | New Claude session in Home Assistant project |
| `cc hw` | New Claude session in Hiveworth project |
| `ccr` | Resume — pick an existing tmux session or start a new one |
| `ccs` | Switch Claude conversations within current tmux session |
| `cc clear` | Interactive picker to kill tmux sessions |
| `cc clear all` | Kill all `cc-*` tmux sessions |
| `cc clear ha` | Kill all Home Assistant sessions |

## How it works

- **`cc [project]`** creates a new tmux session named like `cc-ha-0317-0230pm`, cds into the project directory, and launches `claude`
- **`ccr`** lists all `cc-*` tmux sessions and lets you attach to one, or create a new tmux session and pick a Claude conversation to resume via `--resume`
- **`ccs`** (inside tmux) brings up Claude's conversation picker directly

## Detaching

To leave a session without killing it: **`Ctrl+b` then `d`** (tmux detach). The tmux session and Claude keep running in the background.

## Adding projects

Edit the `_CC_PROJECTS` array in `cc-helpers.sh`:

```bash
_CC_PROJECTS=(
    "ha|Home Assistant|_CC_HA|cc-ha"
    "hw|Hiveworth|_CC_HW|cc-hw"
    "rs|Redfin Scraper|_CC_RS|cc-rs"
    "pb|Pezbox|_CC_DEFAULT|cc-pezbox"
    "myapp|My App|_CC_MYAPP|cc-myapp"   # add new project
)
```

Then add the path variable above:
```bash
_CC_MYAPP="$HOME/projects/myapp"
```

## Requirements

- [tmux](https://github.com/tmux/tmux)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI installed and authenticated
