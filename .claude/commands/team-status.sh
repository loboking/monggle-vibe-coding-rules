#!/bin/bash
#
# team-status.sh - 팀 상태 상세 보기
#
# 모든 팀의 현재 상태를 표(Table) 형태로 보여줍니다.
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

# find_project_root 함수 정의
find_project_root() {
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        if [[ -d "$dir/.git" ]] || [[ -f "$dir/CLAUDE.md" ]] || [[ -d "$dir/.claude/teams" ]]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    echo "$(cd "${SCRIPT_DIR}/../../" && pwd)"
}

PROJECT_ROOT="$(find_project_root)"
STATUS_SCRIPT="${PROJECT_ROOT}/scripts/team_state.py"

# 테이블 포맷
print_table() {
    local header="$1"
    local rows="$2"

    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${BOLD}               팀 상태 현황 (Team Status)                   ${NC} ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} $header ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════╣${NC}"
    echo "$rows"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# 메인 실행
main() {
    # cleanup-zombies 먼저 실행 (모든 출력 무시)
    if [[ -f "${SCRIPT_DIR}/cleanup-zombies.sh" ]]; then
        bash "${SCRIPT_DIR}/cleanup-zombies.sh" &>/dev/null || true
    fi

    # JSON 데이터 가져오기
    local json_data=$(python3 "$STATUS_SCRIPT" --json 2>/dev/null || echo "{}")

    # 팀이 없는 경우
    if [[ "$json_data" == "{}" ]]; then
        echo ""
        echo -e "${YELLOW}⚠️  등록된 팀이 없습니다.${NC}"
        echo ""
        return 0
    fi

    # 테이블 헤더
    local header="╟────────────────┬──────────┬───────────────────────────┬────────┬──────────╢"
    local separator="╞══════════════════╪══════════╪═════════════════════════════╪════════╪══════════╡"

    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${BOLD}                  팀 상태 현황 (Team Status)                ${NC} ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║  팀명           │ 상태     │ 작업                       │ 진행률 │ 세션     ║${NC}"
    echo -e "${CYAN}${separator}${NC}"

    # 각 팀 상태 파싱
    echo "$json_data" | python3 -c '
import sys, json
data = json.load(sys.stdin)

status_emoji = {
    "IDLE": "🟢",
    "BUSY": "🔵",
    "QUEUED": "🟡",
    "ERROR": "🔴",
    "CREATED": "⚪",
    "ARCHIVED": "⚫"
}

for name, state in data.items():
    s = state.get("status", "UNKNOWN").upper()
    task = state.get("current_task", {})

    task_desc = task.get("description", "")[:25] if task else ""
    pct = task.get("progress", 0) if task else 0
    progress = str(pct) + "%" if task else "-"
    locked_by = state.get("locked_by", "")[-10:] if state.get("locked_by") else ""

    emoji = status_emoji.get(s, "⚪")

    print(f"║  {emoji} {name:<12} │ {s:<8} │ {task_desc:<27} │ {progress:<6} │ {locked_by:<10} ║")
'

    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

}

main "$@"
