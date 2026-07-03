#!/usr/bin/env bash
# Declare the personal Claude Code plugin marketplace (rinman24/claude-skills)
# and enable its plugins at user scope, by merging a fragment into
# ~/.claude/settings.json. Purely declarative — no network here; Claude Code
# clones the marketplace and installs the plugins itself on next session start.
# Idempotent: re-running converges on the same settings. Manual overrides
# survive: an existing enabledPlugins entry (e.g. one you set to false) wins
# over the default declared here.
set -euo pipefail

MARKETPLACE_NAME="my-skills"   # must match "name" in claude-skills' .claude-plugin/marketplace.json
MARKETPLACE_REPO="rinman24/claude-skills"
PLUGINS=(handoff local-backlog)

SETTINGS_FILE="$HOME/.claude/settings.json"

if ! command -v jq >/dev/null 2>&1; then
  echo "install-plugins: jq not found; skipping Claude plugin setup" >&2
  exit 1
fi

mkdir -p "$(dirname "$SETTINGS_FILE")"
[ -s "$SETTINGS_FILE" ] || echo '{}' >"$SETTINGS_FILE"

enabled_json="$(printf '%s\n' "${PLUGINS[@]}" \
  | jq -Rn --arg m "$MARKETPLACE_NAME" '[inputs | {key: "\(.)@\($m)", value: true}] | from_entries')"

# Same-directory temp file so the final mv is atomic on the ~/.claude volume.
tmp="$SETTINGS_FILE.tmp.$$"
jq --arg name "$MARKETPLACE_NAME" --arg repo "$MARKETPLACE_REPO" --argjson enabled "$enabled_json" '
  .extraKnownMarketplaces[$name] = {source: {source: "github", repo: $repo}}
  | .enabledPlugins = ($enabled + (.enabledPlugins // {}))
' "$SETTINGS_FILE" >"$tmp"
mv "$tmp" "$SETTINGS_FILE"

echo "install-plugins: declared marketplace $MARKETPLACE_NAME (${MARKETPLACE_REPO}) with plugins: ${PLUGINS[*]}"
