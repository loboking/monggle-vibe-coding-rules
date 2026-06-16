#!/bin/bash
#
# changelog.sh - monggle: Generate CHANGELOG.md from git commits
#
# Usage: /changelog [options]
#
# Options:
#   --since DATE      Show changes since DATE (e.g., 2024-01-01)
#   --from TAG        Show changes since TAG
#   --to TAG          Show changes up to TAG
#   --output FILE     Write to file instead of stdout
#   --append          Append to existing CHANGELOG.md
#   --format FORMAT   Output format (markdown|json|text)
#

set -euo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# Configuration
PROJECT_ROOT="$(get_project_root)"
SINCE_DATE=""
FROM_TAG=""
TO_TAG=""
OUTPUT_FILE=""
APPEND=0
FORMAT="markdown"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --since)
            SINCE_DATE="$2"
            shift 2
            ;;
        --from)
            FROM_TAG="$2"
            shift 2
            ;;
        --to)
            TO_TAG="$2"
            shift 2
            ;;
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --append)
            APPEND=1
            shift
            ;;
        --format)
            FORMAT="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: /changelog [options]"
            echo ""
            echo "Options:"
            echo "  --since DATE      Show changes since DATE"
            echo "  --from TAG        Show changes since TAG"
            echo "  --to TAG          Show changes up to TAG"
            echo "  --output FILE     Write to file"
            echo "  --append          Append to existing CHANGELOG.md"
            echo "  --format FORMAT   Output format (markdown|json|text)"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

print_header "CHANGELOG Generator"

# Check if we're in a git repository
cd "$PROJECT_ROOT"
if ! is_git_repo; then
    die "Not a git repository"
fi

# Get version from git tag or package.json/pyproject.toml
get_version() {
    # Try git tag
    local latest_tag
    latest_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
    echo "$latest_tag"
}

# Format date
format_date() {
    date +%Y-%m-%d
}

# Categorize commit
categorize_commit() {
    local msg="$1"

    if echo "$msg" | grep -qiE "^(feat|add|new|feature)"; then
        echo "added"
    elif echo "$msg" | grep -qiE "^(fix|bug|hotfix)"; then
        echo "fixed"
    elif echo "$msg" | grep -qiE "^(refactor|refact)"; then
        echo "changed"
    elif echo "$msg" | grep -qiE "^(perf|performance|optimize)"; then
        echo "optimized"
    elif echo "$msg" | grep -qiE "^(docs|documentation)"; then
        echo "documented"
    elif echo "$msg" | grep -qiE "^(test|testing)"; then
        echo "tested"
    elif echo "$msg" | grep -qiE "^(style|format)"; then
        echo "styled"
    elif echo "$msg" | grep -qiE "^(chore|build|ci)"; then
        echo "chore"
    elif echo "$msg" | grep -qiE "^(sec|security)"; then
        echo "secured"
    else
        echo "misc"
    fi
}

