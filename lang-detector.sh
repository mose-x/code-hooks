#!/usr/bin/env bash
# lang-detector.sh: detect programming languages from changed files.
#
# Sourced by pre-commit (staged files) and pre-push (push-range files).
# Detection is by file suffix -- a docs-only commit (README / *.md) has
# no recognised suffix and therefore skips every language tool, matching
# the existing Rust-only behaviour for non-source commits.
#
# Five languages are configured out-of-box in hook-rules.conf [lang_tools]:
# rust, go, nodejs, python, java. The detector below also recognises
# php, perl, csharp suffixes -- these become active the moment a consumer
# adds the corresponding [lang_tools] entries (see README "Adding or
# customizing a language"). No code change is needed to enable them.
#
# wails is NOT a separate language: a wails project has both .go (backend)
# and .js/.ts/.vue/.jsx/... (frontend under frontend/), so it shows up as
# `go` + `nodejs` and both toolchains run. The presence of wails.json is
# not required for detection -- it only affects which nodejs commands are
# configured in hook-rules.conf [lang_tools].
#
# Output: detect_languages prints one language per line, deduped, sorted.

# detect_languages <files>
#   <files>: newline-separated file paths (e.g. git diff --name-only output)
detect_languages() {
    local files="$1"
    local langs=()

    # Suffix -> language map. One grep per language keeps the pattern
    # readable and avoids a single mega-regex that is hard to maintain.
    # Out-of-box configured (hook-rules.conf ships entries for these):
    printf '%s\n' "$files" | grep -qE '\.rs$'               && langs+=("rust")
    printf '%s\n' "$files" | grep -qE '\.go$'               && langs+=("go")
    # nodejs covers JS/TS plus framework-specific suffixes (.vue, .svelte,
    # .astro) since they all share the npm toolchain.
    printf '%s\n' "$files" | grep -qE '\.(js|ts|jsx|tsx|mjs|cjs|vue|svelte|astro)$' && langs+=("nodejs")
    printf '%s\n' "$files" | grep -qE '\.(java|kt)$'        && langs+=("java")
    printf '%s\n' "$files" | grep -qE '\.py$'               && langs+=("python")
    # Recognised but NOT configured out-of-box -- add [lang_tools] entries
    # to enable (see README "Adding or customizing a language"):
    printf '%s\n' "$files" | grep -qE '\.php$'              && langs+=("php")
    printf '%s\n' "$files" | grep -qE '\.pl$|\.pm$|\.t$'    && langs+=("perl")
    printf '%s\n' "$files" | grep -qE '\.cs$'               && langs+=("csharp")

    if [ "${#langs[@]}" -eq 0 ]; then
        return 0
    fi
    printf '%s\n' "${langs[@]}" | sort -u
}
