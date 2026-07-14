#!/bin/bash
# pyright-lsp activation (CLI half) — belt-and-braces, mirrors run_onchange_canon.sh.
#
# WHY this exists (the runbook's premise was wrong): the "official marketplace is
# auto-available, so a bare enabledPlugins entry suffices" assumption does NOT hold in
# practice. Observed 2026-07-13 in a real gswa container — pyright-lsp was declared in
# settings but never installed, and `/plugin` reported:
#   Failed to load marketplace "claude-plugins-official": cache-miss
# Root cause: a persisted ~/.claude volume created in the root era (pre ADR-0005 non-root
# migration) carries a stale installLocation (/root/.claude/...) in known_marketplaces.json;
# under the current non-root HOME (/home/dev) the loader misses. canon never hit this because
# run_onchange_canon.sh re-adds its marketplace (rewriting the path). This gives pyright-lsp
# the same explicit activation: declaration declares, CLI actually installs.
#
# The `remove` self-heals that stale/corrupt entry (claude's own error prescribes
# "remove and re-add"); on a fresh volume it's a harmless no-op. `add` then registers the
# marketplace at the correct current HOME, and `install` installs the plugin (declaration
# alone does not).
#
# run_onchange_ (NOT run_after_): the `claude plugin` commands re-serialize
# ~/.claude/settings.json in Claude Code's key order, which differs from the modify-template's
# sorted output; running them every apply would churn settings.json on every `billet start`.
# run_onchange_ runs once per machine per script-version, so settings.json converges.
# Idempotent and deliberately non-fatal — a workspace bootstrap must never brick on plugin setup.
set -uo pipefail
command -v claude >/dev/null 2>&1 || {
  echo "chezmoi: claude not on PATH; skipping pyright-lsp activation (declaration still applied)"
  exit 0
}
# Self-heal a stale/root-era installLocation, then (re)register at the current HOME.
claude plugin marketplace remove claude-plugins-official >/dev/null 2>&1 || true
claude plugin marketplace add anthropics/claude-plugins-official --scope user \
  || echo "chezmoi: 'claude plugin marketplace add claude-plugins-official' failed (non-fatal)" >&2
claude plugin install pyright-lsp@claude-plugins-official --scope user \
  || echo "chezmoi: 'claude plugin install pyright-lsp' failed (non-fatal)" >&2
