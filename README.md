# dotfiles

Personal configuration for my Mac, managed by [chezmoi](https://chezmoi.io).
The repo root is the chezmoi source tree.

## Setup

Prerequisite: [Homebrew](https://brew.sh).

```bash
brew install chezmoi
git clone git@github.com:rinman24/dotfiles.git ~/Code/dotfiles
chezmoi init --apply --source ~/Code/dotfiles
```

`.chezmoi.toml.tmpl` renders `~/.config/chezmoi/chezmoi.toml` with `sourceDir`
set to the clone, so `~/Code/dotfiles` is the only copy and every later chezmoi
command uses it. Repo-local git config (e.g. `user.email`) set in that clone
therefore applies to commits made via `chezmoi cd`.

Thereafter:

```bash
chezmoi diff     # preview what apply would change
chezmoi update   # pull + apply
chezmoi cd       # jump into the source tree to edit, commit and push
```

## What's managed

| Source | Target | Notes |
|---|---|---|
| `dot_zshrc` | `~/.zshrc` | Fully managed. `yolo` = `claude --dangerously-skip-permissions` |
| `dot_config/ghostty/config.ghostty` | `~/.config/ghostty/config.ghostty` | Built-in Catppuccin themes (Latte light, Mocha dark), JetBrains Mono 15 |
| `private_dot_claude/executable_statusline.sh` | `~/.claude/statusline.sh` | Claude Code status line, small (2 lines) or medium (4 lines): model · effort, thinking, output style, cost, folder, branch, worktree, context tokens, 5H/7D usage |
| `private_dot_claude/modify_settings.json` | `~/.claude/settings.json` | Partially managed: sets only `statusLine`; Claude Code owns every other key |

`.chezmoi.toml.tmpl` and `.chezmoiignore` are chezmoi's own files, not
targets; the latter keeps this README out of `$HOME`. `~/.zprofile` (Homebrew's
`shellenv`) and all git configuration (identity, signing) are deliberately left
unmanaged for per-machine setup.

## Claude Code status line

`~/.claude/settings.json` is rewritten by Claude Code itself (`/config`,
plugins, model settings) and holds machine-specific paths, so chezmoi never
owns it wholesale. `modify_settings.json` is a
[modify script](https://www.chezmoi.io/user-guide/manage-different-types-of-file/#manage-part-but-not-all-of-a-file):
it pipes the live file through `jq` and sets only `statusLine`.

The layout comes in two sizes, after
[AwesomeZun/CC-statusline](https://github.com/AwesomeZun/CC-statusline)'s small
and medium presets. `small` (the default) fits on two lines; `medium` spreads
the same segments over four. Pick one per machine
with a state file, or per session with an environment variable, which wins.
The state file is re-read on every refresh, so no restart, and is deliberately
unmanaged: a toggle is machine state, not drift for `chezmoi apply` to revert.

```bash
echo medium > ~/.claude/statusline-size        # or small; rm for the default
CLAUDE_STATUSLINE_SIZE=small claude            # this session only
```

Every bar is drawn upstream-style: whole `█` cells, each colored by its own
position along a gradient, on a `░` track colored at the current value. Some
fonts draw `░` as dots, others as a flat block; for dots in any font, switch
the track to braille `⣿` the same way as the size:

```bash
echo dots > ~/.claude/statusline-track         # rm for ░
CLAUDE_STATUSLINE_TRACK=dots claude            # this session only
```

All colors are Catppuccin Mocha. The context bar spans 0–200k tokens whatever
the window size, with its gradient anchored at absolute thresholds: green,
yellow at 95k, red from 120k, and 🚨 in place of 🪣 at 200k. 5H runs teal →
sapphire → mauve → red and 7D rosewater → peach → red. Claude Code sends
`rate_limits` only on Pro/Max and only after the first response; until then
both bars show empty with `--%`, at the same size they'll have once data
arrives.

Bar widths adapt. Each bar line (small's line 2; medium's context and usage
rows) is as wide as line 1, capped at `$COLUMNS`. Bars sharing a line get equal
cell counts, and any leftover columns pad the numbers. No bar gets fewer than
10 cells, so a short line 1 gives bar lines a little wider than it. Numbers are
fixed-width (`  5%`, `(0h05m)`, `  45k/200k`), so bars resize only when line 1
does, for example when the cost gains a digit or the branch changes.

To iterate on the script before committing, run a throwaway session from the
clone (or a worktree of it) pointed at the working copy. `--settings` overrides
the user setting for that session only, and script edits appear on the next
status line refresh without a restart:

```bash
claude --settings "{\"statusLine\":{\"type\":\"command\",\"command\":\"$PWD/private_dot_claude/executable_statusline.sh\"}}"
```

Or render it without a session:

```bash
echo '{"model":{"display_name":"Opus"},"effort":{"level":"high"},"workspace":{"current_dir":"'"$PWD"'"},"context_window":{"total_input_tokens":45000,"context_window_size":200000,"used_percentage":22},"cost":{"total_cost_usd":0.42},"rate_limits":{"five_hour":{"used_percentage":42,"resets_at":'"$(( $(date +%s) + 8100 ))"'},"seven_day":{"used_percentage":18,"resets_at":'"$(( $(date +%s) + 300000 ))"'}}}' \
  | CLAUDE_STATUSLINE_SIZE=medium private_dot_claude/executable_statusline.sh
```

## History

Before the 2026-10 cleanup this repo also provisioned billet devcontainers
(rc-file patching, Claude Code settings and plugins, the board agents, tmux) and
managed git identity, including the GenShift work-address override.
That state is preserved on the `archive/pre-cleanup-2026-10-06` branch for
reference.
