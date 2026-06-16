#!/bin/bash
#
# debug.sh - monggle: 통합 디버깅 커맨드
#
# Usage: /debug [type] [options]
#   /debug            # 일반 디버깅
#   /debug --web      # 프론트엔드 (JS, React)
#   /debug --css      # CSS 전용
#   /debug --perf     # 성능 병목
#   /debug --mem      # 메모리 누수
#

set -euo pipefail

# 하네스 래퍼 로드 (자동 추적)
# 주의: skill-harness-wrapper.sh 가 SCRIPT_DIR 을 자기 경로로 덮어쓰므로,
# 디스패치에 쓸 commands 디렉터리는 오염되지 않는 별도 변수로 고정한다.
# COMMANDS_DIR 은 반드시 아래 source(하네스 래퍼) 호출 '이전'에 설정해야 한다. (순서 변경 금지)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMANDS_DIR="$SCRIPT_DIR"
source "${SCRIPT_DIR}/../brain/skill-harness-wrapper.sh" 2>/dev/null || true

# 스킬 종료 시 자동 기록 (trap)
trap 'type harness_skill_end &>/dev/null && harness_skill_end $?' EXIT

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 뇌 코어 로드 (스킬-뇌 통합)
BRAIN_ROOT="${HOME}/.claude/brain"
if [[ -f "$BRAIN_ROOT/brain-core.sh" ]]; then
    source "$BRAIN_ROOT/brain-core.sh"
fi

# 인자 파싱
DEBUG_TYPE="${1:-general}"

# 하네스 추적 시작
if type harness_skill_start &>/dev/null; then
    harness_skill_start "$@"
fi
shift || true

case "$DEBUG_TYPE" in
    general)
        # 일반 디버깅 - debug-master 는 LLM 에이전트(.md) 스킬이므로 안내로 위임
        echo -e "${CYAN}🔍 General Debug Mode${NC}"
        echo ""
        if type brain_query_by_tags &>/dev/null; then
            echo -e "${BLUE}📚 관련 기억:${NC}"
            brain_query_by_tags "bug,debug" 3 2>/dev/null || true
            echo ""
        fi
        echo "체계적 버그 분석은 LLM 에이전트 스킬을 사용하세요:"
        echo -e "  ${GREEN}/debug-master${NC}  - 과학적 방법론 기반 버그 분석"
        echo ""
        echo "성능/메모리 디버깅은 실행 스킬을 사용하세요:"
        echo -e "  ${GREEN}/debug --perf${NC}  - 성능 병목"
        echo -e "  ${GREEN}/debug --mem${NC}   - 메모리 누수"
        ;;

    --web|--frontend|--js|--react)
        # 프론트엔드 - front-bugfix 는 LLM 에이전트(.md) 스킬이므로 안내로 위임
        echo -e "${CYAN}🔍 Frontend Debug Mode${NC}"
        echo ""
        if type brain_query_by_tags &>/dev/null; then
            echo -e "${BLUE}📚 관련 기억:${NC}"
            brain_query_by_tags "bug,frontend,js" 3 2>/dev/null || true
            echo ""
        fi
        echo "프론트엔드 디버깅은 LLM 에이전트 스킬을 사용하세요:"
        echo -e "  ${GREEN}/debug-web${NC} 또는 ${GREEN}/debug-master${NC}"
        ;;

    --css|--style)
        # CSS - css-bugfix 는 LLM 에이전트(.md) 스킬이므로 안내로 위임
        echo -e "${CYAN}🎨 CSS Debug Mode${NC}"
        echo ""
        if type brain_query_by_tags &>/dev/null; then
            echo -e "${BLUE}📚 관련 기억:${NC}"
            brain_query_by_tags "bug,css,style" 3 2>/dev/null || true
            echo ""
        fi
        echo "CSS 디버깅은 LLM 에이전트 스킬을 사용하세요:"
        echo -e "  ${GREEN}/debug-css${NC} 또는 ${GREEN}/debug-master${NC}"
        ;;

    --perf|--performance|--bottleneck)
        # 성능 - bottleneck
        echo -e "${CYAN}⚡ Performance Debug Mode${NC}"
        echo ""
        if type brain_query_by_tags &>/dev/null; then
            echo -e "${BLUE}📚 관련 기억:${NC}"
            brain_query_by_tags "pattern,performance,optimization" 3 2>/dev/null || true
            echo ""
        fi
        exec "${COMMANDS_DIR}/bottleneck.sh" "$@"
        ;;

    --mem|--memory|--leak)
        # 메모리 - mem-check
        echo -e "${CYAN}💾 Memory Debug Mode${NC}"
        echo ""
        if type brain_query_by_tags &>/dev/null; then
            echo -e "${BLUE}📚 관련 기억:${NC}"
            brain_query_by_tags "bug,memory,leak" 3 2>/dev/null || true
            echo ""
        fi
        exec "${COMMANDS_DIR}/mem-check.sh" "$@"
        ;;

    *)
        # 알 수 없는 타입 - fuzzy matching
        echo -e "${YELLOW}알 수 없는 디버깅 타입: $DEBUG_TYPE${NC}"
        echo ""
        echo "지원하는 타입:"
        echo "  /debug            # 일반 디버깅"
        echo "  /debug --web      # 프론트엔드"
        echo "  /debug --css      # CSS"
        echo "  /debug --perf     # 성능"
        echo "  /debug --mem      # 메모리"
        echo ""
        echo "또는 직접 호출:"
        echo "  /debug-master   (LLM 에이전트)"
        echo "  /bottleneck     (실행 스킬)"
        echo "  /mem-check      (실행 스킬)"
        exit 1
        ;;
esac
