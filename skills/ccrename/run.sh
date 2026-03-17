#!/bin/bash

# This script is called by Claude when analyzing and renaming the session
# Claude will pass the generated description as the first argument

description="$1"

# If no description provided, ask Claude to generate one
if [ -z "$description" ]; then
    echo "🤔 Analyzing session context..."
    echo "Please provide a 3-5 word description of the work in this session."
    echo "Focus on: What was fixed/built/changed?"
    exit 1
fi

# Check if in tmux
if [ -z "$TMUX" ]; then
    echo "❌ Not in a tmux session"
    exit 1
fi

# Get current session name
current=$(tmux display-message -p '#S')

# Check if it's a Claude Code session
if [[ ! "$current" =~ ^cc- ]]; then
    echo "❌ Not in a Claude Code session (current: $current)"
    exit 1
fi

# Strip any existing description (keep prefix and timestamp)
base=$(echo "$current" | sed -E 's/(-[a-z]+-[a-z]+.*)$//')

# Add new description
new_name="${base}-${description}"

# Rename the session
tmux rename-session -t "$current" "$new_name" 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ Session renamed: $new_name"
    echo "Summary: $description"
else
    echo "❌ Failed to rename session"
    exit 1
fi