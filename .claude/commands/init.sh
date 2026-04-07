#!/bin/bash
#
# init.sh - Initial Setup Wizard for Claude Code
#
# Usage: /init [--reset]
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG_DIR="${PROJECT_ROOT}/.claude/config"
USER_CONFIG="${CONFIG_DIR}/user.conf"
SESSION_FILE="${PROJECT_ROOT}/.claude/.setup-session.json"

# Ensure config directory exists
mkdir -p "$CONFIG_DIR"
mkdir -p "$(dirname "$SESSION_FILE")"

# Logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_title() {
    echo ""
    echo -e "${CYAN}${BOLD}$1${NC}"
    echo ""
}

# Show current config
show_current_config() {
    if [ -f "$USER_CONFIG" ]; then
        source "$USER_CONFIG"
        echo -e "${YELLOW}현재 설정:${NC}"
        echo "  작업 모드: ${WORK_MODE:-설정 안됨}"
        echo "  PRD 언어: ${PRD_LANGUAGE:-설정 안됨}"
        echo "  기본 모델: ${DEFAULT_MODEL:-설정 안됨}"
        echo ""
    else
        echo -e "${YELLOW}설정 파일이 없습니다. 초기 설정을 진행합니다.${NC}"
        echo ""
    fi
}

# Save session
save_session() {
    cat > "$SESSION_FILE" <<EOF
{
  "work_mode": "$1",
  "prd_language": "$2",
  "default_model": "$3",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
}

# Ask question with default
ask_with_default() {
    local prompt="$1"
    local default="$2"
    local result

    echo -n "$prompt [$default]: "
    read -r result
    echo "${result:-$default}"
}

# Main setup
run_setup() {
    log_title "🎉 Claude Code 초기 설정"

    echo "이 설정은 한 번만 진행됩니다."
    echo "원하지 않으면 Ctrl+C로 종료하세요."
    echo ""

    # 1. Work Mode
    echo -e "${BOLD}1. 작업 환경${NC}"
    echo "  1) Solo - 혼자 작업"
    echo "  2) Team - 팀과 함께"
    echo ""
    read -p "선택 (1-2, Enter=1): " mode_choice

    case "$mode_choice" in
        2|team) WORK_MODE="team" ;;
        *) WORK_MODE="solo" ;;
    esac
    log_info "작업 모드: $WORK_MODE"
    echo ""

    # 2. PRD Language
    echo -e "${BOLD}2. PRD 언어${NC}"
    echo "  1) 한국어 (ko)"
    echo "  2) English (en)"
    echo "  3) 中文 (zh)"
    echo "  4) 日本語 (ja)"
    echo ""
    read -p "선택 (1-4, Enter=1): " lang_choice

    case "$lang_choice" in
        2|en) PRD_LANGUAGE="en" ;;
        3|zh) PRD_LANGUAGE="zh" ;;
        4|ja) PRD_LANGUAGE="ja" ;;
        *) PRD_LANGUAGE="ko" ;;
    esac
    log_info "PRD 언어: $PRD_LANGUAGE"
    echo ""

    # 3. Default Model
    echo -e "${BOLD}3. 기본 AI 모델${NC}"
    echo "  1) Haiku - 빠름 (단순 작업)"
    echo "  2) Sonnet - 균형 (권장)"
    echo "  3) Opus - 고품질 (복잡한 작업)"
    echo ""
    read -p "선택 (1-3, Enter=2): " model_choice

    case "$model_choice" in
        1|haiku) DEFAULT_MODEL="haiku" ;;
        3|opus) DEFAULT_MODEL="opus" ;;
        *) DEFAULT_MODEL="sonnet" ;;
    esac
    log_info "기본 모델: $DEFAULT_MODEL"
    echo ""

    # 4. Optional: Name
    echo -e "${BOLD}4. 사용자 이름 (선택)${NC}"
    echo "  커밋 메시지 등에 사용됩니다"
    echo ""
    USER_NAME=$(ask_with_default "이름" "Anonymous")

    # 5. Optional: Email
    echo ""
    echo -e "${BOLD}5. 이메일 (선택)${NC}"
    echo "  Git 설정에 사용됩니다"
    echo ""
    USER_EMAIL=$(ask_with_default "이메일" "")

    # Save config
    cat > "$USER_CONFIG" <<EOF
# Claude Code User Configuration
# Created: $(date +%Y-%m-%d)

# Work Mode
WORK_MODE=$WORK_MODE

# PRD Language (ko|en|zh|ja)
PRD_LANGUAGE=$PRD_LANGUAGE

# Default Model (haiku|sonnet|opus)
DEFAULT_MODEL=$DEFAULT_MODEL

# User Info
USER_NAME="$USER_NAME"
USER_EMAIL="$USER_EMAIL"
EOF

    # Save session
    save_session "$WORK_MODE" "$PRD_LANGUAGE" "$DEFAULT_MODEL"

    log_title "✅ 설정 완료!"

    echo -e "${GREEN}설정이 저장되었습니다:${NC} $USER_CONFIG"
    echo ""
    echo "  작업 모드: $WORK_MODE"
    echo "  PRD 언어: $PRD_LANGUAGE"
    echo "  기본 모델: $DEFAULT_MODEL"
    echo "  이름: $USER_NAME"
    if [ -n "$USER_EMAIL" ]; then
        echo "  이메일: $USER_EMAIL"
    fi
    echo ""
    echo -e "${CYAN}설정을 변경하려면:${NC} /init --reset"
    echo ""
}

# Reset config
reset_config() {
    if [ -f "$USER_CONFIG" ]; then
        echo -e "${YELLOW}현재 설정을 백업 중...${NC}"
        cp "$USER_CONFIG" "${USER_CONFIG}.backup.$(date +%Y%m%d%H%M%S)"
        rm -f "$USER_CONFIG"
        log_success "설정이 초기화되었습니다. /init로 다시 설정하세요."
    else
        log_info "설정 파일이 없습니다."
    fi
}

# Main entry point
main() {
    local reset=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --reset|-r)
                reset=true
                shift
                ;;
            --help|-h)
                echo "Usage: /init [--reset]"
                echo ""
                echo "Options:"
                echo "  --reset    설정 초기화 후 재설정"
                echo ""
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Handle reset
    if [[ "$reset" == true ]]; then
        reset_config
        if [ ! -f "$USER_CONFIG" ]; then
            run_setup
        fi
        exit 0
    fi

    # Check if config exists
    if [ -f "$USER_CONFIG" ]; then
        log_title "📋 현재 설정"
        show_current_config

        echo -e "${YELLOW}설정을 변경하시겠습니까?${NC} [y/N]"
        read -r response

        if [[ "$response" =~ ^[Yy]$ ]]; then
            run_setup
        else
            log_info "설정을 유지합니다."
        fi
    else
        run_setup
    fi
}

# Run main
main "$@"
