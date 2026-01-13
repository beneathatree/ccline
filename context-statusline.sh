#!/bin/bash
# Claude Code Statusline - Context Usage Display
# Shows: model | context usage | cost | cwd | transcript path

# Read JSON from stdin (passed by Claude Code)
INPUT=$(cat)

# Parse context window data using jq
TOTAL_INPUT=$(echo "$INPUT" | jq -r '.context_window.total_input_tokens // 0' 2>/dev/null)
TOTAL_OUTPUT=$(echo "$INPUT" | jq -r '.context_window.total_output_tokens // 0' 2>/dev/null)
CONTEXT_SIZE=$(echo "$INPUT" | jq -r '.context_window.context_window_size // 200000' 2>/dev/null)

# Parse additional fields
CWD=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null)
MODEL=$(echo "$INPUT" | jq -r '.model.display_name // "Unknown"' 2>/dev/null)
COST=$(echo "$INPUT" | jq -r '.cost.total_cost_usd // 0' 2>/dev/null)
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // ""' 2>/dev/null)

# Ensure we have valid numbers
TOTAL_INPUT=${TOTAL_INPUT:-0}
TOTAL_OUTPUT=${TOTAL_OUTPUT:-0}
CONTEXT_SIZE=${CONTEXT_SIZE:-200000}

# Handle null or empty values
[[ "$TOTAL_INPUT" == "null" || -z "$TOTAL_INPUT" ]] && TOTAL_INPUT=0
[[ "$TOTAL_OUTPUT" == "null" || -z "$TOTAL_OUTPUT" ]] && TOTAL_OUTPUT=0
[[ "$CONTEXT_SIZE" == "null" || -z "$CONTEXT_SIZE" || "$CONTEXT_SIZE" == "0" ]] && CONTEXT_SIZE=200000
[[ "$CWD" == "null" ]] && CWD=""
[[ "$MODEL" == "null" || -z "$MODEL" ]] && MODEL="Unknown"
[[ "$COST" == "null" || -z "$COST" ]] && COST=0
[[ "$TRANSCRIPT" == "null" ]] && TRANSCRIPT=""

# Format cost (show as $X.XX or $X.XXXX for small amounts)
if (( $(echo "$COST < 0.01" | bc -l) )); then
    COST_FMT=$(awk "BEGIN {printf \"\$%.4f\", $COST}")
else
    COST_FMT=$(awk "BEGIN {printf \"\$%.2f\", $COST}")
fi

# Shorten cwd (show last 2 path components)
if [[ -n "$CWD" ]]; then
    CWD_SHORT=$(echo "$CWD" | awk -F/ '{if (NF>2) print $(NF-1)"/"$NF; else print $0}')
else
    CWD_SHORT="N/A"
fi

# Calculate total used tokens and percentage
USED=$((TOTAL_INPUT + TOTAL_OUTPUT))
PERCENTAGE=$(awk "BEGIN {printf \"%.1f\", ($USED / $CONTEXT_SIZE) * 100}")

# Format numbers with K suffix for readability
format_tokens() {
    local num=$1
    if [ "$num" -ge 1000000 ]; then
        awk "BEGIN {printf \"%.1fM\", $num / 1000000}"
    elif [ "$num" -ge 1000 ]; then
        awk "BEGIN {printf \"%.1fK\", $num / 1000}"
    else
        echo "$num"
    fi
}

USED_FMT=$(format_tokens $USED)
SIZE_FMT=$(format_tokens $CONTEXT_SIZE)
FREE=$((CONTEXT_SIZE - USED))
FREE_FMT=$(format_tokens $FREE)
REMAINING_PCT=$(awk "BEGIN {printf \"%.0f\", 100 - $PERCENTAGE}")

# Redaction visualization - text gets censored as context fills
redaction_viz() {
    local pct=$1
    local remaining=$2
    local pct_int=${pct%.*}  # Remove decimal

    if (( pct_int < 20 )); then
        echo "CONTEXT WINDOW ($remaining%)"
    elif (( pct_int < 40 )); then
        echo "CONTEXT ██████ ($remaining%)"
    elif (( pct_int < 60 )); then
        echo "████EXT ██████ ($remaining%)"
    elif (( pct_int < 80 )); then
        echo "████████ █████ ($remaining%)"
    else
        echo "██████████████ ($remaining%)"
    fi
}

REDACT=$(redaction_viz "$PERCENTAGE" "$REMAINING_PCT")

# Color based on usage percentage (using RGB true colors for consistent display)
GREEN=$'\033[38;2;0;200;0m'
YELLOW=$'\033[38;2;255;200;0m'
ORANGE=$'\033[38;2;255;130;0m'
RED=$'\033[38;2;255;50;50m'
RESET=$'\033[0m'

if (( $(echo "$PERCENTAGE < 50" | bc -l) )); then
    COLOR="$GREEN"
elif (( $(echo "$PERCENTAGE < 75" | bc -l) )); then
    COLOR="$YELLOW"
elif (( $(echo "$PERCENTAGE < 90" | bc -l) )); then
    COLOR="$ORANGE"
else
    COLOR="$RED"
fi

# Output the statusline
# Format: model | redaction | cost | cwd | transcript
CYAN=$'\033[38;2;100;200;255m'
DIM=$'\033[2m'
printf "%s%s%s | %s%s%s | %s | %s%s%s | %s%s%s\n" \
    "$CYAN" "$MODEL" "$RESET" \
    "$COLOR" "$REDACT" "$RESET" \
    "$COST_FMT" \
    "$DIM" "$CWD_SHORT" "$RESET" \
    "$DIM" "$TRANSCRIPT" "$RESET"
