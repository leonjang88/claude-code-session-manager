#!/usr/bin/env bash
# cc-helpers.sh — tmux session manager for Claude Code
# Source this from your ~/.bashrc:  source ~/claude-code-tmux/cc-helpers.sh

# ── Project config ─────────────────────────────────────────────────────────
# Load projects from projects.conf (gitignored, private to each machine).
# See projects.conf.example for format.
_CC_HELPERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$_CC_HELPERS_DIR/projects.conf" ]; then
    source "$_CC_HELPERS_DIR/projects.conf"
else
    echo "cc-helpers: No projects.conf found. Copy projects.conf.example to projects.conf and edit it." >&2
    _CC_PROJECTS=()
    _CC_DEFAULT="$HOME"
fi

# ── Claude flags (set _CC_FLAGS in projects.conf to override) ─────────────
_CC_FLAGS="${_CC_FLAGS:-}"

# ── Internal helpers ───────────────────────────────────────────────────────

# Resolve context name to directory
_cc_dir() {
    local key="${1:-$_CC_DEFAULT_PROJECT}"
    for entry in "${_CC_PROJECTS[@]}"; do
        IFS='|' read -r shortname label dir prefix <<< "$entry"
        if [ "$key" = "$shortname" ]; then
            echo "$dir"
            return
        fi
    done
    echo "$_CC_DEFAULT"
}

# Resolve context name to session prefix
_cc_prefix() {
    local key="${1:-$_CC_DEFAULT_PROJECT}"
    for entry in "${_CC_PROJECTS[@]}"; do
        IFS='|' read -r shortname label dir prefix <<< "$entry"
        if [ "$key" = "$shortname" ]; then
            echo "$prefix"
            return
        fi
    done
    echo "cc-default"
}

# Create a new tmux session, send claude into it, attach
_cc_new_session() {
    local session_name="$1"
    local work_dir="$2"
    local cmd="$3"
    tmux new-session -d -s "$session_name" -c "$work_dir"
    tmux send-keys -t "$session_name" "$cmd" Enter
    tmux attach -t "$session_name"
}

# Picker for multiple sessions
_cc_pick_session() {
    local sessions="$1"
    echo "Active tmux sessions:" >&2
    echo "$sessions" | nl >&2
    echo -n "Which session? (number): " >&2
    read choice </dev/tty
    echo "$sessions" | sed -n "${choice}p"
}

