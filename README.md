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
personal_bootstrap_cmd = "if [ -d ~/.dotfiles/.git ]; then git -C ~/.dotfiles pull --ff-only; else git clone --depth 1 https://github.com/rinman24/dotfiles ~/.dotfiles; fi && ~/.dotfiles/install.sh"
```

Notes:

- The command must stay **idempotent** — billet re-runs it on every `billet start`
  (clone the first time, `pull --ff-only` thereafter). The explicit exists-check
  keeps failures loud: nothing is redirected to `/dev/null`, and `install.sh` only
  runs once the repo is actually in place.
- Leaving `personal_bootstrap_cmd` unset (or `""`) disables the hook entirely; a
  failing command aborts `billet start` like any other phase.
- The clone uses HTTPS, which works anywhere while this repo is public. billet can
  also agent-forward the personal bootstrap through the container's sshd, so an SSH
  URL to a private repo works too — never bake a token into the URL.
