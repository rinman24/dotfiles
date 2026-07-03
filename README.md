# dotfiles

Personal shell and tool configuration, applied by an idempotent installer.

```bash
git clone git@github.com:rinman24/dotfiles.git ~/.dotfiles
~/.dotfiles/install.sh
```

`install.sh` is safe to re-run: it symlinks each config into place (backing up any
pre-existing regular file once, to `*.bak`) and appends a source line for
`shell/aliases.sh` to both `~/.bashrc` and `~/.zshrc` — exactly once — so the
aliases work whichever login shell a machine uses.

## Layout

- `shell/aliases.sh` — aliases sourced by bash and zsh (`yolo` = `claude --dangerously-skip-permissions`)
- `tmux/tmux.conf` — tmux configuration (linked to `~/.tmux.conf`)
- `install.sh` — idempotent installer

## billet integration

These dotfiles are applied automatically to every billet-managed devcontainer via
billet's `personal_bootstrap_cmd` hook (billet PR #22). billet runs the command
below **inside the service container** on every `billet start`, immediately after
the repo's devcontainer `postCreateCommand` — so the dotfiles survive container
rebuilds without being committed to any team repo.

Add this to the billet operator config (`config.toml`, resolved via `--config`,
`$BILLET_CONFIG`, or the XDG default path):

```toml
[billet]
personal_bootstrap_cmd = "git clone --depth 1 https://github.com/rinman24/dotfiles ~/.dotfiles 2>/dev/null || git -C ~/.dotfiles pull --ff-only; ~/.dotfiles/install.sh"
```

Notes:

- The command must stay **idempotent** — billet re-runs it on every `billet start`
  (clone the first time, `pull --ff-only` thereafter).
- Leaving `personal_bootstrap_cmd` unset (or `""`) disables the hook entirely; a
  failing command aborts `billet start` like any other phase.
- The clone uses HTTPS because containers may not have GitHub SSH keys; this only
  works while the repo is public. If it goes private, switch to the SSH URL and
  forward an agent, or bake a read token into the URL via a credential helper.
