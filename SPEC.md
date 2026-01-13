# ccline Specification

This document specifies the behavior of the ccline status line tool. Use this to build your own implementation in any language.

## Overview

ccline is a status line hook for Claude Code that displays real-time session information including model name, context window usage, cost, working directory, and transcript location. Claude Code invokes the script and pipes JSON data to stdin. The script outputs a formatted, color-coded status string to stdout.

The context usage is displayed using a **redaction visualization** where the text "CONTEXT WINDOW" progressively gets censored as context fills up, providing an intuitive visual indicator of remaining capacity.

## Input

Claude Code pipes JSON to stdin with the following structure:

```json
{
  "hook_event_name": "Status",
  "session_id": "<string>",
  "transcript_path": "<string>",
  "cwd": "<string>",
  "version": "<string>",
  "output_style": "<string>",
  "model": {
    "id": "<string>",
    "display_name": "<string>"
  },
  "workspace": {
    "current_dir": "<string>",
    "project_dir": "<string>"
  },
  "context_window": {
    "total_input_tokens": "<integer>",
    "total_output_tokens": "<integer>",
    "context_window_size": "<integer>"
  },
  "cost": {
    "total_cost_usd": "<float>",
    "total_duration_ms": "<integer>",
    "total_api_duration_ms": "<integer>",
    "total_lines_added": "<integer>",
    "total_lines_removed": "<integer>"
  }
}
```

### Field Reference

#### Root Fields

| Field | Type | Description |
|-------|------|-------------|
| `hook_event_name` | string | Event type, always `"Status"` for statusline |
| `session_id` | string | Unique identifier for the current session |
| `transcript_path` | string | Absolute path to the conversation transcript JSON file |
| `cwd` | string | Current working directory |
| `version` | string | Claude Code version (e.g., `"1.0.80"`) |
| `output_style` | string | Output formatting preference |

#### `model` Object

| Field | Type | Description |
|-------|------|-------------|
| `model.id` | string | Full model identifier (e.g., `"claude-opus-4-5-20251101"`) |
| `model.display_name` | string | Short display name (e.g., `"Opus"`, `"Sonnet"`) |

#### `workspace` Object

| Field | Type | Description |
|-------|------|-------------|
| `workspace.current_dir` | string | Current working directory |
| `workspace.project_dir` | string | Original project root directory |

#### `context_window` Object

| Field | Type | Description |
|-------|------|-------------|
| `context_window.total_input_tokens` | integer | Tokens used by input/prompts |
| `context_window.total_output_tokens` | integer | Tokens used by model responses |
| `context_window.context_window_size` | integer | Maximum context window capacity |

#### `cost` Object

| Field | Type | Description |
|-------|------|-------------|
| `cost.total_cost_usd` | float | Total session cost in USD |
| `cost.total_duration_ms` | integer | Total session duration in milliseconds |
| `cost.total_api_duration_ms` | integer | Time spent in API calls in milliseconds |
| `cost.total_lines_added` | integer | Total lines of code added in session |
| `cost.total_lines_removed` | integer | Total lines of code removed in session |

### Input Validation

Handle missing, null, or invalid values with these defaults:

| Field | Default |
|-------|---------|
| `total_input_tokens` | `0` |
| `total_output_tokens` | `0` |
| `context_window_size` | `200000` |
| `model.display_name` | `"Unknown"` |
| `cost.total_cost_usd` | `0` |
| `cwd` | `""` (display as `"N/A"`) |
| `transcript_path` | `""` |

If `context_window_size` is `0`, treat it as `200000` to avoid division by zero.

## Output

Print a single line to stdout in this format:

```
<model> | <redaction> (<remaining>%) | <cost> | <cwd> | <transcript>
```

Example:
```
Opus | CONTEXT ██████ (71%) | $0.05 | projects/ccline | /home/user/.claude/sessions/abc123.json
```

### Calculations

