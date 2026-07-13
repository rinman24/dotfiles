#!/usr/bin/env bash
# Idempotent dotfiles installer — safe to re-run; billet re-runs it on every
# `billet start` (see the billet integration section of the README).
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Symlink a dotfile into place, backing up a pre-existing regular file once.
link_file() {
  local src="$1" dest="$2"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    mv "$dest" "$dest.bak"
  fi
  ln -sfn "$src" "$dest"
}

# Shell aliases: one symlinked file, sourced from both bash and zsh — container
# login shells vary by image (bash is always present; zsh only sometimes).
link_file "$DOTFILES_DIR/shell/aliases.sh" "$HOME/.aliases.sh"

source_line='[ -f "$HOME/.aliases.sh" ] && . "$HOME/.aliases.sh"'
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  # Only create a missing rc file when its shell is actually installed.
  shell_bin="$(basename "$rc" rc | tr -d .)"   # .bashrc -> bash, .zshrc -> zsh
  if [ ! -e "$rc" ] && ! command -v "$shell_bin" >/dev/null 2>&1; then
    continue
  fi
  touch "$rc"
  grep -qxF "$source_line" "$rc" || printf '\n%s\n' "$source_line" >>"$rc"
done

# tmux
link_file "$DOTFILES_DIR/tmux/tmux.conf" "$HOME/.tmux.conf"

# Claude Code: personal plugin marketplace + skills (user scope). Non-fatal —
# a missing tool must not brick a workspace bootstrap.
bash "$DOTFILES_DIR/claude/install-plugins.sh" \
  || echo "install.sh: claude plugin setup failed (non-fatal)" >&2

# Claude Code: canon marketplace activation (skips itself when claude is absent)
"$DOTFILES_DIR/claude/install.sh"

echo "dotfiles installed from $DOTFILES_DIR"
