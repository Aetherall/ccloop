# ccloop - Claude Continuous Loop

An auto-prompting system for Claude CLI that keeps Claude continuously working on tasks using tmux.

## Features

- **Auto-prompting**: Automatically sends a configured prompt to Claude when idle
- **Prompt Manager**: Store and organize multiple prompts with persistence
- **Metadata support**: Prompts can have tags, creation dates, and custom fields
- **Prompt composition**: Use `@include` to compose prompts from other prompts
- **Toggle control**: Enable/disable auto-prompting with `Ctrl+b, t`
- **Temporary prompt editing**: Edit the active prompt without modifying saved versions
- **Visual status**: Status bar shows current state and all shortcuts
- **Mouse support**: Scroll through history with mouse wheel
- **Nested tmux support**: Claude can spawn its own tmux sessions
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

## Keyboard Shortcuts

- **`Ctrl+b, t`** - Toggle auto-prompt on/off (disabled by default)
- **`Ctrl+b, e`** - Edit the temporary prompt in vim
- **`Ctrl+b, o`** - Open/select a saved prompt to load
- **`Ctrl+b, s`** - Save the current temporary prompt as a new saved prompt
- **`Ctrl+b, d`** - Detach from tmux session
- **`Ctrl+c`** - Interrupt Claude

### Workflow

1. **Start ccloop** - Loads the most recently used prompt or default
2. **Edit freely** with `Ctrl+b, e` - Modify the temporary prompt without affecting saved versions
3. **Load different prompts** with `Ctrl+b, o` - Browse and select from your prompt library
4. **Save good prompts** with `Ctrl+b, s` - If you've edited something useful, save it for later
5. **Toggle auto-prompting** with `Ctrl+b, t` when ready

## Prompt Management

Prompts are stored persistently in `~/.config/ccloop/prompts/` as markdown files with YAML frontmatter.

### Prompt Format

```markdown
---
tags: [debugging, testing]
created: 2024-08-15
priority: high
---
# Main prompt content

Continue debugging the test failures in the authentication module.

@include common/context.md
```

### Features

- **Metadata support**: Add tags, dates, and custom fields in YAML frontmatter
- **Prompt composition**: Use `@include path/to/prompt.md` to include other prompts
- **Usage tracking**: Prompts are automatically sorted by most recently used
- **Temporary vs Saved**: Edit temporary prompts freely without modifying saved versions
- **Smart selection**: Numbered menu with previews and metadata display

### File Locations

- Prompts: `~/.config/ccloop/prompts/*.md`
- Usage data: `~/.config/ccloop/prompt_usage`
- Temporary prompt: `/tmp/claude-autoprompt.txt`
- Current prompt name: `/tmp/claude-current-prompt-name.txt`
- Can be customized via `XDG_CONFIG_HOME` environment variable

## How It Works

1. Starts Claude CLI in a tmux session with `TMUX` unset (allowing nested sessions)
2. Loads the most recently used prompt with metadata and include processing
3. Monitors Claude's entire screen output for idle state (no "esc to interrupt" message)
4. When idle for 5+ seconds and auto-prompt is enabled:
   - Sends the temporary prompt content
   - Presses Enter 3 times with 100ms intervals to ensure submission
5. Waits 15 seconds before checking again to let Claude work
6. All prompt edits work on the temporary copy until explicitly saved

## Status Bar

The tmux status bar displays:
- **Auto-prompt state**: ENABLED or DISABLED
- **Keyboard shortcuts**: All available commands with color coding
  - Green: Toggle (^B+t)
  - Blue: Edit (^B+e)
  - Cyan: Open (^B+o)
  - Magenta: Save (^B+s)

## Advanced Usage

### Creating Reusable Prompt Components

Create common components in subdirectories:

```markdown
# ~/.config/ccloop/prompts/common/style.md
Follow these coding standards:
- Use descriptive variable names
- Add comments for complex logic
- Keep functions under 50 lines
```

Then include them in other prompts:

```markdown
---
tags: [refactoring]
---
Refactor the current codebase.

@include common/style.md
```

### Prompt Templates with Metadata

Use metadata to organize and filter prompts:

```markdown
---
tags: [bug-fix, urgent]
created: 2024-08-15
author: yourname
success_rate: 0.85
---
# Bug Fix Protocol

1. Identify the root cause
2. Write a failing test
3. Implement the fix
4. Verify all tests pass
```

## Requirements

- `bash` 4.0+
- `tmux` 2.0+
- `vim` (for editing prompts)
- `claude` CLI (must be installed and configured)
- Standard Unix tools: `grep`, `sed`, `cut`, `tr`, `awk`

## Troubleshooting

### Prompt not loading
- Check if the prompt file exists in `~/.config/ccloop/prompts/`
- Verify metadata format (must have `---` delimiters)
- Ensure @include paths are relative to the prompts directory

### Auto-prompt not triggering
- Verify it's enabled with `Ctrl+b, t`
- Check that Claude shows as idle (no "esc to interrupt")
- Ensure the temporary prompt file is not empty

### Ctrl+b shortcuts not working
- Make sure you're attached to the tmux session
- Try detaching (`Ctrl+b, d`) and reattaching
- Check if tmux prefix key has been customized

## License

MIT