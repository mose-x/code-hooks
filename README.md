# nvm-rust-hooks

Private repo hosting git hooks for [mose-x/nvm-rust](https://github.com/mose-x/nvm-rust).

The hooks themselves (`pre-commit`, `commit-msg`, `pre-push`) are never committed
into the nvm-rust repo; instead each sandbox/workdir points at this repo via
`core.hooksPath`. A bootstrap script (`setup-nvm-hooks.sh`) clones this repo and
wires up the workdir in one shot.

## Hooks

| Hook | Enforces |
|---|---|
| `pre-commit` | `user.email == 602187256@qq.com` |
| `commit-msg` | subject ≤ 100 chars, no trailing `.`, no `traeagent` / `Co-authored-by` |
| `pre-push` | only `main` branch; no `traeagent` / `Co-authored-by` in pushed range |

## Activate in a fresh sandbox

The sandbox network allows `git clone` from `github.com` (but blocks
`raw.githubusercontent.com`), so bootstrap with two commands:

```bash
git clone https://github.com/mose-x/nvm-rust-hooks.git /root/.nvm-hooks && \
bash /root/.nvm-hooks/setup-nvm-hooks.sh /workspace
```

The script is idempotent — re-running just does `pull --ff-only` and refreshes
the workdir config. It also pins `user.name=mose-zm` / `user.email=602187256@qq.com`
into the workdir so `pre-commit` is satisfied without any manual `git config`.

Replace `/workspace` with the actual nvm-rust workdir path if different.

## Notes

- `~/.git-credentials` (the GitHub PAT) and `/root/.nvm-hooks/` live under
  `/root` and do not persist across sandbox resets; re-run the bootstrap
  above at the start of each new session.
- The hooks repo itself is pushed using the same PAT / identity as nvm-rust.
