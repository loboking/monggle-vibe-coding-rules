#!/bin/bash
#
# test.sh - monggle: Test runner
#
# Usage: /test [options]
#   /test            # 전체 QA 테스트
#   /test --report   # 보고서만 (수정 없음)
#   /test --quick    # 빠른 스모크 테스트
#   /test --format   # 출력 형식 지정
#

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 뇌 코어 로드
BRAIN_ROOT="${HOME}/.claude/brain"
if [[ -f "$BRAIN_ROOT/brain-core.sh" ]]; then
    source "$BRAIN_ROOT/brain-core.sh"
fi

# 인자 파싱
case "${1:-full}" in
    full|--all|--report|--quick|--smoke)
        TEST_MODE="$1"
        shift || true
        ;;
    *)
        TEST_MODE="full"
        ;;
esac

case "$TEST_MODE" in
    full|--all)
        # 전체 QA - qa
        echo -e "${CYAN}✅ Full QA Mode${NC}"
        echo ""
        if type brain_query_by_tags &>/dev/null; then
            echo -e "${BLUE}📚 관련 기억:${NC}"
            brain_query_by_tags "pattern,test,qa" 3 2>/dev/null || true
            echo ""
        fi
        exec "${0%/*}/smart-qa.sh" "$@"
        ;;

    --report)
        # 보고서만 - qa-only
        echo -e "${CYAN}📋 Report Only Mode${NC}"
        echo ""
        exec "${0%/*}/smart-qa.sh" --report "$@"
        ;;

    --quick|--smoke)
        # 빠른 테스트
        echo -e "${CYAN}⚡ Quick Smoke Test${NC}"
        echo ""
        exec "${0%/*}/smart-qa.sh" --quick "$@"
        ;;

    *)
        echo -e "${YELLOW}알 수 없는 테스트 모드: $TEST_MODE${NC}"
        echo ""
        echo "지원하는 모드:"
        echo "  /test            # 전체 QA"
        echo "  /test --report   # 보고서만"
        echo "  /test --quick    # 빠른 테스트"
        exit 1
        ;;
esac
