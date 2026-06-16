#!/bin/bash
#
# /monggle-upgrade - Vibe Coding Rules 업그레이드 체크
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
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

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
    # Try multiple sources for version
    if [[ -f "$PROJECT_ROOT/.claude/version" ]]; then
        cat "$PROJECT_ROOT/.claude/version"
    elif [[ -f "$PROJECT_ROOT/VERSION" ]]; then
        cat "$PROJECT_ROOT/VERSION"
    elif [[ -f "$PROJECT_ROOT/CLAUDE.md" ]]; then
        sed -nE 's/.*Version:.*v([0-9.]+).*/\1/p' "$PROJECT_ROOT/CLAUDE.md" 2>/dev/null | head -1
    else
        echo "unknown"
    fi
}

# Get latest version from GitHub (if git repo)
get_latest_version() {
    # Try GitHub API first (faster, no network if cached)
    local repo="loboking/monggle-vibe-coding-rules"
    local api_url="https://api.github.com/repos/${repo}/releases/latest"

    if command -v curl &> /dev/null; then
        local tag=$(curl -s --connect-timeout 3 "$api_url" 2>/dev/null | grep -o '"tag_name": *"[^"]*"' | cut -d'"' -f4)
        if [[ -n "$tag" ]]; then
            echo "$tag"
            return 0
        fi
    elif command -v wget &> /dev/null; then
        local tag=$(wget -qO- --timeout=3 "$api_url" 2>/dev/null | grep -o '"tag_name": *"[^"]*"' | cut -d'"' -f4)
        if [[ -n "$tag" ]]; then
            echo "$tag"
            return 0
        fi
    fi

    # Fallback to git fetch
    if [[ ! -d "$PROJECT_ROOT/.git" ]]; then
        echo "unknown"
        return 1
    fi

    cd "$PROJECT_ROOT"

    # Try to get latest tag
    if git fetch --tags origin >/dev/null 2>&1; then
        git describe --tags --abbrev=0 2>/dev/null || echo "unknown"
    else
        echo "unknown"
    fi
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
