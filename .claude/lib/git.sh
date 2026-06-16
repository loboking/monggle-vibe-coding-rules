#!/bin/bash
#
# git.sh - Safe git operations
#
# Prevents command injection in git operations
#

# Safe git log with array arguments (no eval)
# bash 3.2 호환: nameref(local -n) 대신 인자를 값으로 직접 받음.
# 호출: safe_git_log "${git_args[@]}"
safe_git_log() {
    # Always use safe format
    git log --pretty=format:'%h|%s|%an|%ad' --date=short "$@"
}

# Safe git diff with array arguments
# 호출: safe_git_diff "${git_args[@]}"
safe_git_diff() {
    git diff "$@"
}

# Get commits between two tags (safe)
get_commits_between() {
    local from_tag="$1"
    local to_tag="${2:-HEAD}"

    # 태그 검증 (인젝션 방지)
    if [[ "$from_tag" != "HEAD" ]] && ! [[ "$from_tag" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        echo "Error: Invalid from_tag format: $from_tag" >&2
        return 1
    fi

    if [[ "$to_tag" != "HEAD" ]] && ! [[ "$to_tag" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        echo "Error: Invalid to_tag format: $to_tag" >&2
        return 1
    fi

    # 태그 존재 확인 (HEAD 제외)
    if [[ "$from_tag" != "HEAD" ]]; then
        if ! git rev-parse "$from_tag" >/dev/null 2>&1; then
            echo "Error: Tag not found: $from_tag" >&2
            return 1
        fi
    fi

    if [[ "$to_tag" != "HEAD" ]]; then
        if ! git rev-parse "$to_tag" >/dev/null 2>&1; then
            echo "Error: Tag not found: $to_tag" >&2
            return 1
        fi
    fi

    local git_args=()
    git_args+=("${from_tag}..${to_tag}")
    safe_git_log "${git_args[@]}"
}

# Get commits since date (safe)
get_commits_since() {
    local since_date="$1"

    local git_args=()
    git_args+=("--since=${since_date}")

    safe_git_log "${git_args[@]}"
}

# Get latest tag safely
get_latest_tag() {
    git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0"
}

# Validate git tag format
validate_git_tag() {
    local tag="$1"

    # Tags should start with v or be plain semver
    if [[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || [[ "$tag" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 0
    fi

    echo "Error: Invalid git tag format: $tag" >&2
    return 1
}

# Check if we're in a git repository
is_git_repo() {
    git rev-parse --git-dir >/dev/null 2>&1
}

# Get current branch name (safe)
get_current_branch() {
    git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown"
}

# Check if working directory is clean
is_git_clean() {
    git diff-index --quiet HEAD -- 2>/dev/null
}
