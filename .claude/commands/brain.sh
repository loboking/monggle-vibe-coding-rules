#!/bin/bash
#
# brain.sh - monggle: 뇌 시스템 커맨드
#
# Usage: /brain [subcommand] [args]
#

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# 뇌 코어 로드
BRAIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../brain" && pwd)"
source "$BRAIN_ROOT/brain-core.sh"

# 서브커맨드
SUBCOMMAND="${1:-stats}"
shift || true

case "$SUBCOMMAND" in
    stats|이어서|continue|resume)
        if [[ "$SUBCOMMAND" == "이어서" ]] || [[ "$SUBCOMMAND" == "continue" ]] || [[ "$SUBCOMMAND" == "resume" ]]; then
            echo -e "${CYAN}${BOLD}🧠 최근 작업 내역 복원${NC}"
            echo ""
            # 가장 최근 context 뉴런 찾기
            recent_context=$(ls -t "$NEURONS_DIR/context"/*.md 2>/dev/null | head -1)
            if [[ -n "$recent_context" ]]; then
                echo "$(cat "$recent_context")"
            else
                echo "저장된 작업 내역이 없습니다."
            fi
        else
            echo -e "${CYAN}${BOLD}🧠 뇌 통계${NC}"
            echo ""
            brain_stats
        fi
        ;;

    save)
        # --tags 옵션 분리 (위치 인자에서 제거)
        brain_tags=""
        save_args=()
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --tags)
                    brain_tags="${2:-}"
                    shift 2 || shift
                    ;;
                --tags=*)
                    brain_tags="${1#--tags=}"
                    shift
                    ;;
                *)
                    save_args+=("$1")
                    shift
                    ;;
            esac
        done

        brain_type="${save_args[0]:-conversation}"
        brain_title="${save_args[1]:-}"
        brain_content="${save_args[2]:-}"
        # 4번째 위치 인자로도 태그 입력 가능 (--tags 미지정 시)
        if [[ -z "$brain_tags" ]]; then
            brain_tags="${save_args[3]:-}"
        fi

        if [[ -z "$brain_title" ]]; then
            echo -e "${YELLOW}사용법: /brain save <type> <title> <content> [tags]${NC}"
            echo -e "${YELLOW}       /brain save <type> <title> <content> --tags <tag1,tag2>${NC}"
            echo ""
            echo "타입: decision, pattern, bug, context, todo"
            exit 1
        fi

        # 내용이 없으면 표준 입력에서 읽기
        if [[ -z "$brain_content" ]]; then
            brain_content=$(cat)
        fi

        # 태그가 없으면 type 을 기본 태그로 (빈 태그 인덱스 방지)
        if [[ -z "$brain_tags" ]]; then
            brain_tags="$brain_type"
        fi

        neuron_id=$(brain_create_neuron "$brain_type" "$brain_title" "$brain_content" "$brain_tags")

        echo -e "${GREEN}✅ 뉴런 생성됨: $neuron_id${NC}"
        ;;

    query)
        tags="$1"

        if [[ -z "$tags" ]]; then
            echo -e "${YELLOW}사용법: /brain query <tag1,tag2,...>${NC}"
            exit 1
        fi

        echo -e "${CYAN}${BOLD}🔍 검색 결과: $tags${NC}"
        echo ""

        brain_query_by_tags "$tags"
        ;;

    recall)
        neuron_id="$1"

        if [[ -z "$neuron_id" ]]; then
            echo -e "${YELLOW}사용법: /brain recall <neuron_id>${NC}"
            exit 1
        fi

        brain_recall_neuron "$neuron_id"
        ;;

    forget)
        neuron_id="$1"

        if [[ -z "$neuron_id" ]]; then
            echo -e "${YELLOW}사용법: /brain forget <neuron_id>${NC}"
            exit 1
        fi

        brain_remove_neuron "$neuron_id"
        echo -e "${GREEN}✅ 뉴런 삭제됨: $neuron_id${NC}"
        ;;

    link)
        source="$1"
        target="$2"
        weight="${3:-0.5}"

        if [[ -z "$source" ]] || [[ -z "$target" ]]; then
            echo -e "${YELLOW}사용법: /brain link <source_id> <target_id> [weight]${NC}"
            exit 1
        fi

        brain_create_synapse "$source" "$target" "$weight"
        echo -e "${GREEN}✅ 시냅스 생성됨: $source → $target${NC}"
        ;;

    cleanup)
        echo -e "${YELLOW}망각된 기억 청소를 실행합니다...${NC}"
        read -p "계속하시겠습니까? [y/N] " confirm

        if [[ "$confirm" == "y" ]] || [[ "$confirm" == "Y" ]]; then
            brain_cleanup_forgotten
            echo -e "${GREEN}✅ 청소 완료${NC}"
        else
            echo "취소되었습니다."
        fi
        ;;

    init)
        brain_init
        echo -e "${GREEN}✅ 뇌 시스템 초기화 완료${NC}"
        ;;

    *)
        echo -e "${CYAN}${BOLD}🧠 뇌 시스템${NC}"
        echo ""
        echo "사용법:"
        echo "  /brain stats              - 통계 보기"
        echo "  /brain save <type> <title> - 뉴런 저장"
        echo "  /brain query <tags>       - 태그 검색"
        echo "  /brain recall <id>        - 뉴런 로드"
        echo "  /brain forget <id>        - 뉴런 삭제"
        echo "  /brain link <src> <tgt>   - 시냅스 연결"
        echo "  /brain cleanup            - 망각 청소"
        echo "  /brain init               - 초기화"
        echo ""
        echo "타입: decision, pattern, bug, context, todo, conversation"
        ;;
esac
