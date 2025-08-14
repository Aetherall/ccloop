# ccloop - Claude Continuous Loop

An auto-prompting system for Claude CLI that keeps Claude continuously working on tasks using tmux.

## Features

- **Auto-prompting**: Automatically sends a configured prompt to Claude when idle
- **Toggle control**: Enable/disable auto-prompting with `Ctrl+b, t`
- **Easy editing**: Edit the prompt with `Ctrl+b, e` (opens in vim)
- **Visual status**: Status bar shows current state and shortcuts
- **Mouse support**: Scroll through history with mouse wheel
- **Pass-through arguments**: All arguments are forwarded to Claude CLI

## Installation

### Using Nix Flakes

```bash
# Run directly
nix run github:yourusername/ccloop

# Install to profile
nix profile install github:yourusername/ccloop
```

### Manual Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/ccloop.git
cd ccloop

# Make script executable
chmod +x ccloop.sh

# Run the script
./ccloop.sh
```

## Usage

```bash
# Basic usage
ccloop

# With Claude CLI arguments
ccloop --model claude-3-opus-20240229
ccloop --continue
ccloop "Initial prompt"
```

### Keyboard Shortcuts

- **`Ctrl+b, t`** - Toggle auto-prompt on/off (disabled by default)
- **`Ctrl+b, e`** - Edit the auto-prompt message in vim
- **`Ctrl+b, d`** - Detach from tmux session
- **`Ctrl+c`** - Interrupt Claude

### Status Bar

The tmux status bar shows:
- Current auto-prompt state (ENABLED/DISABLED)
- Available keyboard shortcuts
- Session name

## Configuration

The auto-prompt message is stored in `/tmp/claude-autoprompt.txt` and can be edited:
1. Using the keyboard shortcut `Ctrl+b, e`
2. Directly editing the file in another terminal
3. Using echo: `echo "New prompt" > /tmp/claude-autoprompt.txt`

## How It Works

1. Starts Claude CLI in a tmux session
2. Monitors Claude's output for idle state (no "esc to interrupt" message)
3. When idle for 5+ seconds and auto-prompt is enabled, sends the configured prompt
4. Continues until you disable auto-prompting or exit

## Requirements

- `bash`
- `tmux`
- `vim` (for editing prompts)
- `claude` CLI (must be installed and configured)

## License

MIT