```
used = total_input_tokens + total_output_tokens
percentage = (used / context_window_size) * 100
remaining = 100 - percentage
```

### Redaction Visualization

The context display uses a "redaction" metaphor where the text "CONTEXT WINDOW" progressively gets censored as context fills up:

| Usage | Display |
|-------|---------|
| `< 20%` | `CONTEXT WINDOW` |
| `20% - 39%` | `CONTEXT ██████` |
| `40% - 59%` | `████EXT ██████` |
| `60% - 79%` | `████████ █████` |
| `>= 80%` | `██████████████` |

The parenthetical shows the **remaining** percentage (not used), providing an at-a-glance indicator of available capacity.

### Number Formatting

#### Token Counts

| Condition | Format | Example |
|-----------|--------|---------|
| `>= 1,000,000` | `X.XM` | `1050000` → `1.1M` |
| `>= 1,000` | `X.XK` | `45200` → `45.2K` |
| `< 1,000` | raw number | `500` → `500` |

Use one decimal place for K/M suffixes. Round to nearest tenth.

#### Cost

| Condition | Format | Example |
|-----------|--------|---------|
| `>= $0.01` | `$X.XX` | `0.0523` → `$0.05` |
| `< $0.01` | `$X.XXXX` | `0.003` → `$0.0030` |

#### Working Directory

Shorten to last 2 path components for readability:
- `/home/user/dev/projects/myapp` → `projects/myapp`
- `/home/user` → `home/user`

## Color Coding

Apply ANSI color codes based on context usage percentage:

| Percentage | Color | RGB Values | ANSI Code |
|------------|-------|------------|-----------|
| `< 50%` | Green | (0, 200, 0) | `\033[38;2;0;200;0m` |
| `50% - 74.9%` | Yellow | (255, 200, 0) | `\033[38;2;255;200;0m` |
| `75% - 89.9%` | Orange | (255, 130, 0) | `\033[38;2;255;130;0m` |
| `>= 90%` | Red | (255, 50, 50) | `\033[38;2;255;50;50m` |

### Additional Colors

| Element | Color | RGB Values | ANSI Code |
|---------|-------|------------|-----------|
| Model name | Cyan | (100, 200, 255) | `\033[38;2;100;200;255m` |
| CWD, Transcript | Dim | N/A | `\033[2m` |

### Color Application

1. Apply cyan to model name
2. Apply usage-based color to context section
3. Apply dim to cwd and transcript path
4. Append reset sequence `\033[0m` after each colored section

## Integration

### Claude Code Configuration

