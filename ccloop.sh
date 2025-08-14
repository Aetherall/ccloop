#!/usr/bin/env bash
# ccloop.sh - Claude Continuous Loop: Auto-prompting system for Claude CLI

# Configuration paths
AUTOPROMPT_FILE="/tmp/claude-autoprompt.txt"
AUTOPROMPT_STATE="/tmp/claude-autoprompt.state"
PROMPTS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ccloop/prompts"
PROMPT_USAGE_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/ccloop/prompt_usage"
CURRENT_PROMPT_NAME="/tmp/claude-current-prompt-name.txt"

# === PROMPT MANAGEMENT FUNCTIONS ===

# Save current prompt back to storage
ccloop_save_prompt() {
    local current_name=$(cat "$CURRENT_PROMPT_NAME" 2>/dev/null || echo "default.md")
    cp "$AUTOPROMPT_FILE" "$PROMPTS_DIR/$current_name"
    
    # Update usage timestamp
    local temp_file=$(mktemp)
    grep -v "^$current_name|" "$PROMPT_USAGE_FILE" 2>/dev/null > "$temp_file" || true
    echo "$current_name|$(date +%s)" >> "$temp_file"
    mv "$temp_file" "$PROMPT_USAGE_FILE"
}

# Extract metadata from prompt file
ccloop_get_metadata() {
    local file="$1"
    local field="$2"
    
    # Check if file has metadata block
    if head -1 "$file" | grep -q "^---$"; then
        # Extract metadata block between --- markers
        sed -n '/^---$/,/^---$/p' "$file" | grep "^$field:" | cut -d':' -f2- | xargs
    fi
}

# Get prompt content without metadata
ccloop_get_content() {
    local file="$1"
    
    if head -1 "$file" | grep -q "^---$"; then
        # Skip metadata block - extract content after second ---
        awk '/^---$/{i++}i==2{print}' "$file" | tail -n +2
    else
        cat "$file"
    fi
}

# Process @include directives
ccloop_process_includes() {
    local content="$1"
    local processed=""
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^@include[[:space:]]+(.+)$ ]]; then
            local include_file="${BASH_REMATCH[1]}"
            # Handle relative and absolute paths
            if [[ ! "$include_file" =~ ^/ ]]; then
                include_file="$PROMPTS_DIR/$include_file"
            fi
            if [[ -f "$include_file" ]]; then
                # Recursively process includes
                local included_content=$(ccloop_get_content "$include_file")
                processed+=$(ccloop_process_includes "$included_content")$'\n'
            else
                processed+="$line"$'\n'
            fi
        else
            processed+="$line"$'\n'
        fi
    done <<< "$content"
    
    echo "$processed"
}

# Load a prompt with metadata and includes
ccloop_load_prompt() {
    local prompt_file="$1"
    local prompt_name=$(basename "$prompt_file")
    
    if [[ -f "$prompt_file" ]]; then
        # Get content and process includes
        local content=$(ccloop_get_content "$prompt_file")
        content=$(ccloop_process_includes "$content")
        
        # Remove trailing newlines for sending to Claude
        echo "$content" | sed '/^[[:space:]]*$/d' > "$AUTOPROMPT_FILE"
        echo "$prompt_name" > "$CURRENT_PROMPT_NAME"
        
        # Update usage
        local temp_file=$(mktemp)
        grep -v "^$prompt_name|" "$PROMPT_USAGE_FILE" 2>/dev/null > "$temp_file" || true
        echo "$prompt_name|$(date +%s)" >> "$temp_file"
        mv "$temp_file" "$PROMPT_USAGE_FILE"
        
        return 0
    fi
    return 1
}

