#!/bin/bash
#
# validation.sh - Input validation functions
#
# Safe input validation to prevent injection attacks
#

# Validate file path (prevent path traversal)
validate_file_path() {
    local path="$1"

    # 강화된 경로 탐색 검사
    # 1. 직접적인 .. 패턴
    if [[ "$path" =~ \.\. ]]; then
        echo "Error: Path traversal detected: $path" >&2
        return 1
    fi

    # 2. 우회 패턴 (././ etc)
    if [[ "$path" =~ \./\. ]] || [[ "$path" =~ \./\./ ]]; then
        echo "Error: Path traversal detected: $path" >&2
        return 1
    fi

    # 3. 실제 경로 확인 (이식성: macOS realpath는 -m 미지원)
    #    python3 os.path 기반으로 정규화하여 존재하지 않는 경로도 안전하게 처리.
    #    realpath -m 폴백은 정규화 없이 원본을 통과시켜 traversal 검증을 무력화하므로 사용하지 않음.
    local real_path
    local project_root
    project_root=$(pwd)

    # 상대 경로 -> 절대 경로 변환
    if [[ "$path" = /* ]]; then
        real_path="$path"
    else
        real_path="${project_root}/${path}"
    fi

    # 정규화 (.. 해결 등). 존재하지 않는 경로도 abspath+normpath로 처리 (realpath -m 의미).
    if command -v python3 &>/dev/null; then
        real_path=$(python3 -c 'import os, sys; print(os.path.normpath(os.path.abspath(sys.argv[1])))' "$real_path" 2>/dev/null || echo "$real_path")
    elif command -v realpath &>/dev/null; then
        # GNU realpath -m: 존재하지 않는 경로 허용. macOS는 위 python3 경로를 사용.
        real_path=$(realpath -m "$real_path" 2>/dev/null || echo "$real_path")
    fi

    # 프로젝트 루트 밖인지 확인
    case "$real_path" in
        "$project_root"/*|"$project_root") ;;  # 프로젝트 내 또는 루트 자체
        *)
            echo "Error: Path outside project root: $path" >&2
            return 1
            ;;
    esac

    return 0
}

# Validate directory path (must be within project root)
validate_within_root() {
    local target_path="$1"
    local root_path="$2"

    # Resolve to absolute paths
    local abs_target
    local abs_root

    abs_target="$(cd "$target_path" 2>/dev/null && pwd)" || return 1
    abs_root="$(cd "$root_path" 2>/dev/null && pwd)" || return 1

    # Check if target is within root
    case "$abs_target" in
        "$abs_root"/*) return 0 ;;
        "$abs_root") return 0 ;;
        *)
            echo "Error: Path must be within project root" >&2
            return 1
            ;;
    esac
}

# Validate version string (semantic version)
validate_version() {
    local version="$1"

    # Match: X.Y.Z or X.Y.Z-prerelease
    if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9a-zA-Z.]+)?$ ]]; then
        return 0
    fi

    echo "Error: Invalid version format: $version" >&2
    return 1
}

# Validate threshold (positive integer)
validate_threshold() {
    local value="$1"

    if [[ ! "$value" =~ ^[0-9]+$ ]]; then
        echo "Error: Threshold must be a positive integer: $value" >&2
        return 1
    fi

    return 0
}

# Validate PRD type
validate_prd_type() {
    local prd_type="$1"

    case "$prd_type" in
        feature|bug|refactor|hotfix|experiment|api|migration|ml|devops)
            return 0
            ;;
        *)
            echo "Error: Invalid PRD type: $prd_type" >&2
            return 1
            ;;
    esac
}

# Validate language code
validate_language() {
    local lang="$1"

    case "$lang" in
        ko|en|zh)
            return 0
            ;;
        *)
            echo "Error: Invalid language code: $lang (supported: ko, en, zh)" >&2
            return 1
            ;;
    esac
}

# Sanitize string for safe use in grep/sed
sanitize_pattern() {
    local pattern="$1"
    # Escape special regex characters
    echo "$pattern" | sed 's/[][\$^*.\/(){}+?|\\]/\\&/g'
}
