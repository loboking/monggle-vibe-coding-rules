#!/bin/bash
#
# team.sh - /team 디스패처
#
# 인자에 따라 적절한 team 하위 명령으로 위임합니다.
#
# Usage:
#   /team                # 인자 없음 → 상태 보기 (team-status.sh)
#   /team status         # 상태 보기 (team-status.sh)
#   /team run [args]     # 팀 기동 (team-run.sh)로 인자 위임
#   /team -h | --help    # 사용법
#

set -euo pipefail

# 명령 디렉토리 고정 (source 되는 wrapper의 SCRIPT_DIR 오염 방지를 위해 별도 변수 사용)
COMMANDS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
CYAN='\033[0;36m'
BOLD='\033[1m'
RED='\033[0;31m'
NC='\033[0m'

show_help() {
    printf '%b\n' "${BOLD}🤝 /team${NC} - 가상 개발팀 디스패처

${CYAN}Usage:${NC}
  /team [command] [options]

${CYAN}Commands:${NC}
  status            팀 상태 현황 보기 (기본값, 인자 없을 때)
  run [args]        가상 개발팀 기동 (team-run.sh로 위임)
  -h, --help        이 도움말 표시

${CYAN}Examples:${NC}
  /team                          # 팀 상태 보기
  /team status                   # 팀 상태 보기
  /team run                      # 최근 PRD 자동 감지 후 팀 기동
  /team run prd/feature.md       # 특정 PRD로 팀 기동
  /team run --visualize          # 팀 구조 시각화"
}

main() {
    local sub="${1:-status}"

    case "$sub" in
        run)
            shift
            exec bash "${COMMANDS_DIR}/team-run.sh" "$@"
            ;;
        status)
            shift || true
            exec bash "${COMMANDS_DIR}/team-status.sh" "$@"
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}알 수 없는 명령: ${sub}${NC}" >&2
            echo "" >&2
            show_help >&2
            exit 1
            ;;
    esac
}

main "$@"
