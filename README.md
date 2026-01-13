# ccline

A minimal, transparent status line tool for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that displays real-time context window usage.

## Why I Built This

There are a few open-source tools and repos that show context remaining and usage in Claude Code's status line. However, they typically come with bash script installers that download and execute code - which I wasn't comfortable with.

It was simpler to just give enough context to Claude Code itself to build this tool for me. This is that tool.

**No installers. No external downloads. Just a single, readable bash script.**

But what if you don't trust *me* either? Fair. Check out [SPEC.md](SPEC.md) - it's a plain-English specification of exactly what this tool does. Read it, copy it into your project folder, and ask Claude to build it for you. English is the new programming language anyway (Conditions apply).

## What It Does

Displays your current context window usage in Claude Code's status line using a **redaction visualization**:

```
Opus 4.5 | CONTEXT WINDOW (90%) | $0.05 | user/project
```

As context fills up, the text "CONTEXT WINDOW" progressively gets censored:

| Usage | Display |
|-------|---------|
| < 20% | `CONTEXT WINDOW (85%)` |
| 20-39% | `CONTEXT ██████ (65%)` |
| 40-59% | `████EXT ██████ (45%)` |
| 60-79% | `████████ █████ (25%)` |
| >= 80% | `██████████████ (10%)` |

The percentage shows **remaining** context, not used. The output is color-coded:
- **Green**: < 50% used - Plenty of room
- **Yellow**: 50-75% used - Moderate usage
- **Orange**: 75-90% used - Getting full
- **Red**: >= 90% used - Nearly exhausted

Colors use RGB true color escape sequences (`\033[38;2;R;G;Bm`) for consistent display regardless of terminal theme. Requires a terminal with true color support (most modern terminals).

## How It Works

The script receives JSON data from Claude Code via stdin containing session metrics:

```json
{
  "context_window": {
    "used_percentage": 24,
    "remaining_percentage": 76,
    "context_window_size": 200000
  },
  "model": {
    "display_name": "Opus 4.5"
  },
  "cost": {
    "total_cost_usd": 0.05
  },
  "cwd": "/home/user/project"
}
```

### Processing Flow

1. **Parse JSON** - Extract percentage fields, model, cost, and cwd using `jq`
2. **Validate** - Check for null/empty values and apply defaults
3. **Get percentage** - Use `used_percentage` and `remaining_percentage` directly (Claude Code 2.1.6+), or fall back to token calculation for older versions
4. **Redact** - Generate redaction visualization based on usage percentage
5. **Colorize** - Apply ANSI color codes based on usage percentage
6. **Output** - Print the formatted status line

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
echo '{"context_window":{"used_percentage":15,"remaining_percentage":85,"context_window_size":200000},"model":{"display_name":"Opus 4.5"},"cost":{"total_cost_usd":0.05},"cwd":"/home/user/project"}' | ~/bin/context-statusline.sh
```

You should see output like:

```
Opus 4.5 | CONTEXT WINDOW (85%) | $0.05 | user/project
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

### Claude Code 2.1.6+ (Recommended)

With Claude Code 2.1.6 and later, the script uses `used_percentage` and `remaining_percentage` fields that provide **accurate context usage** matching the built-in `/context` command. No limitations in this mode.

### Claude Code < 2.1.6 (Fallback Mode)

For older versions of Claude Code, the script falls back to token-based calculation using `total_input_tokens` and `total_output_tokens`. This fallback has limitations:

- Token counts are cumulative session totals, not current context contents
- Does not account for system prompt, tool definitions, or autocompact buffer
- May show different percentages than `/context`

**Recommendation:** Update to Claude Code 2.1.6+ for accurate context usage display.

## File Structure

```
ccline/
├── context-statusline.sh    # The main (and only) script
├── README.md                 # This file
├── SPEC.md                   # Technical specification for reimplementation
├── CHANGELOG.md             # Version history
├── LICENSE                   # MIT License
└── .claude/
    └── settings.local.json  # Local Claude Code permissions
```

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

Built entirely by Claude Code, for Claude Code. Designed and Reviewed by human.
