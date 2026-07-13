#!/usr/bin/env bash
# User-level SessionStart tripwire: if the current project declares canon
# requirements (.claude/canon.txt) but the canon-core plugin is not enabled in
# user settings, print a loud warning to stdout (which Claude Code injects as
# session context). Warn-only — SessionStart hooks cannot block. Always exits
# 0; never fatal, never slow, no network.
#
# CANON_TRIPWIRE_SETTINGS overrides the settings path (used by tests).
set -u

project_dir="${CLAUDE_PROJECT_DIR:-$PWD}"
settings="${CANON_TRIPWIRE_SETTINGS:-$HOME/.claude/settings.json}"

# Project declares nothing: stay silent.
[ -f "$project_dir/.claude/canon.txt" ] || exit 0

# Missing jq or settings file means "unknown", not failure: stay silent.
command -v jq >/dev/null 2>&1 || exit 0
[ -f "$settings" ] || exit 0

if jq -e '.enabledPlugins."canon-core@canon" == true' "$settings" >/dev/null 2>&1; then
  exit 0
fi

cat <<'EOF'
================================================================================
CANON TRIPWIRE — canon rules are NOT active in this session.

This project declares canon requirements (.claude/canon.txt), but the
canon-core plugin is not enabled in ~/.claude/settings.json, so its
engineering rules are not being injected.

Fix (one-time per machine):

    ~/Code/dotfiles/claude/install.sh

then restart Claude Code.
================================================================================
EOF
exit 0