# Prompt selection UI
ccloop_select_prompt() {
    clear
    echo "=== ccloop Prompt Manager ==="
    echo
    
    # Build arrays for prompts
    local prompt_files=()
    local prompt_names=()
    local prompt_previews=()
    
    # Read prompts sorted by usage
    if [[ -f "$PROMPT_USAGE_FILE" ]]; then
        while IFS='|' read -r name timestamp; do
            if [[ -f "$PROMPTS_DIR/$name" ]]; then
                prompt_files+=("$PROMPTS_DIR/$name")
                prompt_names+=("$name")
                
                # Get preview with metadata if available
                local tags=$(ccloop_get_metadata "$PROMPTS_DIR/$name" "tags")
                local preview=$(ccloop_get_content "$PROMPTS_DIR/$name" | head -1 | cut -c1-40)
                if [[ -n "$tags" ]]; then
                    prompt_previews+=("$preview [$tags]")
                else
                    prompt_previews+=("$preview")
                fi
            fi
        done < <(sort -t'|' -k2 -rn "$PROMPT_USAGE_FILE")
    fi
    
    # Add prompts not in usage file
    for prompt_file in "$PROMPTS_DIR"/*.md; do
        if [[ -f "$prompt_file" ]]; then
            local name=$(basename "$prompt_file")
            if ! printf '%s\n' "${prompt_names[@]}" 2>/dev/null | grep -q "^$name$"; then
                prompt_files+=("$prompt_file")
                prompt_names+=("$name")
                local preview=$(ccloop_get_content "$prompt_file" | head -1 | cut -c1-40)
                prompt_previews+=("$preview")
            fi
        fi
    done
    
    # Display menu
    echo "Select a prompt:"
    echo
    for i in "${!prompt_names[@]}"; do
        printf "  %2d) %-20s  %s\n" $((i+1)) "${prompt_names[$i]}" "${prompt_previews[$i]}"
    done
    echo
    echo "  n) Create new prompt"
    echo "  q) Cancel"
    echo
    
    read -p "Choice: " choice
    
    case "$choice" in
        n|N)
            read -p "Enter name for new prompt (without .md): " new_name
            if [[ -n "$new_name" ]]; then
                new_name="${new_name%.md}.md"
                cat > "$PROMPTS_DIR/$new_name" << PROMPT_EOF
---
tags: []
created: $(date +%Y-%m-%d)
---
# New Prompt

Describe what you want Claude to do...
PROMPT_EOF
                vim "$PROMPTS_DIR/$new_name"
                ccloop_load_prompt "$PROMPTS_DIR/$new_name"
                tmux display-message "Created and loaded: $new_name"
            fi
            ;;
        q|Q)
            return
            ;;
        [0-9]*)
            local idx=$((choice - 1))
            if [[ $idx -ge 0 && $idx -lt ${#prompt_files[@]} ]]; then
                ccloop_load_prompt "${prompt_files[$idx]}"
                tmux display-message "Loaded: ${prompt_names[$idx]}"
            fi
            ;;
    esac
}

# === INITIALIZATION ===

# Handle special arguments
if [[ "$1" == "--select-prompt" ]]; then
    ccloop_select_prompt
    exit 0
fi

# Create prompts directory if it doesn't exist
mkdir -p "$PROMPTS_DIR"

# Initialize default prompt if no prompts exist
if [ ! "$(ls -A "$PROMPTS_DIR" 2>/dev/null)" ]; then
    cat > "$PROMPTS_DIR/default.md" << DEFAULT_PROMPT
---
tags: [default]
created: $(date +%Y-%m-%d)
---
Continue working on the current task
DEFAULT_PROMPT
fi

# Initialize autoprompt with the most recently used or default
if [[ -f "$PROMPT_USAGE_FILE" ]]; then
    # Get most recently used prompt
    most_recent=$(sort -t'|' -k2 -rn "$PROMPT_USAGE_FILE" | head -1 | cut -d'|' -f1)
    if [[ -f "$PROMPTS_DIR/$most_recent" ]]; then
        ccloop_load_prompt "$PROMPTS_DIR/$most_recent"
    else
        ccloop_load_prompt "$PROMPTS_DIR/default.md"
    fi
else
    ccloop_load_prompt "$PROMPTS_DIR/default.md"
fi

echo "disabled" > "$AUTOPROMPT_STATE"

# === TMUX SETUP ===

# Kill any existing session
tmux kill-session -t claude-auto 2>/dev/null

# Start Claude in tmux with all arguments passed through
# Unset TMUX to allow Claude to create nested tmux sessions
tmux new-session -d -s claude-auto "unset TMUX; claude $*"
sleep 1

# Enable mouse support
tmux set-option -t claude-auto mouse on

# Configure status bar with dark background
tmux set-option -t claude-auto status on
tmux set-option -t claude-auto status-bg black
tmux set-option -t claude-auto status-fg white
tmux set-option -t claude-auto status-interval 1
tmux set-option -t claude-auto status-left-length 50
tmux set-option -t claude-auto status-right-length 90
tmux set-option -t claude-auto status-left "#[fg=cyan,bold]ccloop "
tmux set-option -t claude-auto status-right "#[fg=yellow,bold]Auto: #(cat $AUTOPROMPT_STATE | tr a-z A-Z) #[fg=white]| #[fg=green,bold]^B+t: toggle #[fg=white]| #[fg=blue,bold]^B+e: edit #[fg=white]| #[fg=cyan,bold]^B+o: open #[fg=white]| #[fg=magenta,bold]^B+s: save "

# Export functions for use in subshells
export -f ccloop_save_prompt
export -f ccloop_get_metadata
export -f ccloop_get_content
export -f ccloop_process_includes
export -f ccloop_load_prompt
export -f ccloop_select_prompt

# Write selection script with all functions embedded
cat > /tmp/ccloop-select.sh << 'SELECT_SCRIPT'
#!/usr/bin/env bash
PROMPTS_DIR="${PROMPTS_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/ccloop/prompts}"
AUTOPROMPT_FILE="${AUTOPROMPT_FILE:-/tmp/claude-autoprompt.txt}"
CURRENT_PROMPT_NAME="${CURRENT_PROMPT_NAME:-/tmp/claude-current-prompt-name.txt}"
PROMPT_USAGE_FILE="${PROMPT_USAGE_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/ccloop/prompt_usage}"

# Get prompt content without metadata
ccloop_get_content() {
    file="$1"
    if head -1 "$file" | grep -q "^---$"; then
        awk '/^---$/{i++}i==2{print}' "$file" | tail -n +2
    else
        cat "$file"
    fi
}

# Get metadata
ccloop_get_metadata() {
    local file="$1"
    local field="$2"
    if head -1 "$file" | grep -q "^---$"; then
        sed -n '/^---$/,/^---$/p' "$file" | grep "^$field:" | cut -d':' -f2- | xargs
    fi
}

# Process includes
ccloop_process_includes() {
    local content="$1"
    local processed=""
    while IFS= read -r line; do
        if [[ "$line" =~ ^@include[[:space:]]+(.+)$ ]]; then
            local include_file="${BASH_REMATCH[1]}"
            if [[ ! "$include_file" =~ ^/ ]]; then
                include_file="$PROMPTS_DIR/$include_file"
            fi
            if [[ -f "$include_file" ]]; then
                local included_content=$(ccloop_get_content "$include_file")
                processed+=$(ccloop_process_includes "$included_content")$'\n'
            else
                processed+="$line"$'\n'
            fi
        else
            processed+="$line"$'\n'
        fi
    done <<< "$content"
    echo "$processed"
}

# Load prompt
ccloop_load_prompt() {
    prompt_file="$1"
    prompt_name=$(basename "$prompt_file")
    if [[ -f "$prompt_file" ]]; then
        content=$(ccloop_get_content "$prompt_file")
        content=$(ccloop_process_includes "$content")
        # Save processed content to the temporary file
        echo "$content" | sed '/^[[:space:]]*$/d' > "$AUTOPROMPT_FILE"
        echo "$prompt_name" > "$CURRENT_PROMPT_NAME"
        temp_file=$(mktemp)
        grep -v "^$prompt_name|" "$PROMPT_USAGE_FILE" 2>/dev/null > "$temp_file" || true
        echo "$prompt_name|$(date +%s)" >> "$temp_file"
        mv "$temp_file" "$PROMPT_USAGE_FILE"
        return 0
    fi
    return 1
}

clear
echo "=== ccloop Prompt Manager ==="
echo

prompt_files=()
prompt_names=()
prompt_previews=()

if [[ -f "$PROMPT_USAGE_FILE" ]]; then
    while IFS='|' read -r name timestamp; do
        if [[ -f "$PROMPTS_DIR/$name" ]]; then
            prompt_files+=("$PROMPTS_DIR/$name")
            prompt_names+=("$name")
            tags=$(ccloop_get_metadata "$PROMPTS_DIR/$name" "tags")
            preview=$(ccloop_get_content "$PROMPTS_DIR/$name" | head -1 | cut -c1-40)
            if [[ -n "$tags" ]]; then
                prompt_previews+=("$preview [$tags]")
            else
                prompt_previews+=("$preview")
            fi
        fi
    done < <(sort -t'|' -k2 -rn "$PROMPT_USAGE_FILE")
fi

for prompt_file in "$PROMPTS_DIR"/*.md; do
    if [[ -f "$prompt_file" ]]; then
        name=$(basename "$prompt_file")
        if ! printf '%s\n' "${prompt_names[@]}" 2>/dev/null | grep -q "^$name$"; then
            prompt_files+=("$prompt_file")
            prompt_names+=("$name")
            preview=$(ccloop_get_content "$prompt_file" | head -1 | cut -c1-40)
            prompt_previews+=("$preview")
        fi
    fi
done

echo "Select a prompt:"
echo
for i in "${!prompt_names[@]}"; do
    printf "  %2d) %-20s  %s\n" $((i+1)) "${prompt_names[$i]}" "${prompt_previews[$i]}"
done
echo
echo "  n) Create new prompt"
echo "  q) Cancel"
echo

read -p "Choice: " choice

case "$choice" in
    n|N)
        read -p "Enter name for new prompt (without .md): " new_name
        if [[ -n "$new_name" ]]; then
            new_name="${new_name%.md}.md"
            cat > "$PROMPTS_DIR/$new_name" << 'PROMPT_EOF'
---
tags: []
created: $(date +%Y-%m-%d)
---
# New Prompt

Describe what you want Claude to do...
PROMPT_EOF
            vim "$PROMPTS_DIR/$new_name"
            ccloop_load_prompt "$PROMPTS_DIR/$new_name"
            tmux display-message "Created and loaded: $new_name"
        fi
        ;;
    q|Q)
        exit 0
        ;;
    [0-9]*)
        idx=$((choice - 1))
        if [[ $idx -ge 0 && $idx -lt ${#prompt_files[@]} ]]; then
            ccloop_load_prompt "${prompt_files[$idx]}"
            tmux display-message "Loaded: ${prompt_names[$idx]}"
        fi
        ;;
esac
SELECT_SCRIPT
chmod +x /tmp/ccloop-select.sh

# Add tmux key binding to edit temporary prompt (Ctrl+b then e)
tmux bind-key -T prefix e run-shell "echo 'disabled' > $AUTOPROMPT_STATE; tmux new-window \"vim $AUTOPROMPT_FILE; tmux switch-client -t claude-auto\""

# Add tmux key binding to open/select prompt (Ctrl+b then o) - use standalone script
tmux bind-key -T prefix o run-shell "echo 'disabled' > $AUTOPROMPT_STATE; tmux new-window 'PROMPTS_DIR=\"$PROMPTS_DIR\" AUTOPROMPT_FILE=\"$AUTOPROMPT_FILE\" CURRENT_PROMPT_NAME=\"$CURRENT_PROMPT_NAME\" PROMPT_USAGE_FILE=\"$PROMPT_USAGE_FILE\" /tmp/ccloop-select.sh; tmux switch-client -t claude-auto'"

# Create save script
cat > /tmp/ccloop-save.sh << 'SAVE_SCRIPT'
#!/usr/bin/env bash
PROMPTS_DIR="${PROMPTS_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/ccloop/prompts}"
AUTOPROMPT_FILE="${AUTOPROMPT_FILE:-/tmp/claude-autoprompt.txt}"
CURRENT_PROMPT_NAME="${CURRENT_PROMPT_NAME:-/tmp/claude-current-prompt-name.txt}"

clear
echo "=== Save Current Prompt ==="
echo
echo "Current prompt content:"
echo "---"
head -5 "$AUTOPROMPT_FILE"
if [[ $(wc -l < "$AUTOPROMPT_FILE") -gt 5 ]]; then
    echo "..."
fi
echo "---"
echo

read -p "Save as (without .md, or press Enter to cancel): " name
if [[ -n "$name" ]]; then
    name="${name%.md}.md"
    
    # Check if file exists
    if [[ -f "$PROMPTS_DIR/$name" ]]; then
        read -p "File exists. Overwrite? (y/N): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            echo "Cancelled."
            sleep 1
            exit 0
        fi
    fi
    
    # Create with metadata
    {
        echo "---"
        echo "tags: []"
        echo "created: $(date +%Y-%m-%d)"
        echo "---"
        cat "$AUTOPROMPT_FILE"
    } > "$PROMPTS_DIR/$name"
    
    echo "$name" > "$CURRENT_PROMPT_NAME"
    echo "Saved as: $name"
    tmux display-message "Saved: $name"
    sleep 1
fi
SAVE_SCRIPT
chmod +x /tmp/ccloop-save.sh

# Add tmux key binding to save temporary prompt as new (Ctrl+b then s)
tmux bind-key -T prefix s run-shell "tmux new-window '/tmp/ccloop-save.sh; tmux switch-client -t claude-auto'"

# Add tmux key binding to toggle autoprompt (Ctrl+b then t)
tmux bind-key -T prefix t run-shell "if [ \$(cat $AUTOPROMPT_STATE) = 'enabled' ]; then echo 'disabled' > $AUTOPROMPT_STATE; tmux display-message 'Auto-prompt DISABLED'; else echo 'enabled' > $AUTOPROMPT_STATE; tmux display-message 'Auto-prompt ENABLED'; fi"

# === AUTO-PROMPT LOOP ===

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
                # Press Enter 3 times with 100ms intervals to ensure submission
                for i in {1..3}; do
                    sleep 0.1
                    tmux send-keys -t claude-auto C-m  # Use C-m for Enter/Return
                done
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