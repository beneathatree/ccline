# Changelog

All notable changes to ccline.

## 2026-01-13

### Changed
- **Remove transcript from output** - Cleaner UI with just model, context, cost, and cwd
- **Use percentage fields from Claude Code 2.1.6+** - Now uses `used_percentage` and `remaining_percentage` fields for accurate context usage, with fallback to token-based calculation for older versions

### Added
- **Redaction visualization** - Context usage now shown as progressively censored "CONTEXT WINDOW" text
- **CLAUDE.md** - Project context file for development assistance

## 2026-01-12

### Added
- **Model, cost, cwd display** - Show model name, session cost, and working directory
- **SPEC.md** - Technical specification for reimplementing in other languages
- **Initial release** - Basic context window status line with color-coded usage
