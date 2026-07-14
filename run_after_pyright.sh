#!/bin/bash
# Ensures pyright-langserver is on PATH (Claude Code's pyright-lsp plugin has no
# path setting). Plain run_ prefix: executes on every `chezmoi apply`, so a
# container that gains npm later gets picked up on the next start; the guard makes
# the common case a fast no-op. (run_onchange_ would be wrong here — it re-runs
# only when THIS FILE changes, so it would never retry after a skipped install.)
set -euo pipefail
command -v pyright-langserver >/dev/null 2>&1 && exit 0
if command -v npm >/dev/null 2>&1; then
  echo "chezmoi: installing pyright (provides pyright-langserver)"
  # Non-fatal: code intelligence is a convenience and must never brick a
  # workspace bootstrap. npm -g fails when the global prefix isn't user-writable
  # (e.g. a root-owned /usr/local, or a non-root container user) — warn and move on.
  npm install -g pyright \
    || echo "chezmoi: 'npm install -g pyright' failed (non-fatal) — install pyright-langserver another way (on macOS: 'brew install pyright'; in an image: bake it into the Dockerfile)" >&2
else
  echo "chezmoi: pyright-langserver missing and npm unavailable — bake 'npm install -g pyright' into the image" >&2
fi
