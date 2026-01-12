# ccline

A minimal, transparent status line tool for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that displays real-time context window usage.

## Why I Built This

There are a few open-source tools and repos that show context remaining and usage in Claude Code's status line. However, they typically come with bash script installers that download and execute code - which I wasn't comfortable with.

It was simpler to just give enough context to Claude Code itself to build this tool for me. This is that tool.

**No installers. No external downloads. Just a single, readable bash script.**

## What It Does

Displays your current context window usage in Claude Code's status line:

```
ctx: 45.2K/200K (22.6%) | free: 154.8K
```

The output is color-coded based on usage:
- **Green**: < 50% - Plenty of room
- **Yellow**: 50-75% - Moderate usage
- **Orange**: 75-90% - Getting full
- **Red**: >= 90% - Nearly exhausted

Colors use RGB true color escape sequences (`\033[38;2;R;G;Bm`) for consistent display regardless of terminal theme. Requires a terminal with true color support (most modern terminals).

## How It Works

The script receives JSON data from Claude Code via stdin containing context window metrics:

```json
{
  "context_window": {
    "total_input_tokens": 45200,
    "total_output_tokens": 12300,
    "context_window_size": 200000
  }
}
```

### Processing Flow

1. **Parse JSON** - Extract input tokens, output tokens, and context window size using `jq`
2. **Validate** - Check for null/empty values and apply defaults
3. **Calculate** - Compute used tokens (input + output) and percentage
4. **Format** - Convert raw numbers to human-readable format (K for thousands, M for millions)
5. **Colorize** - Apply ANSI color codes based on usage percentage
6. **Output** - Print the formatted status line

### Token Formatting

| Raw Value | Displayed As |
|-----------|--------------|
| 1,050,000 | 1.1M |
| 45,200 | 45.2K |
| 500 | 500 |

## Installation

### 1. Install Dependencies

The script requires `jq` for JSON parsing. Other tools (`bash`, `awk`, `bc`) are pre-installed on most systems.

```bash
# Ubuntu/Debian
sudo apt install jq

# macOS
brew install jq

# Fedora
sudo dnf install jq
```

Verify installation:

```bash
jq --version
```

### 2. Clone the Repository

```bash
git clone https://github.com/yourusername/ccline.git
cd ccline
```

### 3. Install the Script

Copy the script to a permanent location on your system:

```bash
mkdir -p ~/bin
cp context-statusline.sh ~/bin/
chmod +x ~/bin/context-statusline.sh
```

> **Note:** If you prefer a different location (e.g., `~/tools/ccline/`), update all paths in the configuration steps below accordingly.

### 4. Test the Script

Verify the script works by running it with sample data:

```bash
echo '{"context_window":{"total_input_tokens":45200,"total_output_tokens":12300,"context_window_size":200000}}' | ~/bin/context-statusline.sh
```

You should see output like:

```
ctx: 57.5K/200K (28.8%) | free: 142.5K
```

If you see colors, your terminal supports true color. If not, the text will still display correctly.

## Integration with Claude Code

Claude Code needs two configurations: permission to run the script, and a hook to use it as the status line.

### Option A: Using Claude Code's `/config` Command

1. Open Claude Code in your terminal
2. Type `/config` and press Enter to open the configuration interface
3. Navigate to **Permissions** and add: `Bash(~/bin/context-statusline.sh)`
4. Navigate to **Hooks** and add a `StatusLine` hook with command: `~/bin/context-statusline.sh`

### Option B: Editing Settings Files Directly

Edit `~/.claude/settings.json` (global) or `.claude/settings.local.json` (project-level) to include both configurations:

```json
{
  "permissions": {
    "allow": [
      "Bash(~/bin/context-statusline.sh)"
    ]
  },
  "hooks": {
    "StatusLine": [
      {
        "type": "command",
        "command": "~/bin/context-statusline.sh"
      }
    ]
  }
}
```

> **Note on paths:** Claude Code expands `~` to your home directory. If you encounter issues, try using the full absolute path (e.g., `/home/yourname/bin/context-statusline.sh` or `/Users/yourname/bin/context-statusline.sh` on macOS).

### Verify Integration

Restart Claude Code after configuration. You should see the context usage in the status line at the bottom of the interface. If the status line is empty, see Troubleshooting below.

## Troubleshooting

### "jq: command not found"

The `jq` JSON parser is not installed. Install it using the commands in the Installation section.

### "Permission denied"

The script is not executable. Run:

```bash
chmod +x ~/bin/context-statusline.sh
```

### Status line is empty or not showing

1. **Check the script runs manually** - Run the test command from step 4 of Installation
2. **Check permissions** - Ensure the `Bash(...)` permission matches your script path exactly
3. **Check hooks config** - Verify the `StatusLine` hook is configured correctly
4. **Restart Claude Code** - Configuration changes require a restart

### Colors not displaying

Your terminal may not support true color (24-bit color). The status line will still work, but without color coding. Most modern terminals (iTerm2, Windows Terminal, Gnome Terminal, Alacritty) support true color.

### Script works manually but not in Claude Code

Ensure the path in your config matches exactly where the script is installed. Try using an absolute path instead of `~`.

## Limitations

**This script shows lower token counts than `/context`.**

The built-in `/context` command shows the full context window usage:

| Component | Example |
|-----------|---------|
| System prompt | ~2.8k |
| System tools | ~15.4k |
| Custom agents | ~49 |
| Skills | ~67 |
| Messages | ~3.5k |
| Autocompact buffer (reserved) | ~45k |

This script only receives `total_input_tokens` and `total_output_tokens` from the JSON passed to status line hooks - which appears to be just the **conversation message tokens**, not the full context.

**Example discrepancy:**
- `/context` shows: `22K/200K (11%) | free: 133K`
- This script shows: `12.7K/200K (6.4%) | free: 187.3K`

The "free" calculation also differs because `/context` accounts for the autocompact buffer reservation (~45k tokens reserved for summarization), while this script does a simple `total - used` calculation.

**Bottom line:** Use this script for a rough indicator of conversation growth, but refer to `/context` for accurate full context usage.

## File Structure

```
ccline/
├── context-statusline.sh    # The main (and only) script
├── README.md                 # This file
├── LICENSE                   # MIT License
└── .claude/
    └── settings.local.json  # Local Claude Code permissions
```

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

Built entirely by Claude Code, for Claude Code. Designed and Reviewed by human.