# Pick a project and resume a Claude conversation in it
_cc_pick_project_and_resume() {
    echo "Resume a Claude conversation in which project?" >&2
    local i=1
    for entry in "${_CC_PROJECTS[@]}"; do
        IFS='|' read -r shortname label dir prefix <<< "$entry"
        echo "  $i) $shortname - $label" >&2
        i=$((i+1))
    done
    echo "  $i) current - Current directory" >&2
    echo "" >&2
    echo -n "Project (number): " >&2
    read choice </dev/tty

    local work_dir prefix
    local total=${#_CC_PROJECTS[@]}

    if [ "$choice" -ge 1 ] 2>/dev/null && [ "$choice" -le "$total" ] 2>/dev/null; then
        local entry="${_CC_PROJECTS[$((choice-1))]}"
        IFS='|' read -r shortname label dir prefix <<< "$entry"
        work_dir="$dir"
    elif [ "$choice" = "$((total+1))" ]; then
        work_dir="$PWD"
        prefix="cc-$(basename "$PWD")"
    else
        echo "Invalid selection"
        return 1
    fi

    local session_name="${prefix}-$(date +%m%d-%I%M%p | tr '[:upper:]' '[:lower:]')"
    local cmd="claude $_CC_FLAGS --resume"
    echo "Starting new tmux session in $work_dir..."
    _cc_new_session "$session_name" "$work_dir" "$cmd"
}

# Switch to a different project within the current tmux session
_cc_switch_project_in_session() {
    echo "Switch to project:" >&2
    local i=1
    for entry in "${_CC_PROJECTS[@]}"; do
        IFS='|' read -r shortname label dir prefix <<< "$entry"
        echo "  $i) $shortname - $label" >&2
        i=$((i+1))
    done
    echo "  $i) current - Stay in current directory" >&2
    echo "" >&2
    echo -n "Which project? (number): " >&2
    read choice </dev/tty

    local work_dir
    local total=${#_CC_PROJECTS[@]}

    if [ "$choice" -ge 1 ] 2>/dev/null && [ "$choice" -le "$total" ] 2>/dev/null; then
        local entry="${_CC_PROJECTS[$((choice-1))]}"
        IFS='|' read -r shortname label dir prefix <<< "$entry"
        work_dir="$dir"
    elif [ "$choice" = "$((total+1))" ]; then
        work_dir="$PWD"
    else
        echo "Invalid selection"
        return 1
    fi

    echo "Switching to $work_dir..."
    cd "$work_dir"
    claude $_CC_FLAGS --resume
}

# ── Public commands ────────────────────────────────────────────────────────

# cc [context] — new Claude Code session in a tmux window
cc() {
    # cc clear [all|context|session-name]
    if [ "$1" = "clear" ]; then
        local sessions

        # No arg: interactive picker
        if [ -z "$2" ]; then
            sessions=$(tmux ls 2>/dev/null | grep "^cc-" | cut -d: -f1)
            if [ -z "$sessions" ]; then
                echo "No tmux sessions found."
                return
            fi
            echo "Select session(s) to kill:" >&2
            echo "$sessions" | nl >&2
            echo "" >&2
            echo "Enter number(s) separated by spaces (or 'all' for all):" >&2
            read choices </dev/tty

            if [ "$choices" = "all" ]; then
                echo "Killing ALL tmux sessions"
                echo "$sessions" | xargs -I {} tmux kill-session -t {}
            else
                for choice in $choices; do
                    local selected
                    selected=$(echo "$sessions" | sed -n "${choice}p")
                    if [ -n "$selected" ]; then
                        echo "Killing $selected"
                        tmux kill-session -t "$selected"
                    fi
                done
            fi
            echo "Done."
            return
        fi

        # cc clear all - nuclear mode
        if [ "$2" = "all" ]; then
            sessions=$(tmux ls 2>/dev/null | grep "^cc-" | cut -d: -f1)
            if [ -z "$sessions" ]; then
                echo "No tmux sessions found."
            else
                echo "Nuclear clear - killing ALL tmux sessions:"
                echo "$sessions"
                echo "$sessions" | xargs -I {} tmux kill-session -t {}
                echo "Done."
            fi
            return
        fi

        # Check if it's a full session name
        if tmux has-session -t "$2" 2>/dev/null; then
            echo "Killing session: $2"
            tmux kill-session -t "$2"
            echo "Done."
            return
        fi

        # Otherwise treat as context prefix
        local prefix
        prefix=$(_cc_prefix "$2")
        sessions=$(tmux ls 2>/dev/null | grep "^${prefix}" | cut -d: -f1)
        if [ -z "$sessions" ]; then
            echo "No sessions matching '${prefix}' or '$2' found."
        else
            echo "Killing ${prefix} sessions:"
            echo "$sessions"
            echo "$sessions" | xargs -I {} tmux kill-session -t {}
            echo "Done."
        fi
        return
    fi

    # cc discord — Claude Code with Discord channel connected
    if [ "$1" = "discord" ]; then
        local work_dir="$_CC_DEFAULT"
        local prefix="cc-discord"
        local discord_flags=$(echo "$_CC_FLAGS" | sed 's/--model [^ ]*//')
        local cmd="claude --channels plugin:discord@claude-plugins-official $discord_flags --model 'claude-opus-4-6[1m]'"

        if [ -n "$TMUX" ]; then
            cd "$work_dir" && eval "$cmd"
        else
            local session_name="${prefix}-$(date +%m%d-%I%M%p | tr '[:upper:]' '[:lower:]')"
            _cc_new_session "$session_name" "$work_dir" "$cmd"
        fi
        return
    fi

    local ctx="$1"
    local work_dir
    work_dir=$(_cc_dir "$ctx")
    local prefix
    prefix=$(_cc_prefix "$ctx")
    local cmd="claude $_CC_FLAGS"

    if [ -n "$TMUX" ]; then
        cd "$work_dir" && eval "$cmd"
    else
        local session_name="${prefix}-$(date +%m%d-%I%M%p | tr '[:upper:]' '[:lower:]')"
        _cc_new_session "$session_name" "$work_dir" "$cmd"
    fi
}

# ccs — quick Claude conversation switcher (for use within tmux)
ccs() {
    if [ -z "$TMUX" ]; then
        echo "Not in a tmux session. Use ccr instead." >&2
        return 1
    fi

    # Show resume menu directly
    claude $_CC_FLAGS --resume
}

# ccr — resume/attach to any Claude Code tmux session
ccr() {
    local cmd="claude $_CC_FLAGS --resume"

    # If already in tmux, handle session switching differently
    if [ -n "$TMUX" ]; then
        if ! tty -s; then
            echo "You're already in a tmux session but have no TTY (probably inside Claude)." >&2
            echo "   Exit this session first (exit or Ctrl-D), then run ccr from your terminal." >&2
            return 1
        fi

        # Find ALL Claude Code sessions
        local sessions
        sessions=$(tmux ls 2>/dev/null | grep "^cc-" | cut -d: -f1)

        if [ -z "$sessions" ]; then
            echo "No other tmux sessions found. Continue in current session." >&2
            eval "$cmd"
            return
        fi

        # Show current session and available options
        echo "Current session: $(tmux display-message -p '#S')" >&2
        echo "" >&2
        echo "Available tmux sessions:" >&2
        local i=1
        while IFS= read -r session; do
            echo "  $i) $session" >&2
            i=$((i+1))
        done <<< "$sessions"
        echo "  c) Continue in current directory" >&2
        echo "  n) New tmux session" >&2
        echo -n "Choice: " >&2
        read choice </dev/tty

        if [ "$choice" = "c" ]; then
            eval "$cmd"
            return
        elif [ "$choice" = "n" ]; then
            _cc_switch_project_in_session
            return
        elif [[ "$choice" =~ ^[0-9]+$ ]]; then
            local selected_session=$(echo "$sessions" | sed -n "${choice}p")
            if [ -n "$selected_session" ]; then
                echo "Switching to session: $selected_session"
                tmux switch-client -t "$selected_session"
            else
                echo "Invalid selection"
            fi
            return
        else
            echo "Invalid selection"
            return
        fi
    fi

    # Find ALL Claude Code sessions across all projects
    local sessions
    sessions=$(tmux ls 2>/dev/null | grep "^cc-" | cut -d: -f1)

    if [ -z "$sessions" ]; then
        # No sessions exist - start a new one in current dir or default
        local work_dir="${PWD}"
        if [ "$PWD" != "$_CC_DEFAULT" ]; then
            work_dir="$_CC_DEFAULT"
        fi
        local session_name="cc-default-$(date +%m%d-%I%M%p | tr '[:upper:]' '[:lower:]')"
        echo "No tmux sessions found. Starting new tmux session..."
        _cc_new_session "$session_name" "$work_dir" "$cmd"
    elif [ "$(echo "$sessions" | wc -l)" -eq 1 ]; then
        # Only one session - ask if they want to attach or start new
        echo "Found 1 session: $sessions" >&2
        echo "" >&2
        echo "  1) Attach to existing session" >&2
        echo "  2) New tmux session" >&2
        echo -n "Choice: " >&2
        read choice </dev/tty

        if [ "$choice" = "1" ]; then
            tmux attach -t "$sessions"
        elif [ "$choice" = "2" ]; then
            _cc_pick_project_and_resume
        else
            echo "Invalid selection"
        fi
    else
        # Multiple sessions - show picker with new tmux session option
        echo "All tmux sessions:" >&2
        echo "$sessions" | nl >&2
        local total=$(echo "$sessions" | wc -l)
        local next=$((total + 1))
        echo "  $next) New tmux session" >&2
        echo "" >&2
        echo -n "Which session? (number): " >&2
        read choice </dev/tty

        if [ "$choice" = "$next" ]; then
            _cc_pick_project_and_resume
        else
            local selected
            selected=$(echo "$sessions" | sed -n "${choice}p")
            if [ -n "$selected" ]; then
                tmux attach -t "$selected"
            else
                echo "Invalid selection"
            fi
        fi
    fi
}
