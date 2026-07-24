#!/usr/bin/env bash
# Bootstrap git hooks for an nvm-rust workdir from this private hooks repo.
#
# Idempotent: safe to re-run. Reuses credential.helper=store if present.
#
# Usage:
#   bash /root/.nvm-hooks/setup-nvm-hooks.sh [path-to-nvm-rust-workdir]
#   # or, from a fresh sandbox with nothing cloned yet:
#   curl -fsSL https://raw.githubusercontent.com/mose-x/code-hooks/main/setup-nvm-hooks.sh | bash -s -- /workspace
set -euo pipefail

HOOKS_DIR="/root/.nvm-hooks"
WORKDIR="${1:-/workspace}"

# If this script is running but /root/.nvm-hooks doesn't exist yet (the
# curl-pipe-bash bootstrap path), clone the repo first so the hook files
# land on disk.
if [ ! -d "$HOOKS_DIR/.git" ]; then
    git clone https://github.com/mose-x/code-hooks.git "$HOOKS_DIR"
else
    git -C "$HOOKS_DIR" pull --ff-only
fi

# Point the nvm-rust repo at the hooks directory.
git -C "$WORKDIR" config core.hooksPath "$HOOKS_DIR"

# Also pin the author identity in the workdir so pre-commit is happy without
# any manual `git config user.email`. Override only if missing or wrong.
current_email=$(git -C "$WORKDIR" config user.email 2>/dev/null || echo "")
if [ "$current_email" != "602187256@qq.com" ]; then
    git -C "$WORKDIR" config user.email "602187256@qq.com"
fi
current_name=$(git -C "$WORKDIR" config user.name 2>/dev/null || echo "")
if [ "$current_name" != "mose-zm" ]; then
    git -C "$WORKDIR" config user.name "mose-zm"
fi

echo "hooksPath -> $(git -C "$WORKDIR" config core.hooksPath)"
echo "user.name -> $(git -C "$WORKDIR" config user.name)"
echo "user.email -> $(git -C "$WORKDIR" config user.email)"
