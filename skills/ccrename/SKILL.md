# ccrename

Analyzes recent work and renames the tmux session with a descriptive summary.

## Usage

Just run the command - Claude will analyze what you've been working on and create a 3-5 word description automatically.

```
/ccrename
```

Or just tell Claude: "rename this session" or "rename the session"

## How it works

1. Claude analyzes recent file edits, conversations, and context
2. Generates a 3-5 word hyphenated summary
3. Renames the tmux session to include that description

Example: `cc-ha-0226-0846pm` → `cc-ha-0226-0846pm-fix-washer-automation`