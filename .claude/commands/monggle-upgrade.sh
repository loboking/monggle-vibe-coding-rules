#!/bin/bash
#
# /monggle-upgrade - Vibe Coding Rules 툴킷 자체 최신화 (업그레이드 진입점)
#
# 역할: 이 스크립트가 "툴킷 업그레이드"의 공식 진입점이다.
#   GitHub 최신 버전 확인 → git pull → install.sh 재실행(글로벌 동기화)까지 수행.
#   (cf. update.sh = 현재 작업 브랜치를 원격과 동기화하는 범용 git pull 도우미.
#        툴킷 업그레이드 목적이면 update 대신 이 스크립트를 사용한다.)
#
# Usage:
#   /monggle-upgrade              # 업그레이드 확인 및 설치
#   /monggle-upgrade --check-only # 확인만 하고 설치 안함
#   /monggle-upgrade --force      # 강제 업그레이드
#
# 스킬 최초 실행시 자동으로 업그레이드 체크를 수행합니다.
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# PROJECT_ROOT(툴킷 저장소) 결정 — 글로벌 설치 위치(~/.claude/commands)와 저장소가
# 분리될 수 있으므로 경로를 추정하지 않는다. 우선순위:
#   1) install.sh가 기록한 ~/.claude/.repo_path (가장 신뢰)
#   2) SCRIPT_DIR에서 위로 올라가며 .git 탐색 (저장소 안에서 직접 실행한 경우)
#   3) 기존 추정 (~/.claude/../..) — 최후 폴백
resolve_project_root() {
    local repo_file="$HOME/.claude/.repo_path"
    if [[ -f "$repo_file" ]]; then
        local p; p="$(cat "$repo_file" 2>/dev/null)"
        if [[ -n "$p" && -d "$p/.git" ]]; then echo "$p"; return; fi
    fi
    local d="$SCRIPT_DIR"
    while [[ "$d" != "/" && -n "$d" ]]; do
        if [[ -d "$d/.git" ]]; then echo "$d"; return; fi
        d="$(dirname "$d")"
    done
    (cd "${SCRIPT_DIR}/../.." && pwd)
}
PROJECT_ROOT="$(resolve_project_root)"

# Upgrade state directory
UPGRADE_STATE_DIR="$PROJECT_ROOT/.claude/.upgrade"
LAST_CHECK_FILE="$UPGRADE_STATE_DIR/.last_check"
UPGRADE_LOG="$PROJECT_ROOT/.claude/.upgrade.log"
CHECK_INTERVAL=86400  # 24 hours (seconds)

