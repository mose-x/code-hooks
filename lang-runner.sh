#!/usr/bin/env bash
# lang-runner.sh: run fmt / lint / test toolchains per detected language.
#
# Sourced by pre-commit (fmt + lint) and pre-push (test). Each language's
# exact command is read from hook-rules.conf [lang_tools] via get_lang_tool.
#
# Behaviour:
#   - Empty [lang_tools] section or empty value for a lang:stage -> skip
#     silently (intentional disable, e.g. Java fmt/lint).
#   - Missing [lang_tools] section entirely -> skip all language tools.
#     This keeps docs-only commits and fresh clones fast.
#   - Tool not found in PATH -> fail closed with an install hint. This
#     matches the identity fail-closed philosophy: if your commit touches
#     .go you must have go installed locally, otherwise local and CI
#     diverge. cargo / npx are special-cased because they self-resolve
#     subcommands.
#
# $FILES in a command is substituted with the space-separated, single-
# quoted file list passed by the caller, so fmt/lint can target only the
# changed files (fast) instead of the whole repo.

# _lang_tool_available <cmd>
#   Returns 0 if the first token of <cmd> is a usable tool.
#   cargo / npx are treated as always-available (they resolve subcommands).
_lang_tool_available() {
    local cmd="$1"
    local tool="${cmd%% *}"
    case "$tool" in
        cargo|npx|npm|mvn|gradle|./gradlew)
            # These resolve their own subcommands; presence of the wrapper
            # is checked by actually running them via the configured cmd.
            return 0
            ;;
        *)
            command -v "$tool" >/dev/null 2>&1
            ;;
    esac
}

# run_lang_stage <lang> <stage> <files>
#   Runs the configured command for <lang>:<stage>. Returns 0 on success
#   or if the stage is disabled (empty value). Returns 1 on failure or if
#   the tool is missing (fail-closed).
run_lang_stage() {
    local lang="$1"
    local stage="$2"
    local files="$3"
    local cmd

    cmd=$(get_lang_tool "$lang" "$stage")
    # Empty value: two distinct cases.
    if [ -z "$cmd" ]; then
        if has_lang_any_tool "$lang"; then
            # Intentional disable (entry exists with empty value, e.g.
            # `java:fmt=`). Silent skip, same as before.
            return 0
        fi
        # Detected language but no [lang_tools] entry at all. Print a
        # hint so the user knows their .php/.pl/.cs/... changes are not
        # being checked, and how to enable them. Non-fatal (return 0):
        # an unconfigured language is not a policy violation.
        echo "  $lang $stage: detected but no [lang_tools] entry -- skipped." >&2
        echo "    to enable, add '${lang}:${stage}=<cmd>' to hook-rules.conf" >&2
        return 0
    fi

    if ! _lang_tool_available "$cmd"; then
        local tool="${cmd%% *}"
        echo "pre-commit: reject" >&2
        echo "  $tool not found in PATH, but $lang $stage is configured." >&2
        echo "  install $tool, or disable this stage:" >&2
        echo "    edit hook-rules.conf [lang_tools] ${lang}:${stage}=" >&2
        return 1
    fi

    # Substitute $FILES with single-quoted, space-separated file list.
    # Using printf %q to safely quote paths with spaces / special chars.
    local quoted_files=""
    local f
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        quoted_files+=" $(printf '%q' "$f")"
    done <<< "$files"
    cmd="${cmd//\$FILES/$quoted_files}"

    echo "  $lang $stage: $cmd" >&2
    if ! eval "$cmd" 2>&1; then
        echo "pre-commit: reject" >&2
        echo "  $lang $stage failed: $cmd" >&2
        return 1
    fi
    return 0
}

# run_all_langs_stage <stage> <files>
#   Detects languages from <files> and runs <stage> for each.
#   Returns 0 iff every language's stage succeeded (or was disabled).
run_all_langs_stage() {
    local stage="$1"
    local files="$2"
    local fail=0
    local lang

    while IFS= read -r lang; do
        [ -z "$lang" ] && continue
        run_lang_stage "$lang" "$stage" "$files" || fail=1
    done < <(detect_languages "$files")

    return $fail
}
