#!/bin/bash
#
# msg.sh - monggle: Message utility
#
# Claude와 대화하듯이 자연스럽게 작업을 진행하는 모드
#
# Usage: /msg
#

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

# 순수 대화 모드: 디스크에 아무것도 쓰지 않음 (세션 기록/뇌 저장 비활성화)

# 세션 시작
msg_start() {
    clear
    echo ""
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}${BOLD}  💬 대화모드 (Message Mode)${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}Commands:${NC}"
    echo "  /help    - 도움말"
    echo "  /exit    - 종료"
    echo ""
    echo -e "${GREEN}✅ 대화모드 시작 (나갈 때는 /exit)${NC}"
    echo ""
}

# 도움말
msg_help() {
    echo ""
    echo -e "${CYAN}💬 대화모드 명령어${NC}"
    echo ""
    echo "기본:"
    echo "  /help        - 도움말"
    echo "  /exit        - 종료"
    echo "  /clear       - 화면 정리"
    echo ""
    echo "빠른 명령:"
    echo "  /debug       - 디버깅"
    echo "  /test        - 테스트"
    echo "  /review      - 리뷰"
    echo ""
}

# 메인 루프
msg_loop() {
    msg_start

    while true; do
        # 프롬프트
        echo -n -e "${BOLD}💬 ${NC}"
        read -r input

        # 빈 입력 무시
        [[ -z "$input" ]] && continue

        # 종료
        if [[ "$input" == "/exit" ]] || [[ "$input" == "/quit" ]] || [[ "$input" == "q" ]]; then
            echo ""
            echo -e "${GREEN}✅ 대화모드 종료${NC}"
            break
        fi

        # 내부 명령어
        case "$input" in
            /help|--help|-h)
                msg_help
                ;;

            /clear)
                clear
                ;;

            /debug*)
                # /debug 전달 - 실제 실행은 Claude에게 맡김
                echo -e "${BLUE}[Executing]${NC} $input"
                break
                ;;

            /test*|/review*|/qa*)
                echo -e "${BLUE}[Executing]${NC} $input"
                break
                ;;

            *)
                # 일반 입력 - Claude에게 전달
                break
                ;;
        esac
    done
}

# 실행
msg_loop
