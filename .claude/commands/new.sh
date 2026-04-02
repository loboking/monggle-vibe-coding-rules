#!/bin/bash
#
# new.sh - Quick PRD Creation Alias
#
# Usage: /new <description>
#
# Examples:
#   /new 사용자 인증 기능
#   /new API 서버 개발
#   /new 로그인 버그 수정
#

set -eo pipefail

# Colors
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INIT_SCRIPT="${SCRIPT_DIR}/prd.sh"

# PRD 타입 자동 감지
detect_type() {
    local input="$1"

    if echo "$input" | grep -qiE "api|endpoint|rest|graphql"; then
        echo "api"
    elif echo "$input" | grep -qiE "bug|버그|에러|오류|fix|고치"; then
        echo "bug"
    elif echo "$input" | grep -qiE "refactor|리팩토링|개선|최적화"; then
        echo "refactor"
    elif echo "$input" | grep -qiE "hotfix|긴급|즉시|urgent"; then
        echo "hotfix"
    elif echo "$input" | grep -qiE "experiment|실험|poc"; then
        echo "experiment"
    elif echo "$input" | grep -qiE "migration|마이그레이션|스키마|db"; then
        echo "migration"
    elif echo "$input" | grep -qiE "ml|모델|학습|ai|인공지능"; then
        echo "ml"
    elif echo "$input" | grep -qiE "devops|배포|ci/cd|자동화|인프라"; then
        echo "devops"
    else
        echo "feature"
    fi
}

# 메인
main() {
    local description="$*"

    if [[ -z "$description" ]]; then
        echo "Usage: /new <설명>"
        echo ""
        echo "Examples:"
        echo "  /new 사용자 인증 기능"
        echo "  /new API 서버 개발"
        echo "  /new 로그인 버그 수정"
        exit 1
    fi

    # 타입 자동 감지
    local prd_type
    prd_type=$(detect_type "$description")

    # 헤더
    echo ""
    echo -e "${CYAN}${BOLD}🚀 Quick PRD: $description${NC}"
    echo -e "${CYAN}${BOLD}   Type: $prd_type${NC}"
    echo ""

    # init.sh 실행
    exec "$INIT_SCRIPT" "$prd_type"
}

main "$@"
