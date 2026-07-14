#!/usr/bin/env bash
# Transitional shim. This repo is now a chezmoi source tree, not the old
# symlink-installer layout. Old billet configs still call ~/.dotfiles/install.sh;
# this forwards them to chezmoi so cutover order doesn't matter. Delete once no
# config references this path (billet personal_bootstrap_cmd flipped everywhere).
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
command -v chezmoi >/dev/null 2>&1 \
  || sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
chezmoi init --apply rinman24
