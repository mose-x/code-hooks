#!/usr/bin/env bash
# Bootstrap git hooks for a target workdir from this public hooks repo.
#
# Idempotent: safe to re-run. Reuses credential.helper=store if present.
#
# Usage:
#   bash /root/.code-hooks/setup-code-hooks.sh [path-to-target-workdir]
#   # or, from a fresh sandbox with nothing cloned yet:
#   curl -fsSL https://raw.githubusercontent.com/mose-x/code-hooks/main/setup-code-hooks.sh | bash -s -- /workspace
set -euo pipefail

HOOKS_DIR="/root/.code-hooks"
WORKDIR="${1:-/workspace}"

# If this script is running but /root/.code-hooks doesn't exist yet (the
# curl-pipe-bash bootstrap path), clone the repo first so the hook files
# land on disk.
if [ ! -d "$HOOKS_DIR/.git" ]; then
    git clone https://github.com/mose-x/code-hooks.git "$HOOKS_DIR"
else
    git -C "$HOOKS_DIR" pull --ff-only
fi

# Point the target repo at the hooks directory.
git -C "$WORKDIR" config core.hooksPath "$HOOKS_DIR"

# Pick the first identity from allowed-identities and pin it into the
# workdir's git config so pre-commit is satisfied without any manual
# `git config user.email`. This is a convenience for the primary developer
# (the first listed identity); contributors with a different email should
# run `git config user.email <theirs>` manually, or create a
# `.allowed-identities.local` in $HOOKS_DIR with their own entry first.
allowlist="$HOOKS_DIR/allowed-identities"
if [ -f "$allowlist" ] && grep -qE '<[^>]+>' "$allowlist" 2>/dev/null; then
    # Extract the first `Name <email>` line (ignoring comments/blanks).
    first_line=$(sed -E 's/#.*$//; /^[[:space:]]*$/d' "$allowlist" \
        | grep -E '<[^>]+>' | head -1)
    first_email=$(printf '%s' "$first_line" | grep -oE '<[^>]+>' | tr -d '<>' \
        | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
    first_name=$(printf '%s' "$first_line" | sed -E 's/[[:space:]]*<[^>]+>[[:space:]]*$//' \
        | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')

    if [ -n "$first_email" ]; then
        current_email=$(git -C "$WORKDIR" config user.email 2>/dev/null || echo "")
        if [ "$current_email" != "$first_email" ]; then
            git -C "$WORKDIR" config user.email "$first_email"
        fi
    fi
    if [ -n "$first_name" ]; then
        current_name=$(git -C "$WORKDIR" config user.name 2>/dev/null || echo "")
        if [ "$current_name" != "$first_name" ]; then
            git -C "$WORKDIR" config user.name "$first_name"
        fi
    fi
else
    echo "setup-code-hooks: WARNING: no allowed-identities file with entries." >&2
    echo "  pre-commit will fail closed until you create one at:" >&2
    echo "    $HOOKS_DIR/allowed-identities" >&2
    echo "  or a local override at:" >&2
    echo "    $HOOKS_DIR/.allowed-identities.local" >&2
fi

echo "hooksPath -> $(git -C "$WORKDIR" config core.hooksPath)"
echo "user.name -> $(git -C "$WORKDIR" config user.name)"
echo "user.email -> $(git -C "$WORKDIR" config user.email)"
