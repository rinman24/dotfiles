# dotfiles

Personal shell and tool configuration, managed by [chezmoi](https://chezmoi.io).
The repo root is the chezmoi source tree.

```bash
brew install chezmoi
chezmoi init --apply rinman24
chezmoi update   # pull + re-apply thereafter
```

## Layout

- `dot_aliases.sh` → `~/.aliases.sh` (aliases; `yolo` = `claude --dangerously-skip-permissions`)
- `dot_config/tmux/tmux.conf` → `~/.config/tmux/tmux.conf` (hand-rolled status
  line; no plugin manager — see the palette block to recolour it)
- `dot_config/git/config` → `~/.config/git/config` (commit identity and
  `commit.gpgsign = false`; swaps `user.email` to the GenShift address for
  `genshift-energy` and Azure DevOps remotes via `includeIf "hasconfig:remote.*.url:…"`)
- `dot_config/git/genshift.inc` → `~/.config/git/genshift.inc` (the work-address
  override the above includes)
- `modify_dot_zshrc` — appends the aliases source line to `~/.zshrc` if missing
- `.chezmoiignore` — excludes this README from being applied to `$HOME`
- `private_dot_claude/` → `~/.claude/` (0700)
  - `modify_settings.json` — surgically deep-merges the managed settings surface
    (canon + skills marketplaces, enabled plugins, tripwire hook) into
    `~/.claude/settings.json`; leaves every other key Claude Code writes untouched
  - `executable_canon-tripwire.sh` → `~/.claude/canon-tripwire.sh`
- `run_after_pyright.sh` — ensures `pyright-langserver` is on PATH (non-fatal)
- `run_onchange_canon.sh` — canon marketplace/plugin CLI activation, belt-and-braces
