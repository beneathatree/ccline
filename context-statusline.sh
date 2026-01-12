#!/bin/bash
# Claude Code Statusline - Context Usage Display
# Shows: used tokens / available tokens (percentage)

# Read JSON from stdin (passed by Claude Code)
INPUT=$(cat)

# Parse context window data using jq
TOTAL_INPUT=$(echo "$INPUT" | jq -r '.context_window.total_input_tokens // 0' 2>/dev/null)
TOTAL_OUTPUT=$(echo "$INPUT" | jq -r '.context_window.total_output_tokens // 0' 2>/dev/null)
CONTEXT_SIZE=$(echo "$INPUT" | jq -r '.context_window.context_window_size // 200000' 2>/dev/null)

# Ensure we have valid numbers
TOTAL_INPUT=${TOTAL_INPUT:-0}
TOTAL_OUTPUT=${TOTAL_OUTPUT:-0}
CONTEXT_SIZE=${CONTEXT_SIZE:-200000}

# Handle null or empty values
[[ "$TOTAL_INPUT" == "null" || -z "$TOTAL_INPUT" ]] && TOTAL_INPUT=0
[[ "$TOTAL_OUTPUT" == "null" || -z "$TOTAL_OUTPUT" ]] && TOTAL_OUTPUT=0
[[ "$CONTEXT_SIZE" == "null" || -z "$CONTEXT_SIZE" || "$CONTEXT_SIZE" == "0" ]] && CONTEXT_SIZE=200000

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
printf "%sctx: %s/%s (%s%%) | free: %s%s\n" "$COLOR" "$USED_FMT" "$SIZE_FMT" "$PERCENTAGE" "$FREE_FMT" "$RESET"
