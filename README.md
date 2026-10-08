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
| `.chezmoiexternal.toml` | `~/.claude/statusline.sh` | Claude Code status line, downloaded from a pinned release of [rinman24/claude-statusline](https://github.com/rinman24/claude-statusline) |
| `private_dot_claude/modify_settings.json` | `~/.claude/settings.json` | Partially managed: sets only `statusLine`; Claude Code owns every other key |

`.chezmoi.toml.tmpl`, `.chezmoiexternal.toml` and `.chezmoiignore` are
chezmoi's own files, not targets; the last keeps this README out of `$HOME`.
`~/.zprofile` (Homebrew's `shellenv`) and all git configuration (identity,
signing) are deliberately left unmanaged for per-machine setup.

## Claude Code status line

The status line lives in its own repo,
[rinman24/claude-statusline](https://github.com/rinman24/claude-statusline),
which has its docs, tests and CI. Here, `.chezmoiexternal.toml` downloads
`statusline.sh` from a pinned tag; to upgrade, bump the tag and `chezmoi apply`.

`~/.claude/settings.json` is rewritten by Claude Code itself (`/config`,
plugins, model settings) and holds machine-specific paths, so chezmoi never
owns it wholesale. `modify_settings.json` is a
[modify script](https://www.chezmoi.io/user-guide/manage-different-types-of-file/#manage-part-but-not-all-of-a-file):
it pipes the live file through `jq` and sets only `statusLine`.

The layout and track toggles (`~/.claude/statusline-size`,
`~/.claude/statusline-track`) are deliberately unmanaged: a toggle is machine
state, not drift for `chezmoi apply` to revert.

## History

Before the 2026-10 cleanup this repo also provisioned billet devcontainers
(rc-file patching, Claude Code settings and plugins, the board agents, tmux) and
managed git identity, including the GenShift work-address override.
That state is preserved on the `archive/pre-cleanup-2026-10-06` branch for
reference.
