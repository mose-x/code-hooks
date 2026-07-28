#!/usr/bin/env bash
# load-config.sh: shared loader + matchers for code-hooks.
#
# Sourced by pre-commit / commit-msg / pre-push and inlined (in spirit)
# by the commit-lint CI workflow. Provides:
#
#   Config access:
#     get_identities              -> print `Name <email>` lines from [identities]
#     get_allowed_branches        -> print patterns from [allowed_branches]
#     get_forbidden_tokens        -> print literal tokens from [forbidden_tokens]
#     get_commit_types            -> print types from [commit_types]
#     get_rule <key>              -> print value for <key> from [rules]
#     config_section_nonempty <s> -> 0 if section <s> exists and has >=1 entry
#
#   Matchers:
#     branch_allowed <branch>     -> 0 if <branch> matches any [allowed_branches] entry
#     message_has_forbidden <msg> -> 0 if <msg> contains any [forbidden_tokens] entry
#     email_in_allowlist <email>  -> 0 if <email> appears in [identities]
#
# Fail-closed:
#   - If hook-rules.conf is missing -> caller must reject (callers check
#     `config_load_ok` after sourcing).
#   - If a required section is missing or empty -> the corresponding
#     `get_*` function prints nothing; callers decide to reject.
#
# HOOKS_DIR must be set by the caller before sourcing this file.
# HOOKS_DIR points at the code-hooks repo root (where hook-rules.conf lives).

set -euo pipefail

# shellcheck disable=SC2153
config_file="$HOOKS_DIR/hook-rules.conf"

# Print the lines of a named section (excluding the [section] header,
# comments, and blank lines). Empty output if section not found.
_section_lines() {
    local section="$1"
    awk -v want="$section" '
        /^\[/ {
            in_section = ($0 == "[" want "]")
            next
        }
        in_section {
            line = $0
            sub(/#.*/, "", line)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
            if (line != "") print line
        }
    ' "$config_file"
}

get_identities() {
    _section_lines identities
}

get_allowed_branches() {
    _section_lines allowed_branches
}

get_forbidden_tokens() {
    _section_lines forbidden_tokens
}

get_commit_types() {
    _section_lines commit_types
}

# Print the command for <lang>:<stage> from [lang_tools].
# Line format in hook-rules.conf: `lang:stage=command`
# Returns empty string if the section, lang, or stage is missing, or if
# the value is intentionally empty (disabled stage).
get_lang_tool() {
    local lang="$1"
    local stage="$2"
    # Use awk with sub() to strip the `lang:stage=` prefix, leaving the
    # rest of the line (which may contain `=` or `:`) as the command.
    awk -v want_lang="$lang" -v want_stage="$stage" '
        {
            line = $0
            # Split on first ":" to get "lang" and "stage=command".
            colon = index(line, ":")
            if (colon == 0) next
            l = substr(line, 1, colon - 1)
            rest = substr(line, colon + 1)
            # Split rest on first "=" to get "stage" and "command".
            eq = index(rest, "=")
            if (eq == 0) next
            s = substr(rest, 1, eq - 1)
            cmd = substr(rest, eq + 1)
            if (l == want_lang && s == want_stage) {
                print cmd
                exit
            }
        }
    ' <(_section_lines lang_tools)
}

# Print the value for <key> from [rules]. Empty string if missing.
get_rule() {
    local key="$1"
    _section_lines rules | awk -F= -v k="$key" '
        {
            lk = $1; rv = $0
            sub(/^[^=]*=/, "", rv)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", lk)
            if (lk == k) { print rv; exit }
        }
    '
}

# 0 if section <s> exists and has at least one non-comment entry.
config_section_nonempty() {
    local section="$1"
    [ -n "$(_section_lines "$section")" ]
}

# --- Matchers -------------------------------------------------------

# 0 if <branch> matches any [allowed_branches] pattern.
# Match rules:
#   - pattern ending in `*`  -> prefix match (branch starts with prefix)
#   - otherwise              -> exact string match
# Other glob chars (`?`, `[...]`, mid-string `*`) are literal.
branch_allowed() {
    local branch="$1"
    local pattern prefix
    while IFS= read -r pattern; do
        if [[ "$pattern" == *\* ]]; then
            prefix="${pattern%\*}"
            if [[ "$branch" == "$prefix"* ]]; then
                return 0
            fi
        else
            if [[ "$branch" == "$pattern" ]]; then
                return 0
            fi
        fi
    done < <(get_allowed_branches)
    return 1
}

# Normalize text: replace non-alphanumeric runs with single space, lowercase.
# Used by message_has_forbidden so `trae-agent` and `traeagent` both hit
# the entry `trae agent`.
_normalize_for_token_match() {
    tr -c '[:alnum:]' ' ' | tr -s ' ' | tr 'A-Z' 'a-z'
}

# 0 if <msg> contains any [forbidden_tokens] entry (after normalization).
message_has_forbidden() {
    local msg="$1"
    local norm tokens token tnorm
    norm=$(printf '%s' "$msg" | _normalize_for_token_match)
    while IFS= read -r token; do
        tnorm=$(printf '%s' "$token" | _normalize_for_token_match)
        # Word-boundary-ish: ensure the token is matched as a unit by
        # checking it appears with leading/trailing space-or-edge. Since
        # `norm` is already space-padded internally, surround both sides
        # with spaces for substring containment.
        if [[ " $norm " == *" $tnorm "* ]]; then
            return 0
        fi
    done < <(get_forbidden_tokens)
    return 1
}

# 0 if <email> appears in [identities].
email_in_allowlist() {
    local target="$1"
    local line email
    while IFS= read -r line; do
        # Extract just the email between < and >.
        email=$(printf '%s' "$line" | grep -oE '<[^>]+>' | tr -d '<>' \
            | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
        if [ "$email" = "$target" ]; then
            return 0
        fi
    done < <(get_identities)
    return 1
}

# Sanity-check the config file at source time. Callers can read
# `config_load_ok` to decide whether to proceed.
config_load_ok=1
if [ ! -f "$config_file" ]; then
    config_load_ok=0
fi
