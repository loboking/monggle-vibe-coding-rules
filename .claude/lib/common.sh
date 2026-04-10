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
           [[ -d "${project_root}/src" ]] && find "${project_root}/src" -name "*.ts" | head -1 | grep -q .; then
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

    echo ""
    printf "${BOLD}${CYAN}%*s${NC}\n" $width | tr ' ' '='
    printf "${BOLD}${CYAN}%s%*s${NC}\n" "  $title  " $width | tr ' ' '='
    printf "${BOLD}${CYAN}%*s${NC}\n" $width | tr ' ' '='
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

# Get OS type
get_os() {
    case "$(uname -s)" in
        Linux*)     echo "linux";;
        Darwin*)    echo "macos";;
        MINGW*|MSYS*|CYGWIN*) echo "windows";;
        *)          echo "unknown";;
    esac
}

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

# Export functions
export -f log_info log_success log_error log_warn log_debug log_step log_section
export -f die command_exists check_commands
export -f detect_project_type get_project_root
export -f confirm print_header print_table
export -f is_git_repo get_git_branch get_git_remote
export -f format_number human_size show_progress spinner
export -f get_script_dir check_file backup_file
export -f get_os get_arch
