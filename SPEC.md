# ccline Specification

This document specifies the behavior of the ccline status line tool. Use this to build your own implementation in any language.

## Overview

ccline is a status line hook for Claude Code that displays real-time context window usage. Claude Code invokes the script and pipes JSON data to stdin. The script outputs a formatted, color-coded status string to stdout.

## Input

Claude Code pipes JSON to stdin with the following structure:

```json
{
  "context_window": {
    "total_input_tokens": <integer>,
    "total_output_tokens": <integer>,
    "context_window_size": <integer>
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `total_input_tokens` | integer | Tokens used by input/prompts |
| `total_output_tokens` | integer | Tokens used by model responses |
| `context_window_size` | integer | Maximum context window capacity |

### Input Validation

Handle missing, null, or invalid values with these defaults:

| Field | Default |
|-------|---------|
| `total_input_tokens` | `0` |
| `total_output_tokens` | `0` |
| `context_window_size` | `200000` |

If `context_window_size` is `0`, treat it as `200000` to avoid division by zero.

## Output

Print a single line to stdout in this format:

```
ctx: <used>/<total> (<percentage>%) | free: <free>
```

Example:
```
ctx: 45.2K/200K (22.6%) | free: 154.8K
```

### Calculations

```
used = total_input_tokens + total_output_tokens
free = context_window_size - used
percentage = (used / context_window_size) * 100
```

### Number Formatting

Format token counts for readability:

| Condition | Format | Example |
|-----------|--------|---------|
| `>= 1,000,000` | `X.XM` | `1050000` → `1.1M` |
| `>= 1,000` | `X.XK` | `45200` → `45.2K` |
| `< 1,000` | raw number | `500` → `500` |

Use one decimal place for K/M suffixes. Round to nearest tenth.

## Color Coding

Apply ANSI color codes based on usage percentage:

| Percentage | Color | RGB Values | ANSI Code |
|------------|-------|------------|-----------|
| `< 50%` | Green | (0, 200, 0) | `\033[38;2;0;200;0m` |
| `50% - 74.9%` | Yellow | (255, 200, 0) | `\033[38;2;255;200;0m` |
| `75% - 89.9%` | Orange | (255, 130, 0) | `\033[38;2;255;130;0m` |
| `>= 90%` | Red | (255, 50, 50) | `\033[38;2;255;50;50m` |

### Color Application

1. Prepend the appropriate color escape sequence to the output
2. Append reset sequence `\033[0m` at the end
3. Use RGB true color format (`\033[38;2;R;G;Bm`) for terminal-theme-independent colors

### Output with Color

```
<COLOR_CODE>ctx: <used>/<total> (<percentage>%) | free: <free><RESET_CODE>
```

## Integration

### Claude Code Hook Configuration

The tool integrates via Claude Code's `StatusLine` hook:

```json
{
  "hooks": {
    "StatusLine": [
      {
        "type": "command",
        "command": "/path/to/script"
      }
    ]
  }
}
```

### Execution Flow

1. Claude Code spawns the script as a subprocess
2. Claude Code writes JSON to script's stdin
3. Script reads stdin, processes data, writes to stdout
4. Claude Code displays stdout content in status line
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

### Basic Usage

Input:
```json
{"context_window":{"total_input_tokens":45200,"total_output_tokens":12300,"context_window_size":200000}}
```

Expected output (without color codes):
```
ctx: 57.5K/200K (28.8%) | free: 142.5K
```

Color: Green (28.8% < 50%)

### High Usage

Input:
```json
{"context_window":{"total_input_tokens":150000,"total_output_tokens":35000,"context_window_size":200000}}
```

Expected output:
```
ctx: 185K/200K (92.5%) | free: 15K
```

Color: Red (92.5% >= 90%)

### Null Values

Input:
```json
{"context_window":{"total_input_tokens":null,"total_output_tokens":null,"context_window_size":null}}
```

Expected output:
```
ctx: 0/200K (0.0%) | free: 200K
```

Color: Green (0% < 50%)

### Million-Scale Tokens

Input:
```json
{"context_window":{"total_input_tokens":500000,"total_output_tokens":550000,"context_window_size":2000000}}
```

Expected output:
```
ctx: 1.1M/2M (52.5%) | free: 950K
```

Color: Yellow (52.5% >= 50%, < 75%)

### Empty Input

Input: (empty string or invalid JSON)

Expected output:
```
ctx: 0/200K (0.0%) | free: 200K
```

Color: Green
