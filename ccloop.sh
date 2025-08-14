#!/usr/bin/env bash
# ccloop.sh - Claude Continuous Loop: Auto-prompting system for Claude CLI

AUTOPROMPT_FILE="/tmp/claude-autoprompt.txt"
AUTOPROMPT_STATE="/tmp/claude-autoprompt.state"

# Initialize autoprompt
echo "Continue working on the current task" > "$AUTOPROMPT_FILE"
echo "disabled" > "$AUTOPROMPT_STATE"

# Kill any existing session
tmux kill-session -t claude-auto 2>/dev/null

# Start Claude in tmux with all arguments passed through
tmux new-session -d -s claude-auto "claude $*"
sleep 1

# Enable mouse support
tmux set-option -t claude-auto mouse on

# Configure status bar with dark background
tmux set-option -t claude-auto status on
tmux set-option -t claude-auto status-bg black
tmux set-option -t claude-auto status-fg white
tmux set-option -t claude-auto status-interval 1
tmux set-option -t claude-auto status-left-length 50
tmux set-option -t claude-auto status-right-length 80
tmux set-option -t claude-auto status-left "#[fg=cyan,bold]Claude Auto "
tmux set-option -t claude-auto status-right "#[fg=yellow,bold]AutoPrompt: #(cat $AUTOPROMPT_STATE | tr a-z A-Z) #[fg=white]| #[fg=green,bold]^B+t: toggle #[fg=white]| #[fg=blue,bold]^B+e: edit "

# Add tmux key binding to edit autoprompt (Ctrl+b then e) - doesn't re-enable after exit
tmux bind-key -T prefix e run-shell "echo 'disabled' > $AUTOPROMPT_STATE; tmux new-window 'vim $AUTOPROMPT_FILE'"

# Add tmux key binding to toggle autoprompt (Ctrl+b then t)
tmux bind-key -T prefix t run-shell "if [ \$(cat $AUTOPROMPT_STATE) = 'enabled' ]; then echo 'disabled' > $AUTOPROMPT_STATE; tmux display-message 'Auto-prompt DISABLED'; else echo 'enabled' > $AUTOPROMPT_STATE; tmux display-message 'Auto-prompt ENABLED'; fi"

# Monitor and auto-prompt
{
    while true; do
        sleep 5
        
        # Check if autoprompt is enabled
        if [[ "$(cat "$AUTOPROMPT_STATE" 2>/dev/null)" != "enabled" ]]; then
            continue
        fi
        
        # Get the entire screen to check Claude's state
        output=$(tmux capture-pane -t claude-auto -p)
        
        # Check if Claude is currently working
        if echo "$output" | grep -q "esc to interrupt"; then
            # Claude is working, skip this cycle
            continue
        fi
        
        # Claude is not working, wait a bit more to be sure it's idle
        sleep 2
        output=$(tmux capture-pane -t claude-auto -p)
        
        # Double-check Claude is still not working
        if echo "$output" | grep -q "esc to interrupt"; then
            continue
        fi
        
        # Claude is idle, send autoprompt
        if [[ -f "$AUTOPROMPT_FILE" ]]; then
            autoprompt=$(cat "$AUTOPROMPT_FILE" | tr -d '\n')  # Remove newlines
            if [[ -n "$autoprompt" ]]; then
                echo "[AUTO-PROMPTING]: $autoprompt"
                # Don't use -l flag, let tmux interpret the text normally
                tmux send-keys -t claude-auto "$autoprompt"
                tmux send-keys -t claude-auto C-m  # Use C-m for Enter/Return
                sleep 15  # Wait longer before next check
            fi
        fi
    done
} &
MONITOR_PID=$!

echo "ccloop - Claude Continuous Loop starting..."
echo "Check the status bar at the bottom for controls and status"

# Attach to the session
trap "kill $MONITOR_PID 2>/dev/null; tmux kill-session -t claude-auto 2>/dev/null" EXIT
tmux attach -t claude-auto