# Generate changelog
generate_changelog() {
    local since_date="$1"
    local from_tag="$2"
    local to_tag="$3"

    # Build git log arguments
    local git_args="--pretty=format:%h|%s|%an|%ad"
    git_args="$git_args --date=short"

    if [[ -n "$from_tag" ]]; then
        git_args="$git_args ${from_tag}..${to_tag:-HEAD}"
    elif [[ -n "$since_date" ]]; then
        git_args="$git_args --since=${since_date}"
    fi

    # Build git log array (safe, no eval)
    local git_log_args
    git_log_args=()
    git_log_args+=("--pretty=format:%h|%s")
    git_log_args+=("--date=short")

    if [[ -n "$from_tag" ]]; then
        git_log_args+=("${from_tag}..${to_tag:-HEAD}")
    elif [[ -n "$since_date" ]]; then
        git_log_args+=("--since=${since_date}")
    fi

    # Get commits (safe execution)
    local commits
    commits=$(git log "${git_log_args[@]}" 2>/dev/null || true)

    if [[ -z "$commits" ]]; then
        log_warn "No commits found"
        return 1
    fi

    # Categorize commits.
    # NOTE: bash 3.2 (macOS default) does not support associative arrays
    # (declare -A), so we accumulate into one plain variable per category and
    # pass them as positional args (in a fixed CATEGORY_ORDER) to the output
    # functions. CATEGORY_ORDER is the contract between producer/consumers.
    local cat_added="" cat_fixed="" cat_changed="" cat_optimized=""
    local cat_documented="" cat_tested="" cat_styled="" cat_chore=""
    local cat_secured="" cat_misc=""

    # message is the trailing field so a '|' inside the subject is preserved.
    while IFS='|' read -r hash message; do
        local category
        category=$(categorize_commit "$message")
        local line="- ${message} (${hash})%NL%"
        case "$category" in
            added)      cat_added="${cat_added}${line}" ;;
            fixed)      cat_fixed="${cat_fixed}${line}" ;;
            changed)    cat_changed="${cat_changed}${line}" ;;
            optimized)  cat_optimized="${cat_optimized}${line}" ;;
            documented) cat_documented="${cat_documented}${line}" ;;
            tested)     cat_tested="${cat_tested}${line}" ;;
            styled)     cat_styled="${cat_styled}${line}" ;;
            chore)      cat_chore="${cat_chore}${line}" ;;
            secured)    cat_secured="${cat_secured}${line}" ;;
            *)          cat_misc="${cat_misc}${line}" ;;
        esac
    done <<< "$commits"

    # Positional order MUST match CATEGORY_ORDER consumed by output_* functions:
    #   1=added 2=fixed 3=changed 4=optimized 5=documented
    #   6=tested 7=styled 8=chore 9=secured 10=misc
    case "$FORMAT" in
        markdown)
            output_markdown "$cat_added" "$cat_fixed" "$cat_changed" "$cat_optimized" "$cat_documented" "$cat_tested" "$cat_styled" "$cat_chore" "$cat_secured" "$cat_misc"
            ;;
        json)
            output_json "$cat_added" "$cat_fixed" "$cat_changed" "$cat_optimized" "$cat_documented" "$cat_tested" "$cat_styled" "$cat_chore" "$cat_secured" "$cat_misc"
            ;;
        text)
            output_text "$cat_added" "$cat_fixed" "$cat_changed" "$cat_optimized" "$cat_documented" "$cat_tested" "$cat_styled" "$cat_chore" "$cat_secured" "$cat_misc"
            ;;
    esac
}

# Map a category name to the matching positional arg ($1..$10).
# CATEGORY_ORDER: added fixed changed optimized documented tested styled chore secured misc
# Usage: content=$(_cat_content "$category" "$@")
_cat_content() {
    local category="$1"; shift
    case "$category" in
        added)      printf '%s' "${1:-}" ;;
        fixed)      printf '%s' "${2:-}" ;;
        changed)    printf '%s' "${3:-}" ;;
        optimized)  printf '%s' "${4:-}" ;;
        documented) printf '%s' "${5:-}" ;;
        tested)     printf '%s' "${6:-}" ;;
        styled)     printf '%s' "${7:-}" ;;
        chore)      printf '%s' "${8:-}" ;;
        secured)    printf '%s' "${9:-}" ;;
        misc)       printf '%s' "${10:-}" ;;
    esac
}

output_markdown() {
    local _args=("$@")
    local version
    version=$(get_version)
    local today
    today=$(format_date)

    echo ""
    echo "## [$version] - $today"
    echo ""

    local section_found=0

    for category in added fixed changed optimized documented tested styled chore secured misc; do
        local content
        content=$(_cat_content "$category" "${_args[@]}")
        if [[ -n "$content" ]]; then
            section_found=1
            local title
            case "$category" in
                added) title="### Added" ;;
                fixed) title="### Fixed" ;;
                changed) title="### Changed" ;;
                optimized) title="### Optimized" ;;
                documented) title="### Documentation" ;;
                tested) title="### Tests" ;;
                styled) title="### Style" ;;
                chore) title="### Chore" ;;
                secured) title="### Security" ;;
                misc) title="### Other" ;;
            esac
            echo "$title"
            echo ""
            echo "$content" | sed 's/%NL%/\n/g'
            echo ""
        fi
    done

    if [[ $section_found -eq 0 ]]; then
        echo "No changes."
    fi
}

