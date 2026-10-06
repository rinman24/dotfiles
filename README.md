# dotfiles

Personal configuration for my Mac, managed by [chezmoi](https://chezmoi.io).
The repo root is the chezmoi source tree.

## Setup

Prerequisite: [Homebrew](https://brew.sh).

```bash
brew install chezmoi
chezmoi init --apply --ssh rinman24   # clone to ~/.local/share/chezmoi and apply
```

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

`.chezmoiignore` keeps this README out of `$HOME`. `~/.zprofile` (Homebrew's
`shellenv`) and all git configuration (identity, signing) are deliberately left
unmanaged for per-machine setup.

## History

Before the 2026-10 cleanup this repo also provisioned billet devcontainers
(rc-file patching, Claude Code settings and plugins, the board agents, tmux) and
managed git identity, including the GenShift work-address override.
That state is preserved on the `archive/pre-cleanup-2026-10-06` branch for
reference.
