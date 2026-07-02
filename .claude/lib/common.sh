#!/bin/bash
#
# common.sh - Shared utilities for Vibe Coding Rules skills
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/../../.claude/lib/common.sh"
#

# Source additional libraries
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load platform compatibility
if [[ -f "${LIB_DIR}/platform.sh" ]]; then
    source "${LIB_DIR}/platform.sh"
fi

# Load validation functions
if [[ -f "${LIB_DIR}/validation.sh" ]]; then
    source "${LIB_DIR}/validation.sh"
fi

# Load git utilities
if [[ -f "${LIB_DIR}/git.sh" ]]; then
    source "${LIB_DIR}/git.sh"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_debug() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        echo -e "${DIM}[DEBUG]${NC} $1" >&2
    fi
}

log_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

log_section() {
    echo ""
    echo -e "${BOLD}${CYAN}=== $1 ===${NC}"
    echo ""
}

# Error handling
die() {
    log_error "$1"
    exit "${2:-1}"
}

# Check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Check if multiple commands exist
check_commands() {
    local missing=()
    for cmd in "$@"; do
        if ! command_exists "$cmd"; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required commands: ${missing[*]}"
        return 1
    fi
    return 0
}

# Project type detection
detect_project_type() {
    local project_root="${1:-$(pwd)}"

    # Check for Python
    if [[ -f "${project_root}/pyproject.toml" ]] || \
       [[ -f "${project_root}/setup.py" ]] || \
       [[ -f "${project_root}/requirements.txt" ]] || \
       [[ -f "${project_root}/Pipfile" ]] || \
       [[ -f "${project_root}/poetry.lock" ]]; then
        echo "python"
        return 0
    fi

    # Check for Node.js/TypeScript
    if [[ -f "${project_root}/package.json" ]] || \
       [[ -f "${project_root}/package-lock.json" ]] || \
       [[ -f "${project_root}/yarn.lock" ]] || \
       [[ -f "${project_root}/pnpm-lock.yaml" ]]; then
        # Check if TypeScript
        if [[ -f "${project_root}/tsconfig.json" ]] || \
           { [[ -d "${project_root}/src" ]] && find "${project_root}/src" -maxdepth 3 -name "*.ts" 2>/dev/null | head -1 | grep -q .; }; then
            echo "typescript"
        else
            echo "nodejs"
        fi
        return 0
    fi

    # Check for Go
    if [[ -f "${project_root}/go.mod" ]] || \
       [[ -f "${project_root}/go.sum" ]]; then
        echo "go"
        return 0
    fi

    # Check for Rust
    if [[ -f "${project_root}/Cargo.toml" ]]; then
        echo "rust"
        return 0
    fi

    # Check for Java/Kotlin (Android)
    if [[ -f "${project_root}/pom.xml" ]] || \
       [[ -f "${project_root}/build.gradle" ]] || \
       [[ -f "${project_root}/build.gradle.kts" ]] || \
       [[ -f "${project_root}/settings.gradle" ]] || \
       [[ -f "${project_root}/settings.gradle.kts" ]]; then
        echo "java"
        return 0
    fi

    # Check for Ruby
    if [[ -f "${project_root}/Gemfile" ]] || \
       [[ -f "${project_root}/Rakefile" ]]; then
        echo "ruby"
        return 0
    fi

    # Check for PHP
    if [[ -f "${project_root}/composer.json" ]]; then
        echo "php"
        return 0
    fi

    # Check for .NET
    if [[ -f "${project_root}/project.json" ]] || \
       find "${project_root}" -maxdepth 2 -name "*.csproj" | head -1 | grep -q .; then
        echo "dotnet"
        return 0
    fi

    echo "unknown"
    return 0
}

# Get project root directory
get_project_root() {
    local dir="$(pwd)"

    while [[ "$dir" != "/" ]]; do
        if [[ -d "${dir}/.git" ]] || \
           [[ -f "${dir}/CLAUDE.md" ]] || \
           [[ -f "${dir}/package.json" ]] || \
           [[ -f "${dir}/pyproject.toml" ]] || \
           [[ -f "${dir}/go.mod" ]] || \
           [[ -f "${dir}/Cargo.toml" ]]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done

    echo "$(pwd)"
}