output_json() {
    local _args=("$@")
    echo "{"
    echo "  \"version\": \"$(get_version)\","
    echo "  \"date\": \"$(format_date)\","
    echo "  \"changes\": {"

    local first=1
    for category in added fixed changed optimized documented tested styled chore secured misc; do
        local content
        content=$(_cat_content "$category" "${_args[@]}")
        if [[ -n "$content" ]]; then
            if [[ $first -eq 0 ]]; then
                echo ","
            fi
            first=0
            echo "    \"$category\": ["
            # Split on the %NL% sentinel into one entry per line, then emit each
            # as a properly escaped JSON string element (comma-separated).
            local items
            items=$(echo "$content" | sed 's/%NL%/\n/g' | grep -v '^$')
            if command_exists jq; then
                echo "$items" | jq -R -s -r 'split("\n") | map(select(length > 0)) | map("      " + (. | @json)) | join(",\n")'
            else
                # Fallback: escape backslashes and double quotes, wrap per line.
                echo "$items" \
                    | sed 's/\\/\\\\/g; s/"/\\"/g' \
                    | sed 's/^/      "/' \
                    | sed 's/$/",/' \
                    | sed '$ s/,$//'
            fi
            echo "    ]"
        fi
    done

    echo "  }"
    echo "}"
}

output_text() {
    local _args=("$@")
    echo "Version: $(get_version)"
    echo "Date: $(format_date)"
    echo ""

    for category in added fixed changed optimized documented tested styled chore secured misc; do
        local content
        content=$(_cat_content "$category" "${_args[@]}")
        if [[ -n "$content" ]]; then
            local title
            case "$category" in
                added) title="ADDED" ;;
                fixed) title="FIXED" ;;
                changed) title="CHANGED" ;;
                optimized) title="OPTIMIZED" ;;
                documented) title="DOCUMENTATION" ;;
                tested) title="TESTS" ;;
                styled) title="STYLE" ;;
                chore) title="CHORE" ;;
                secured) title="SECURITY" ;;
                misc) title="OTHER" ;;
            esac
            echo "[$title]"
            echo "$content" | sed 's/%NL%/\n/g'
            echo ""
        fi
    done
}

# Main execution
if generate_changelog "$SINCE_DATE" "$FROM_TAG" "$TO_TAG"; then
    if [[ -n "$OUTPUT_FILE" ]]; then
        if [[ $APPEND -eq 1 ]] && [[ -f "$OUTPUT_FILE" ]]; then
            # 메인 스크립트 본문이라 local 사용 불가(함수 밖) — 일반 변수로 선언
            tmp_file=$(mktemp)
            {
                echo "# Changelog"
                echo ""
                generate_changelog "$SINCE_DATE" "$FROM_TAG" "$TO_TAG"
                echo ""
                echo "---"
                echo ""
                # Append existing content from its first version section onward.
                # Falls back to the whole file if no '## [' heading is present,
                # so arbitrary files are never truncated.
                existing_start=$(grep -n '^## \[' "$OUTPUT_FILE" 2>/dev/null | head -1 | cut -d: -f1)
                if [[ -n "$existing_start" ]]; then
                    tail -n "+${existing_start}" "$OUTPUT_FILE"
                else
                    cat "$OUTPUT_FILE"
                fi
            } > "$tmp_file"

            mv "$tmp_file" "$OUTPUT_FILE"
        else
            # Write new file
            {
                echo "# Changelog"
                echo ""
                echo "All notable changes to this project will be documented in this file."
                echo ""
                echo "The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),"
                echo "and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)."
                echo ""
                generate_changelog "$SINCE_DATE" "$FROM_TAG" "$TO_TAG"
            } > "$OUTPUT_FILE"
        fi
        log_success "CHANGELOG written to: $OUTPUT_FILE"
    fi
else
    log_warn "No changes to document"
fi

exit 0
