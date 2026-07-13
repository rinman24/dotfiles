#!/usr/bin/env bash
# Canon activation for this machine: merge the pinned marketplace declaration
# (plus the tripwire hook) into ~/.claude/settings.json, then install the
# canon-core plugin. Idempotent — safe to re-run. See claude/README.md.
set -euo pipefail

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAGMENT="$MODULE_DIR/settings-fragment.json"
SETTINGS_DIR="$HOME/.claude"
SETTINGS="$SETTINGS_DIR/settings.json"

# No Claude Code on this machine: nothing to activate.
if ! command -v claude >/dev/null 2>&1; then
  echo "claude/install.sh: 'claude' not on PATH; skipping canon activation."
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "claude/install.sh: 'jq' is required to merge $FRAGMENT into $SETTINGS." >&2
  echo "Install jq (e.g. 'brew install jq') and re-run." >&2
  exit 1
fi

# Surgical deep-merge of the fragment into user settings. Claude Code itself
# writes keys into ~/.claude/settings.json (e.g. enabledPlugins), so this file
# is never symlinked or overwritten whole — the fragment is merged in, with
# fragment values winning on conflict. Temp file + mv so a failed merge can't
# truncate live settings.
mkdir -p "$SETTINGS_DIR"
[ -f "$SETTINGS" ] || printf '{}\n' >"$SETTINGS"

tmp="$(mktemp "$SETTINGS_DIR/settings.json.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
jq -s '.[0] * .[1]' "$SETTINGS" "$FRAGMENT" >"$tmp"
mv "$tmp" "$SETTINGS"
trap - EXIT
echo "Merged canon pin + tripwire hook into $SETTINGS."

# Activation commands — idempotent, no-op once installed. Run after the merge
# so the declared extraKnownMarketplaces pin (ref + autoUpdate) is in place
# before the CLI touches the marketplace.
claude plugin marketplace add rinman24/canon --scope user
claude plugin install canon-core@canon --scope user

echo
echo "Canon activation complete. Restart Claude Code — SessionStart hooks"
echo "register at process startup only (not on /clear)."
