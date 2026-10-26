#!/bin/bash
#
# help.sh - 대화형 도움말 시스템
#
# 카테고리별 스킬 검색
# /help [카테고리] 또는 /help --search <키워드>
#
# Usage:
#   /help                    # 전체 목록 (카테고리별)
#   /help debug             # 디버그 스킬만
#   /help --search "test"    # 검색
#   /help --list             # 간단 목록
#

set -eo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# 스킬 데이터: skill|category|description
SKILL_DATA="
debug|debug|일반 디버깅, 버그 원인 파악
bottleneck|debug|성능 병목, 최적화 (/debug-perf)
front-bugfix|debug|프론트엔드 (JS, React) (/debug-web)
css-bugfix|debug|CSS 전용 (스타일, 레이아웃) (/debug-css)
mem-check|debug|메모리 누수, OOM (/debug-m)
qa|qa|QA 테스트 (fix 포함)
qa-only|qa|보고서만 (수정 없음) (/qa --report)
review|review|PR diff 리뷰
code-reviewer|review|코드 품질 (SOLID, 보안) (/review-code)
arch-review|review|아키텍처 리뷰 (/review-arch)
verify|review|AI 응답 검증 (읽기 전용)
prd|core|PRD 생성 (기획서 작성)
gate|core|PRD 유효성 검사 (/prd 검증)
pipeline|core|전체 에이전트 파이프라인 실행
trace|core|실행 로그 추적
stats|core|파이프라인 통계/현황
audit|analysis|보안 점검, 취약점 스캔
security|analysis|보안성 검증 (OWASP, STRIDE) (/verify --safety)
complexity|analysis|코드 복잡도 분석
impact|analysis|영향도 분석, 사이드 이펙트 예측
api-docs|docs|API 문서 자동 생성
changelog|docs|Git 커밋 기반 CHANGELOG 생성
readme-sync|docs|README 동기화
weekly-recap|docs|주간 회고
bump|git|버전 업 + 태그 생성
push-safe|git|안전한 Git push + PR 생성
quick|dev|빠른 핫픽스
format-check|dev|코드 포맷 검사만
lint-smart|dev|프로젝트 자동 감지 린터
bench|utils|벤치마크 실행/비교
profile|utils|성능 프로파일링
save-point|utils|작업 상태 저장/복구
auto-compact|utils|자동 컴팩트 on/off (80% 기준)
brainstorm|utils|아이디어 브레인스토밍 (→ PRD)
brain|utils|뇌 시스템 (뉴런/시냅스 저장)
init|config|초기화 마법사
mode|config|작업 모드 변경 (solo/team)
monggle-upgrade|config|Vibe Coding Rules 업그레이드
duo|toolkit|Claude + Gemini 협업 (빠름)
run|toolkit|스마트 오케스트레이터
super|toolkit|슈퍼 프롬프트 생성
gemini|toolkit|Gemini AI 호출
product-manager|toolkit|프로덕트 매니저 (PRD, 사용자 스토리, 우선순위)
tech-doc-writer|toolkit|기술 문서 작성 (README, API, 가이드)
docs|docs|문서 인덱스/검색/상태 (docs index|search|status)
"

# 카테고리 이름
get_category_name() {
    case "$1" in
        debug) echo "🔍 디버그" ;;
        qa) echo "✅ QA" ;;
        review) echo "👁️ 리뷰" ;;
        core) echo "⚙️ 핵심" ;;
        analysis) echo "📊 분석" ;;
        docs) echo "📝 문서" ;;
        git) echo "🔧 Git" ;;
        dev) echo "💻 개발" ;;
        utils) echo "🛠️ 유틸리티" ;;
        config) echo "⚙️ 설정" ;;
        toolkit) echo "🧰 툴킷" ;;
        *) echo "$1" ;;
    esac
}

# 헤더 출력
print_header() {
    echo ""
    echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║     Vibe Coding Rules - 도움말              ║${NC}"
    echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════╝${NC}"
    echo ""
}

