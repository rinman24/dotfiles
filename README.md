# dotfiles

Personal shell and tool configuration, managed by [chezmoi](https://chezmoi.io).
The repo root is the chezmoi source tree.

```bash
brew install chezmoi
chezmoi init --apply rinman24
chezmoi update   # pull + re-apply thereafter
```

## Layout

- `dot_zshrc` → `~/.zshrc` (fully managed; `yolo` = `claude --dangerously-skip-permissions`)
- `dot_config/git/config` → `~/.config/git/config` (commit identity and
  `commit.gpgsign = false`; swaps `user.email` to the GenShift address for
  `genshift-energy` and Azure DevOps remotes via `includeIf "hasconfig:remote.*.url:…"`)
- `dot_config/git/genshift.inc` → `~/.config/git/genshift.inc` (the work-address
  override the above includes)
- `.chezmoiignore` — excludes this README from being applied to `$HOME`
