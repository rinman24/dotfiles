# claude — canon activation

Activates the [canon](https://github.com/rinman24/canon) Claude Code plugin
marketplace on this machine: pins the marketplace at a release tag, installs the
`canon-core` plugin, and registers a tripwire hook that warns when a project
declares canon requirements but the plugin isn't installed.

Canon adoption has two layers: each consuming repo commits a **declaration**
(a `.claude/settings.json` pin plus a `.claude/canon.txt` module list) that
states which rules at what version, but deliberately cannot self-install
anything. **Activation** — actually installing the marketplace and plugin so
the rules run — happens once per machine, and this module is that step.

## Files

- `settings-fragment.json` — dotfiles-owned source of truth for the pin
  (`ref: v1.0.0`, `autoUpdate: false`) and the tripwire hook registration.
- `install.sh` — deep-merges the fragment into `~/.claude/settings.json` with
  `jq` (surgically — Claude Code owns that file, so it is never symlinked or
  overwritten whole), then runs the idempotent activation commands. Skips
  quietly on machines without `claude`; safe to re-run (byte-identical
  settings, CLI commands no-op).
- `canon-tripwire.sh` — user-level SessionStart hook; warn-only, always exits 0.

Pin semantics, as verified on this machine (macOS, 2026-07-13):

- `install.sh` merges the fragment *before* running the CLI; `claude plugin
  marketplace add` then reuses the already-declared entry ("declared in user
  settings") instead of writing its own unpinned one, so the declared `ref` and
  `autoUpdate: false` stay authoritative in `~/.claude/settings.json`.
- `marketplace add` cannot be skipped: `claude plugin install` alone fails when
  the marketplace has never been materialized on disk.
- CLI caveat: the on-disk catalog clone (`~/.claude/plugins/marketplaces/canon`)
  tracks canon's default branch rather than checking out the pinned tag — there
  is no `--ref` flag, and the docs leave ref application unspecified. What
  actually prevents drift is `autoUpdate: false`: nothing refreshes the
  marketplace or plugin except a deliberate re-run of `install.sh` (or
  `claude plugin marketplace update canon`).
- Also note `claude plugin uninstall` / `marketplace remove` delete the
  `enabledPlugins` / `extraKnownMarketplaces` blocks from settings — re-running
  `install.sh` restores them.

## Bumping the pin

Renovate watches `settings-fragment.json` (see the repo-root `renovate.json`)
and PRs new canon tags. To bump manually: edit the `ref` in
`settings-fragment.json`, re-run `claude/install.sh`, restart Claude Code.
