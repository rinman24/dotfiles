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

`.chezmoi.toml.tmpl` and `.chezmoiignore` are chezmoi's own files, not
targets; the latter keeps this README out of `$HOME`. `~/.zprofile` (Homebrew's
`shellenv`) and all git configuration (identity, signing) are deliberately left
unmanaged for per-machine setup.

## History

Before the 2026-10 cleanup this repo also provisioned billet devcontainers
(rc-file patching, Claude Code settings and plugins, the board agents, tmux) and
managed git identity, including the GenShift work-address override.
That state is preserved on the `archive/pre-cleanup-2026-10-06` branch for
reference.
