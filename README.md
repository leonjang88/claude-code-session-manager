# claude-code-session-manager

Tmux session manager for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Manages multiple Claude conversations across project directories using named tmux sessions.

## Setup

1. Clone this repo:
   ```bash
   git clone https://github.com/ljang0/claude-code-session-manager.git ~/claude-code-session-manager
   ```

2. Create your project config (this file is gitignored — your project names stay private):
   ```bash
   cp ~/claude-code-session-manager/projects.conf.example ~/claude-code-session-manager/projects.conf
   ```

3. Edit `projects.conf` to match your machine:
   ```bash
   _CC_PROJECTS=(
       "app|My App|$HOME/projects/my-app|cc-app"
       "api|API Server|$HOME/projects/api|cc-api"
       "home|Home|$HOME/projects|cc-home"
   )

   _CC_DEFAULT="$HOME/projects"
   ```
   Format: `shortname|Label|path|session-prefix`

4. Add to your `~/.bashrc` (or `~/.zshrc`):
   ```bash
   source ~/claude-code-session-manager/cc-helpers.sh
   ```

5. Reload your shell:
   ```bash
   source ~/.bashrc
   ```

## Commands

| Command | What it does |
|---------|-------------|
| `cc` | New Claude session in default project |
| `cc app` | New Claude session in "app" project (uses your shortnames from projects.conf) |
| `ccr` | Resume — pick an existing tmux session or start a new one with a Claude conversation picker |
| `ccs` | Switch Claude conversations within current tmux session |
| `cc clear` | Interactive picker to kill tmux sessions |
| `cc clear all` | Kill all `cc-*` tmux sessions |
| `cc clear app` | Kill all sessions for a specific project |
| `/ccrename` | (Inside Claude) Auto-rename tmux session based on current work |

## How it works

- **`cc [project]`** creates a new tmux session named like `cc-app-0317-0230pm`, cds into the project directory, and launches `claude`
- **`ccr`** lists all `cc-*` tmux sessions and lets you attach to one, or create a new tmux session and pick a Claude conversation to resume via `--resume`
- **`ccs`** (inside tmux) brings up Claude's conversation picker directly

## Detaching

To leave a session running in the background: **`Ctrl+b` then `d`** (tmux detach). Both the tmux session and Claude keep running. Use `ccr` to come back later.

## Adding projects

Edit `projects.conf` and add entries to the `_CC_PROJECTS` array:

```bash
_CC_PROJECTS=(
    "app|My App|$HOME/projects/my-app|cc-app"
    "api|API Server|$HOME/projects/api|cc-api"
    "new|New Project|$HOME/projects/new-thing|cc-new"
)
```

Then reload: `source ~/.bashrc`

## Bonus: `/ccrename` skill

The repo includes a Claude Code skill that auto-renames your tmux session based on what you've been working on.

To install it, symlink the skill into your Claude config:

```bash
ln -s ~/claude-code-session-manager/skills/ccrename ~/.claude/skills/ccrename
```

Then inside a Claude session, run `/ccrename` and it'll rename the tmux session with a short description like `cc-app-0317-0230pm-fix-auth-flow`.

## Requirements

- [tmux](https://github.com/tmux/tmux)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI installed and authenticated
