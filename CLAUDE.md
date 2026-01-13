# CLAUDE.md

## Project Overview

ccline is a bash statusline script for Claude Code that displays context usage via a "redaction" visualization. The text "CONTEXT WINDOW" progressively gets censored as context fills up.

## Key Files

- `context-statusline.sh` - The entire implementation (single file)
- `SPEC.md` - Technical specification for reimplementation in other languages
- `README.md` - User documentation and installation guide

## Testing

Test the script by piping JSON to stdin:

```bash
# Low usage (10%) - should show "CONTEXT WINDOW (90%)" in green
echo '{"context_window":{"total_input_tokens":10000,"total_output_tokens":10000,"context_window_size":200000},"model":{"display_name":"Opus 4.5"},"cost":{"total_cost_usd":0.05},"cwd":"/home/user/project","transcript_path":"/tmp/transcript.jsonl"}' | ./context-statusline.sh

# High usage (90%) - should show "██████████████ (10%)" in red
echo '{"context_window":{"total_input_tokens":90000,"total_output_tokens":90000,"context_window_size":200000},"model":{"display_name":"Opus 4.5"},"cost":{"total_cost_usd":0.50},"cwd":"/home/user/project","transcript_path":"/tmp/transcript.jsonl"}' | ./context-statusline.sh

# Empty input - should show defaults gracefully
echo '{}' | ./context-statusline.sh
```

## Redaction Thresholds

| Usage | Display |
|-------|---------|
| < 20% | `CONTEXT WINDOW` |
| 20-39% | `CONTEXT ██████` |
| 40-59% | `████EXT ██████` |
| 60-79% | `████████ █████` |
| >= 80% | `██████████████` |

## Color Thresholds

| Usage | Color |
|-------|-------|
| < 50% | Green |
| 50-74% | Yellow |
| 75-89% | Orange |
| >= 90% | Red |

## Output Format

```
<model> | <redaction> (<remaining>%) | <cost> | <cwd> | <transcript>
```

## Dependencies

- `jq` - JSON parsing
- `awk` - Float formatting
- `bc` - Float comparison

## Common Changes

**Adjust redaction thresholds**: Edit the `redaction_viz()` function in `context-statusline.sh`

**Adjust color thresholds**: Edit the percentage checks near `COLOR=` assignments

**Change output format**: Edit the final `printf` statement

## Keep In Sync

When modifying behavior, update all three:
1. `context-statusline.sh` - Implementation
2. `SPEC.md` - Technical spec (test cases especially)
3. `README.md` - User-facing docs