# 카테고리별 스킬 목록
print_by_category() {
    local target_category="${1:-}"

    local prev_cat=""
    while IFS='|' read -r skill category desc; do
        # 빈 라인 건너뜀
        [[ -z "$skill" ]] && continue

        # 필터링
        if [[ -n "$target_category" ]] && [[ "$category" != "$target_category" ]]; then
            continue
        fi

        # 카테고리 헤더
        if [[ "$category" != "$prev_cat" ]]; then
            echo ""
            echo -e "${BOLD}$(get_category_name "$category")${NC}"
            prev_cat="$category"
        fi

        # 별칭 처리
        local alias=""
        case "$skill" in
            bottleneck) alias=" (/debug-perf)" ;;
            front-bugfix) alias=" (/debug-web)" ;;
            css-bugfix) alias=" (/debug-css)" ;;
            mem-check) alias=" (/debug-m)" ;;
            qa-only) alias=" (/qa --report)" ;;
            code-reviewer) alias=" (/review-code)" ;;
            arch-review) alias=" (/review-arch)" ;;
        esac

        echo -e "  ${GREEN}/$skill${alias}${NC} - $desc"
    done <<< "$SKILL_DATA"
    echo ""
}

# 검색 기능
search_skills() {
    local keyword="$1"
    local found=0

    echo -e "${BOLD}검색어: '$keyword'${NC}"
    echo ""

    while IFS='|' read -r skill category desc; do
        # 빈 라인 건너뜀
        [[ -z "$skill" ]] && continue

        if [[ "$skill" == *"$keyword"* ]] || [[ "$desc" == *"$keyword"* ]]; then
            echo -e "  ${GREEN}/$skill${NC} [$(get_category_name "$category")] - $desc"
            ((found++))
        fi
    done <<< "$SKILL_DATA"

    if [[ $found -eq 0 ]]; then
        echo -e "${YELLOW}검색 결과가 없습니다${NC}"
    else
        echo ""
        echo -e "${CYAN}$found개 결과${NC}"
    fi
}

# 간단 목록
print_simple_list() {
    echo -e "${BOLD}사용 가능한 스킬:${NC}"
    echo ""

    local count=0
    while IFS='|' read -r skill category desc; do
        # 빈 라인 건너뜀
        [[ -z "$skill" ]] && continue

        echo -en "  ${GREEN}/$skill${NC}   "
        ((count++))
        # 3개마다 줄바꿈
        if [[ $((count % 3)) -eq 0 ]]; then
            echo ""
        fi
    done <<< "$SKILL_DATA"
    echo ""
}

# 카테고리별 요약
print_summary() {
    echo -e "${BOLD}카테고리:${NC}"
    echo ""

    local categories="debug qa review core analysis docs git dev utils config toolkit"
    for cat in $categories; do
        local count=0
        while IFS='|' read -r skill category desc; do
            [[ -z "$skill" ]] && continue
            if [[ "$category" == "$cat" ]]; then
                ((count++))
            fi
        done <<< "$SKILL_DATA"
        echo -e "  $(get_category_name "$cat") ($count)"
    done
    echo ""
}

# 사용법
print_usage() {
    echo -e "${BOLD}사용법:${NC}"
    echo "  /help                    # 카테고리별 목록"
    echo "  /help debug             # 특정 카테고리만"
    echo "  /help --search <키워드>  # 검색"
    echo "  /help --list             # 간단 목록"
    echo "  /help --summary          # 카테고리 요약"
    echo ""
}

# 메인
main() {
    print_header

    case "${1:-}" in
        --search|-s)
            if [[ -z "${2:-}" ]]; then
                echo -e "${RED}검색어를 입력하세요${NC}"
                echo "Usage: /help --search <키워드>"
                return 1
            fi
            search_skills "$2"
            ;;
        --list|-l)
            print_simple_list
            ;;
        --summary)
            print_summary
            ;;
        -h|--help)
            print_usage
            ;;
        "")
            print_by_category
            print_summary
            echo -e "${CYAN}자세한 도움말: /help --help${NC}"
            ;;
        *)
            # 카테고리로 처리
            local found=0
            local categories="debug qa review core analysis docs git dev utils config toolkit"
            for cat in $categories; do
                if [[ "$cat" == "$1" ]]; then
                    print_by_category "$1"
                    found=1
                    break
                fi
            done
            if [[ $found -eq 0 ]]; then
                echo -e "${YELLOW}알 수 없는 카테고리: '$1'${NC}"
                echo ""
                print_summary
            fi
            ;;
    esac
}

main "$@"