# Confirm action
confirm() {
    local prompt="$1"
    local default="${2:-n}"

    if [[ "$default" == "y" ]]; then
        prompt="$prompt [Y/n]"
    else
        prompt="$prompt [y/N]"
    fi

    read -p "$prompt " response

    if [[ -z "$response" ]]; then
        response="$default"
    fi

    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Print header
print_header() {
    local title="$1"
    local width=60

    local line
    line=$(printf "%*s" $width | tr ' ' '=')
    local title_text="  $title  "
    local pad=$(( (width - ${#title_text}) / 2 ))
    [[ $pad -lt 0 ]] && pad=0
    local rpad=$(( width - pad - ${#title_text} ))
    [[ $rpad -lt 0 ]] && rpad=0

    echo ""
    printf "${BOLD}${CYAN}%s${NC}\n" "$line"
    printf "${BOLD}${CYAN}%*s%s%*s${NC}\n" $pad "" "$title_text" $rpad ""
    printf "${BOLD}${CYAN}%s${NC}\n" "$line"
    echo ""
}

# Print table
print_table() {
    local data=("$@")
    local max_width=0

    # Find max width
    for row in "${data[@]}"; do
        local width=${#row}
        if [[ $width -gt $max_width ]]; then
            max_width=$width
        fi
    done

    # Print table
    for row in "${data[@]}"; do
        echo "  $row"
    done
}

# Check if running in git repository
is_git_repo() {
    git rev-parse --is-inside-work-tree &> /dev/null
}

# Get current git branch
get_git_branch() {
    if is_git_repo; then
        git branch --show-current
    else
        echo "unknown"
    fi
}

# Get git remote URL
get_git_remote() {
    if is_git_repo; then
        git remote get-url origin 2>/dev/null || echo "unknown"
    else
        echo "unknown"
    fi
}

# Format number with commas
format_number() {
    printf "%'d" "$1"
}

# Human readable file size
human_size() {
    local bytes=$1
    local units=('B' 'KB' 'MB' 'GB' 'TB')

    if [[ $bytes -lt 1024 ]]; then
        echo "${bytes}B"
        return
    fi

    local unit=0
    local size=$bytes

    while [[ $size -ge 1024 && $unit -lt 4 ]]; do
        size=$((size / 1024))
        unit=$((unit + 1))
    done

    echo "${size}${units[$unit]}"
}

# Progress bar
show_progress() {
    local current=$1
    local total=$2
    local width=50

    if [[ $total -le 0 ]]; then
        return 0
    fi

    local percent=$((current * 100 / total))
    local filled=$((width * current / total))

    printf "\r["
    printf "%${filled}s" | tr ' ' '='
    printf "%$((width - filled))s" | tr ' ' '-'
    printf "] %3d%%" $percent

    if [[ $current -eq $total ]]; then
        echo ""
    fi
}

# Spinner for long operations
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'

    while kill -0 $pid 2>/dev/null; do
        for i in $(seq 0 3); do
            echo -ne "\r${spinstr:$i:1}"
            sleep $delay
        done
    done
    echo -ne "\r"
}

# Get script directory
get_script_dir() {
    echo "$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
}

# Check if file exists and is readable
check_file() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        log_error "File not found: $file"
        return 1
    fi

    if [[ ! -r "$file" ]]; then
        log_error "File not readable: $file"
        return 1
    fi

    return 0
}

# Backup file
backup_file() {
    local file="$1"
    local backup_suffix="${2:-.bak}"

    if [[ -f "$file" ]]; then
        local backup="${file}${backup_suffix}"

        # 중복 방지 - 카운터 추가
        local counter=1
        while [[ -f "$backup" ]]; do
            backup="${file}${backup_suffix}.${counter}"
            ((counter++))
        done

        cp "$file" "$backup"
        log_info "Backup created: $backup"
    fi
}

# Note: get_os() is defined in platform.sh (sourced above) and re-exported below.

# Get architecture
get_arch() {
    case "$(uname -m)" in
        x86_64|amd64)  echo "amd64";;
        i386|i686)     echo "386";;
        arm64|aarch64) echo "arm64";;
        arm*)          echo "arm";;
        *)             echo "unknown";;
    esac
}

# ═══════════════════════════════════════════════════════════════════════════
# Upgrade Check Functions (for auto-upgrade on skill first run)
# ═══════════════════════════════════════════════════════════════════════════

# Check for available upgrades (non-blocking, throttled to once per day)
# Returns: 0 if upgrade available, 1 if up to date, 2 if check skipped
check_upgrade_available() {
    local project_root="${1:-$(get_project_root)}"
    local force_check="${2:-false}"

    # Skip if not a git repo
    if [[ ! -d "${project_root}/.git" ]]; then
        return 2
    fi

    # Upgrade state directory
    local upgrade_state_dir="${project_root}/.claude/.upgrade"
    local last_check_file="${upgrade_state_dir}/.last_check"
    local check_interval=86400  # 24 hours

    mkdir -p "$upgrade_state_dir"

    # Check throttle (unless forced)
    if [[ "$force_check" != "true" ]] && [[ -f "$last_check_file" ]]; then
        local last_check now elapsed
        last_check=$(cat "$last_check_file" 2>/dev/null || echo "0")
        now=$(date +%s)
        elapsed=$((now - last_check))

        if [[ $elapsed -lt $check_interval ]]; then
            return 2  # Skip, recently checked
        fi
    fi

    # Record check time
    date +%s > "$last_check_file"

    # Get current version
    local current_version="unknown"
    if [[ -f "${project_root}/.claude/version" ]]; then
        current_version=$(cat "${project_root}/.claude/version")
    elif [[ -f "${project_root}/CLAUDE.md" ]]; then
        # 첫 번째 'v<숫자>' 만 잡도록 anchor + 비-v 문자 클래스로 greedy 매칭 방지
        current_version=$(sed -nE 's/^[^v]*v([0-9]+\.[0-9.]+).*/\1/p' "${project_root}/CLAUDE.md" 2>/dev/null | head -1)
    fi

    # Get latest version from git tags (run in subshell to preserve caller CWD)
    local latest_version="unknown"

    latest_version=$(
        cd "$project_root" || exit 1
        if git fetch --tags origin >/dev/null 2>&1; then
            git describe --tags --abbrev=0 2>/dev/null || echo "unknown"
        else
            echo "unknown"
        fi
    )

    # Compare versions
    if [[ "$current_version" != "unknown" ]] && [[ "$latest_version" != "unknown" ]]; then
        # Remove 'v' prefix
        current_version="${current_version#v}"
        latest_version="${latest_version#v}"

        # Split and compare
        local IFS=.
        local i cur_parts=($current_version) lat_parts=($latest_version)

        for ((i=0; i<${#cur_parts[@]} || i<${#lat_parts[@]}; i++)); do
            local cur=$((10#${cur_parts[i]:-0}))
            local lat=$((10#${lat_parts[i]:-0}))
            if ((cur < lat)); then
                # Upgrade available
                echo ""
                echo -e "${YELLOW}[!]${NC} ${BOLD}Vibe Coding Rules update available${NC}"
                echo -e "   Current: ${DIM}${current_version}${NC} → Latest: ${GREEN}${latest_version}${NC}"
                echo -e "   Run: ${CYAN}/monggle-upgrade${NC} to update"
                echo ""
                return 0
            elif ((cur > lat)); then
                # Current is newer than latest; no upgrade
                return 1
            fi
        done
    fi

    return 1  # Up to date
}

# Auto-check upgrade on skill load (recommended for skills)
# Usage: add this to skill preamble: auto_check_upgrade
auto_check_upgrade() {
    # Only check if UPGRADE_CHECK env var is not set to "false"
    if [[ "${UPGRADE_CHECK:-true}" != "false" ]]; then
        check_upgrade_available >/dev/null 2>&1 || true
    fi
}

# ── Version SSOT — VERSION 파일이 유일한 정본 ──────────────────────────────
# 폴백: env override → repo의 VERSION → 글로벌설치는 ~/.claude/.repo_path → git tag
get_toolkit_version() {
    [[ -n "${MONGGLE_TOOLKIT_VERSION:-}" ]] && { printf '%s\n' "$MONGGLE_TOOLKIT_VERSION"; return; }
    local root="${PROJECT_ROOT:-}"
    [[ -z "$root" ]] && root="$(get_project_root 2>/dev/null)"
    if [[ -n "$root" && -f "${root}/VERSION" ]]; then tr -d '[:space:]' < "${root}/VERSION"; return; fi
    if [[ -f "${HOME}/.claude/.repo_path" ]]; then
        local r; r="$(cat "${HOME}/.claude/.repo_path" 2>/dev/null)"
        [[ -n "$r" && -f "$r/VERSION" ]] && { tr -d '[:space:]' < "$r/VERSION"; return; }
    fi
    if command -v git >/dev/null 2>&1; then
        local t; t="$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')"
        [[ -n "$t" ]] && { printf '%s\n' "$t"; return; }
    fi
    echo unknown
}

# 버전 정본(VERSION)에서 정적 파생물을 동기화. 인자: $1=repo root, $2=version.
# 헤더 라인에만 앵커링하므로 본문의 "(v2.4)" 기능 도입 표기는 보존된다.
sync_version_artifacts() {
    local root="$1" ver="$2"
    [[ -z "$ver" || "$ver" == "unknown" ]] && return 0
    [[ -d "$root/.claude" ]] && printf '%s\n' "$ver" > "$root/.claude/version"
    # CLAUDE.md/README 헤더 치환은 Python으로 처리한다. BSD sed는 한글·이모지·손상
    # 바이트가 섞인 CLAUDE.md에서 'illegal byte sequence'로 실패하기 때문이다.
    # 헤더 라인에만 앵커링하므로 본문의 "(v2.4)" 기능 도입 표기는 보존된다.
    if command -v python3 >/dev/null 2>&1; then
        VER="$ver" ROOT="$root" python3 - <<'PY'
import os, re
ver = os.environ["VER"]; root = os.environ["ROOT"]
def patch(path, pattern, repl):
    try:
        data = open(path, "rb").read()
    except OSError:
        return
    text = data.decode("utf-8", errors="surrogateescape")
    text = re.sub(pattern, repl, text, count=0, flags=re.M)
    open(path, "wb").write(text.encode("utf-8", errors="surrogateescape"))
patch(f"{root}/CLAUDE.md", r'^(# Vibe Coding Rules )v[0-9]+\.[0-9]+(?:\.[0-9]+)?', rf'\g<1>v{ver}')
for rd in ("README.md", "README_EN.md"):
    patch(f"{root}/{rd}", r'version-[0-9]+\.[0-9]+(?:\.[0-9]+)?-blue', f'version-{ver}-blue')
PY
    else
        # 폴백(python3 없을 때): sed. CLAUDE.md에 손상 바이트가 없다는 전제.
        [[ -f "$root/CLAUDE.md" ]] && { LC_ALL=C sed -i.bak -E "s/^(# Vibe Coding Rules )v[0-9]+\.[0-9]+(\.[0-9]+)?/\1v${ver}/" "$root/CLAUDE.md" 2>/dev/null; rm -f "$root/CLAUDE.md.bak"; }
        local rd
        for rd in "$root/README.md" "$root/README_EN.md"; do
            [[ -f "$rd" ]] && { LC_ALL=C sed -i.bak -E "s#version-[0-9]+\.[0-9]+(\.[0-9]+)?-blue#version-${ver}-blue#" "$rd" 2>/dev/null; rm -f "${rd}.bak"; }
        done
    fi
}

# Export upgrade functions
export -f check_upgrade_available auto_check_upgrade

# Export functions
export -f get_toolkit_version sync_version_artifacts
export -f log_info log_success log_error log_warn log_debug log_step log_section
export -f die command_exists check_commands
export -f detect_project_type get_project_root
export -f confirm print_header print_table
export -f is_git_repo get_git_branch get_git_remote
export -f format_number human_size show_progress spinner
export -f get_script_dir check_file backup_file
export -f get_os get_arch