# Logging
log_info() { echo -e "${BLUE}[→]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_step() { echo -e "${CYAN}${BOLD}$1${NC}"; }

# Print header
print_header() {
    clear
    echo ""
    echo -e "${MAGENTA}${BOLD}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}${BOLD}║   Vibe Coding Rules - Upgrade Checker         ║${NC}"
    echo -e "${MAGENTA}${BOLD}╚════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Check if upgrade check is needed (throttling)
should_check_upgrade() {
    mkdir -p "$UPGRADE_STATE_DIR"

    # Force check if requested
    if [[ "${1:-}" == "--force" ]] || [[ "${1:-}" == "--check" ]]; then
        return 0
    fi

    # Check if we've checked recently
    if [[ -f "$LAST_CHECK_FILE" ]]; then
        local last_check
        last_check=$(cat "$LAST_CHECK_FILE" 2>/dev/null || echo "0")
        local now
        now=$(date +%s)
        local elapsed=$((now - last_check))

        if [[ $elapsed -lt $CHECK_INTERVAL ]]; then
            # Recently checked, skip
            return 1
        fi
    fi

    return 0
}

# Record check time
record_check_time() {
    mkdir -p "$UPGRADE_STATE_DIR"
    date +%s > "$LAST_CHECK_FILE"
}

# Get current version from project
get_current_version() {
    # git 태그를 1순위로(릴리스의 신뢰원본). 그다음 git-추적되는 VERSION,
    # 마지막으로 CLAUDE.md. (.claude/version은 미추적이라 자주 어긋나므로 제외)
    if [[ -d "$PROJECT_ROOT/.git" ]]; then
        local tag
        tag=$(git -C "$PROJECT_ROOT" tag --list 'v*' 2>/dev/null | sort -V | tail -1)
        if [[ -n "$tag" ]]; then echo "${tag#v}"; return; fi
    fi
    if [[ -f "$PROJECT_ROOT/VERSION" ]]; then
        cat "$PROJECT_ROOT/VERSION"
    elif [[ -f "$PROJECT_ROOT/CLAUDE.md" ]]; then
        # LC_ALL=C.UTF-8 로 한글/이모지 포함 파일에서 'illegal byte sequence' 방지
        LC_ALL=C.UTF-8 grep -oE 'Version:[^0-9]*v?[0-9]+\.[0-9]+(\.[0-9]+)?' "$PROJECT_ROOT/CLAUDE.md" 2>/dev/null \
            | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1
    else
        echo "unknown"
    fi
}

# Get latest version from GitHub.
# 주의: releases/latest API 는 '릴리스로 발행된 것'만 반환하므로, 태그만 있고
# 릴리스가 안 된 더 높은 버전(예: v3.0.0)을 놓친다. 따라서 '모든 태그를 버전
# 정렬한 최신'과 '릴리스 최신'을 모두 구해 둘 중 더 높은 것을 반환한다.
get_latest_version() {
    local repo="loboking/monggle-vibe-coding-rules"
    local rel_tag="" git_tag=""

    # (a) 모든 태그 중 버전 정렬 최신 (가장 신뢰도 높음)
    if [[ -d "$PROJECT_ROOT/.git" ]]; then
        cd "$PROJECT_ROOT" 2>/dev/null || true
        git fetch --tags origin >/dev/null 2>&1 || true
        git_tag=$(git tag --list 'v*' 2>/dev/null | sort -V | tail -1)
    fi

    # (b) 릴리스 API 최신 (참고용)
    local api_url="https://api.github.com/repos/${repo}/releases/latest"
    if command -v curl &> /dev/null; then
        rel_tag=$(curl -s --connect-timeout 3 "$api_url" 2>/dev/null | grep -o '"tag_name": *"[^"]*"' | cut -d'"' -f4)
    elif command -v wget &> /dev/null; then
        rel_tag=$(wget -qO- --timeout=3 "$api_url" 2>/dev/null | grep -o '"tag_name": *"[^"]*"' | cut -d'"' -f4)
    fi

    # (c) 둘 중 버전이 높은 쪽 선택 (sort -V)
    local best
    best=$(printf '%s\n%s\n' "$git_tag" "$rel_tag" | grep -E '^v?[0-9]' | sort -V | tail -1)
    if [[ -n "$best" ]]; then
        echo "$best"
        return 0
    fi
    echo "unknown"
    return 1
}

# Compare versions (returns 0 if update available)
compare_versions() {
    local current="$1"
    local latest="$2"

    # Remove 'v' prefix
    current="${current#v}"
    latest="${latest#v}"

    # Handle unknown versions
    if [[ "$current" == "unknown" ]] || [[ "$latest" == "unknown" ]]; then
        return 1
    fi

    # Split and compare
    local IFS=.
    local i cur_parts=($current) lat_parts=($latest)

    for ((i=0; i<${#cur_parts[@]} || i<${#lat_parts[@]}; i++)); do
        local cur=$((10#${cur_parts[i]:-0}))
        local lat=$((10#${lat_parts[i]:-0}))
        if ((cur > lat)); then
            return 1  # Current is ahead, no update
        elif ((cur < lat)); then
            return 0  # Update available
        fi
    done

    return 1  # Up to date
}

# Check for updates
check_updates() {
    local current_version
    local latest_version

    current_version=$(get_current_version)
    latest_version=$(get_latest_version)

    log_info "Current version: ${CYAN}${current_version}${NC}"

    if [[ "$latest_version" == "unknown" ]]; then
        log_warning "Cannot check remote version (not a git repo or no network)"
        return 1
    fi

    log_info "Latest version: ${CYAN}${latest_version}${NC}"

    if compare_versions "$current_version" "$latest_version"; then
        echo ""
        log_step "📦 Update Available!"
        echo ""
        echo -e "${YELLOW}Current:${NC}  $current_version"
        echo -e "${GREEN}Latest:${NC}   $latest_version"
        echo ""
        return 0
    else
        log_success "Already up to date!"
        return 1
    fi
}

# Perform upgrade
do_upgrade() {
    log_info "Starting upgrade..."

    cd "$PROJECT_ROOT" || {
        log_error "Cannot access project directory"
        return 1
    }

    # Check for uncommitted changes
    if ! git diff --quiet HEAD 2>/dev/null; then
        log_warning "Uncommitted changes detected, stashing..."
        if git stash push -m "auto-stash before upgrade" >/dev/null 2>&1; then
            local stash_created=true
        fi
    fi

    # Pull latest
    log_info "Pulling latest changes..."
    if git pull origin main --rebase >/dev/null 2>&1; then
        log_success "Upgrade complete!"
    else
        log_error "Failed to pull updates"
        if [[ "${stash_created:-false}" == "true" ]]; then
            git stash pop >/dev/null 2>&1 || true
        fi
        return 1
    fi

    # Restore stashed changes
    if [[ "${stash_created:-false}" == "true" ]]; then
        log_info "Restoring stashed changes..."
        git stash pop >/dev/null 2>&1 || true
    fi

    # Run install script to update global commands
    log_info "Updating global commands..."
    if [[ -f "$PROJECT_ROOT/install.sh" ]]; then
        bash "$PROJECT_ROOT/install.sh" >/dev/null 2>&1 || true
    fi

    # 새로 받은 스킬의 frontmatter(name/description) 자동 보정 — "업데이트만 하면 인식"을 보장
    local ensure_fm="$HOME/.claude/lib/ensure_skill_frontmatter.py"
    if [[ -f "$ensure_fm" ]] && command -v python3 &>/dev/null; then
        log_info "Verifying skill metadata..."
        python3 "$ensure_fm" "$PROJECT_ROOT/.claude/skills" 2>/dev/null || true
    fi

    # Log upgrade history
    mkdir -p "$(dirname "$UPGRADE_LOG")"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Upgraded to $(get_current_version)" >> "$UPGRADE_LOG"

    log_success "Vibe Coding Rules upgraded successfully!"
    log_info "Please restart your terminal or run: source ~/.zshrc"
}

# Show usage
show_usage() {
    echo ""
    echo "Usage: /monggle-upgrade [options]"
    echo ""
    echo "Options:"
    echo "  --check-only    Only check for updates, don't upgrade"
    echo "  --force         Force upgrade check (bypass time limit)"
    echo "  --help, -h      Show this help"
    echo ""
}

# Main
check_only=false
force_check=false

for arg in "$@"; do
    case "$arg" in
        --check-only) check_only=true ;;
        --force|--check) force_check=true ;;
        --help|-h)
            show_usage
            exit 0
            ;;
    esac
done

print_header

# Check if we should check for upgrades
if ! should_check_upgrade "$([[ "$force_check" == true ]] && echo "--force" || echo "")"; then
    log_info "Recently checked, skipping (check once per day)"
    log_info "Use --force to bypass"
    exit 0
fi

# Record check time
record_check_time

# Check for updates
if check_updates; then
    if [[ "$check_only" == true ]]; then
        log_info "Use /monggle-upgrade to install"
        exit 0
    fi

    # Ask for confirmation
    echo -n "Upgrade now? [Y/n] "
    read -r response
    case "$response" in
        [nN][oO]|[nN]) exit 0 ;;
    esac

    echo ""
    do_upgrade
else
    log_success "No updates available"
fi
