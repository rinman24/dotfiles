# dotfiles

Personal shell and tool configuration, managed by [chezmoi](https://chezmoi.io).
The repo root is the chezmoi source tree; chezmoi applies it identically on every
target — my Mac and each devcontainer.

```bash
# any machine (chezmoi is a single static binary):
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin" init --apply rinman24
# on the Mac, prefer brew to own the binary:  brew install chezmoi
chezmoi update   # pull + re-apply thereafter
```

## Layout

- `dot_aliases.sh` → `~/.aliases.sh` (aliases; `yolo` = `claude --dangerously-skip-permissions`)
- `dot_tmux.conf` → `~/.tmux.conf`
- `modify_dot_bashrc`, `modify_dot_zshrc` — append the aliases source line if
  missing, preserving image-provided rc content (never a wholesale managed file)
- `.chezmoiignore` — skips `.zshrc` on machines without zsh; also excludes this
  README and the transitional `install.sh` from being applied to `$HOME`
- `private_dot_claude/` → `~/.claude/` (0700)
  - `modify_settings.json` — surgically deep-merges the managed settings surface
    (canon + skills marketplaces, enabled plugins, tripwire hook) into
    `~/.claude/settings.json`; leaves every other key Claude Code writes untouched
  - `executable_canon-tripwire.sh` → `~/.claude/canon-tripwire.sh`
- `run_after_pyright.sh` — ensures `pyright-langserver` is on PATH (non-fatal)
- `run_onchange_canon.sh` — canon marketplace/plugin CLI activation, belt-and-braces
- `install.sh` — transitional shim only; forwards old bootstrap calls to chezmoi

## billet integration

chezmoi is applied to every billet-managed devcontainer via billet's
`personal_bootstrap_cmd`, run inside the service container on every `billet start`:

```toml
[billet]
personal_bootstrap_cmd = 'export PATH="$HOME/.local/bin:$PATH"; if command -v chezmoi >/dev/null 2>&1; then chezmoi update; else sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin" init --apply rinman24; fi'
```

Idempotent by design: install-and-apply the first start, `chezmoi update` (pull +
re-apply) every start after. Leaving `personal_bootstrap_cmd` unset disables the
hook; a failing command aborts `billet start` like any other phase.
