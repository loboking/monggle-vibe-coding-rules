#!/bin/bash
#
# team-run.sh - monggle: LangGraph 가상 개발팀 기동
#
# Multi-Agent Team 시스템으로 유기적인 협업 실행
#
# Usage:
#   /team-run                    # 자동 PRD 감지
#   /team-run prd/feature.md     # 특정 PRD 실행
#   /team-run --max-retries 5    # 최대 재시도 설정
#   /team-run --visualize        # 팀 구조 시각화
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

# Project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# ── Version SSOT (VERSION 파일이 유일한 정본) ──────────────────────────────
get_toolkit_version() {
    [[ -n "${MONGGLE_TOOLKIT_VERSION:-}" ]] && { printf '%s\n' "$MONGGLE_TOOLKIT_VERSION"; return; }
    if [[ -f "${PROJECT_ROOT}/VERSION" ]]; then tr -d '[:space:]' < "${PROJECT_ROOT}/VERSION"; return; fi
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
TOOLKIT_VERSION="$(get_toolkit_version || echo unknown)"

# Help
show_help() {
    cat << EOF
${BOLD}🤝 team-run${NC} - LangGraph 가상 개발팀

${CYAN}Usage:${NC}
  /team-run [prd_file] [options]

${CYAN}Examples:${NC}
  /team-run                      # 최근 PRD 자동 감지
  /team-run prd/feature.md       # 특정 PRD 실행
  /team-run --max-retries 5      # 최대 재시도 5회
  /team-run --visualize          # 팀 구조 시각화

${CYAN}Team Members:${NC}
  👨‍💼 Architect (Planner)  - PRD 분석 및 계획 수립
  🧑‍💻 Developer (Coder)    - 코드 구현
  🕵️ QA (Reviewer)         - 검증 및 피드백

${CYAN}Options:${NC}
  --max-retries N    최대 재시도 횟수 (default: 3)
  --visualize        팀 구조 시각화
  --verbose          상세 로그 출력
  -h, --help         도움말 표시
EOF
}

# Parse args
PRD_PATH=""
MAX_RETRIES=3
VISUALIZE=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --max-retries)
            if [[ -z "${2:-}" || ! "$2" =~ ^[0-9]+$ ]]; then
                echo -e "${RED}--max-retries requires a numeric value${NC}"
                show_help
                exit 1
            fi
            MAX_RETRIES="$2"
            shift 2
            ;;
        --visualize)
            VISUALIZE=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            echo -e "${RED}Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
        *)
            PRD_PATH="$1"
            shift
            ;;
    esac
done

# Header
echo -e "${BLUE}${BOLD}"
echo "╔════════════════════════════════════════════════════════════╗"
printf "║          🤝 Monggle %-7s - 가상 개발팀                    ║\n" "v${TOOLKIT_VERSION}"
echo "║     LangGraph Multi-Agent Collaboration System            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check Python
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ python3가 설치되지 않았습니다.${NC}"
    exit 1
fi

# Check LangGraph
echo -e "${CYAN}🔍 LangGraph 설치 확인...${NC}"
if python3 -c "import langgraph" 2>/dev/null; then
    echo -e "${GREEN}✅ LangGraph가 설치되어 있습니다.${NC}"
else
    echo -e "${YELLOW}⚠️ LangGraph가 설치되지 않았습니다.${NC}"
    echo -e "${YELLOW}📦 설치하려면: pip install langgraph langchain-anthropic${NC}"
    echo -e "${YELLOW}🔄 선형 파이프라인 모드로 대체 실행합니다...${NC}"
fi

# PRD path 결정
if [[ -z "$PRD_PATH" ]]; then
    PRD_DIR="$PROJECT_ROOT/prd"
    if [[ -d "$PRD_DIR" ]]; then
        PRD_PATH=$(find "$PRD_DIR" -name "*.md" -type f -exec ls -t {} + 2>/dev/null | head -1)
        if [[ -z "$PRD_PATH" ]]; then
            echo -e "${RED}❌ PRD 파일을 찾을 수 없습니다.${NC}"
            exit 1
        fi
        echo -e "${CYAN}📋 자동 감지된 PRD: $PRD_PATH${NC}"
    else
        echo -e "${RED}❌ prd/ 디렉토리를 찾을 수 없습니다.${NC}"
        exit 1
    fi
else
    if [[ ! -f "$PRD_PATH" ]]; then
        echo -e "${RED}❌ PRD 파일을 찾을 수 없습니다: $PRD_PATH${NC}"
        exit 1
    fi
fi

# Build command
CMD_ARGS=("$PRD_PATH")
CMD_ARGS+=("--max-retries" "$MAX_RETRIES")

if [[ "$VISUALIZE" == true ]]; then
    CMD_ARGS+=("--visualize")
fi

if [[ "$VERBOSE" == true ]]; then
    CMD_ARGS+=("--verbose")
fi

# Execute
echo -e "${GREEN}🚀 가상 개발팀을 소집합니다...${NC}"
echo ""

EXIT_CODE=0
python3 "$PROJECT_ROOT/scripts/langgraph_team.py" "${CMD_ARGS[@]}" || EXIT_CODE=$?

# 결과
if [[ $EXIT_CODE -eq 0 ]]; then
    echo ""
    echo -e "${GREEN}${BOLD}✅ 팀 작업 완료!${NC}"
else
    echo ""
    echo -e "${RED}${BOLD}❌ 팀 작업 실패${NC}"
fi

exit $EXIT_CODE