The tool integrates via Claude Code's `statusLine` setting in `settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "/path/to/script",
    "padding": 0
  }
}
```

**Note:** Updates run at most every 300ms.

### Execution Flow

1. Claude Code spawns the script as a subprocess
2. Claude Code writes JSON to script's stdin
3. Script reads stdin, processes data, writes to stdout
4. Claude Code displays first line of stdout in status line
5. Script exits

### Permissions

Claude Code requires explicit permission to execute the script:

```json
{
  "permissions": {
    "allow": [
      "Bash(/path/to/script)"
    ]
  }
}
```

## Known Limitations

The `total_input_tokens` and `total_output_tokens` values represent **conversation message tokens only**. They do not include:

- System prompt tokens (~2.8K)
- Tool definition tokens (~15K)
- Custom agent definitions
- Skill definitions
- Autocompact buffer reservation (~45K)

As a result, this tool shows lower usage than Claude Code's built-in `/context` command.

## Dependencies (Reference Implementation)

The bash reference implementation uses:

| Tool | Purpose |
|------|---------|
| `bash` | Script execution |
| `jq` | JSON parsing |
| `awk` | Floating-point formatting |
| `bc` | Floating-point comparison |

Alternative implementations may use any JSON parser and standard math operations.

## Test Cases

### Basic Usage (Low Context)

Input:
```json
{
  "context_window": {"total_input_tokens": 10000, "total_output_tokens": 10000, "context_window_size": 200000},
  "model": {"id": "claude-opus-4-5", "display_name": "Opus"},
  "cost": {"total_cost_usd": 0.05},
  "cwd": "/home/user/dev/projects/myapp",
  "transcript_path": "/home/user/.claude/sessions/abc123.json"
}
```

Expected output (without color codes):
```
Opus | CONTEXT WINDOW (90%) | $0.05 | projects/myapp | /home/user/.claude/sessions/abc123.json
```

Color: Green (10% used < 50%)

### Medium Usage

Input:
```json
{
  "context_window": {"total_input_tokens": 55000, "total_output_tokens": 55000, "context_window_size": 200000},
  "model": {"display_name": "Sonnet"},
  "cost": {"total_cost_usd": 0.25},
  "cwd": "/home/user/project",
  "transcript_path": "/tmp/transcript.json"
}
```

Expected output:
```
Sonnet | ████EXT ██████ (45%) | $0.25 | user/project | /tmp/transcript.json
```

Color: Yellow (55% used, 50-75% range)

### High Usage with Small Cost

Input:
```json
{
  "context_window": {"total_input_tokens": 90000, "total_output_tokens": 90000, "context_window_size": 200000},
  "model": {"display_name": "Sonnet"},
  "cost": {"total_cost_usd": 0.003},
  "cwd": "/home/user",
  "transcript_path": "/tmp/transcript.json"
}
```

Expected output:
```
Sonnet | ██████████████ (10%) | $0.0030 | home/user | /tmp/transcript.json
```

Color: Red (90% used >= 90%), cost shows 4 decimal places

### Null/Missing Values

Input:
```json
{}
```

Expected output:
```
Unknown | CONTEXT WINDOW (100%) | $0.0000 | N/A |
```

Color: Green (0% used < 50%)

### Partial Redaction

Input:
```json
{
  "context_window": {"total_input_tokens": 35000, "total_output_tokens": 35000, "context_window_size": 200000},
  "model": {"display_name": "Opus"},
  "cost": {"total_cost_usd": 0.15},
  "cwd": "/workspace/project",
  "transcript_path": "/data/sessions/session.json"
}
```

Expected output:
```
Opus | CONTEXT ██████ (65%) | $0.15 | workspace/project | /data/sessions/session.json
```

Color: Green (35% used < 50%)

## Sources & Verification

The JSON input structure documented above was compiled from the following sources:

### Official Documentation
- [Claude Code Status Line Configuration](https://code.claude.com/docs/en/statusline) - Official Anthropic documentation

### Community Implementations
These open-source projects parse the same JSON input, validating the schema:

- [ccstatusline by sirmalloc](https://github.com/sirmalloc/ccstatusline) - Customizable statusline with themes and powerline support
- [ccstatusline by syou6162](https://github.com/syou6162/ccstatusline) - YAML-configurable statusline tool
- [claude_monitor_statusline](https://github.com/gabriel-dehan/claude_monitor_statusline) - Usage monitoring statusline
- [ccusage](https://ccusage.com/guide/statusline) - Claude Code usage analysis tool

### Tutorials & Guides
- [How to Customize Your Claude Code Status Line](https://alexop.dev/posts/customize_claude_code_status_line/) - Detailed walkthrough with JSON field examples
- [Oh My Posh + Claude Code Integration](https://dev.to/jandedobbeleer/oh-my-posh-claude-code-66f) - Terminal prompt integration guide

### Verification Method

To verify the JSON structure yourself, create a debug script:

```bash
#!/bin/bash
# Save stdin to a file for inspection
cat > /tmp/claude-statusline-debug.json
cat /tmp/claude-statusline-debug.json
```

Configure this as your statusline command, then inspect `/tmp/claude-statusline-debug.json` to see the exact data Claude Code provides.
