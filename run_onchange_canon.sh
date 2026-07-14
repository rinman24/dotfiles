#!/bin/bash
# Canon activation (CLI half) — belt-and-braces. The PRIMARY mechanism is the
# declarative marketplace pin + enabledPlugins placed by
# private_dot_claude/modify_settings.json; Claude Code fetches canon-core from
# that declaration on session start, exactly as it does for the my-skills plugins
# (which never needed a CLI step). These calls just make the install immediate on
# a fresh machine.
#
# run_onchange_ (NOT run_after_): the `claude plugin` commands re-serialize
# ~/.claude/settings.json in Claude Code's key order, which differs from the
# modify-template's sorted output. Running them on EVERY apply would rewrite
# settings.json on every `billet start` (perpetual churn). run_onchange_ runs this
# once per machine per script-version, so settings.json converges.
#
# Idempotent and deliberately non-fatal: a workspace bootstrap must never brick
# on plugin setup.
set -uo pipefail
command -v claude >/dev/null 2>&1 || {
  echo "chezmoi: claude not on PATH; skipping canon activation (declaration still applied)"
  exit 0
}
claude plugin marketplace add rinman24/canon --scope user \
  || echo "chezmoi: 'claude plugin marketplace add' failed (non-fatal)" >&2
claude plugin install canon-core@canon --scope user \
  || echo "chezmoi: 'claude plugin install canon-core' failed (non-fatal)" >&2
