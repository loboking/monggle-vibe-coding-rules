#!/bin/bash
#
# prd.sh - monggle: PRD Creator
#
# Usage: /prd [type] [options]
#
# Options:
#   --non-interactive    비대화형 모드 (기본값 사용)
#   --output <path>      출력 파일 경로 지정
#   --language <lang>    PRD 언어 선택 (ko|en|zh|ja)
#   --auto-pipeline      PRD 생성 후 자동으로 pipeline 실행
#   --auto-lint          Pipeline 완료 후 자동으로 lint 실행
#
# Examples:
#   /prd feature
#   /prd api
#   /prd --non-interactive feature
#   /prd --language en feature
#   /prd --auto-pipeline feature
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
PRD_DIR="${PROJECT_ROOT}/prd"
PRD_CREATOR="${PROJECT_ROOT}/scripts/prd_creator.py"
SESSION_FILE="${PROJECT_ROOT}/.claude/.prd-session.json"
INSTALL_CONFIG="${PROJECT_ROOT}/.claude/config/install.conf"
USER_CONFIG="${PROJECT_ROOT}/.claude/config/user.conf"
PIPELINE_SCRIPT="${SCRIPT_DIR}/pipeline.sh"
AUTO_PIPELINE=false
AUTO_LINT=false

# Ensure PRD directory exists
mkdir -p "$PRD_DIR"
mkdir -p "$(dirname "$SESSION_FILE")"

# Load user config first (highest priority)
if [ -f "$USER_CONFIG" ]; then
    source "$USER_CONFIG"
fi

# Then load installation config (can be overridden by user config)
if [ -f "$INSTALL_CONFIG" ]; then
    source "$INSTALL_CONFIG"
fi

# Default language if not set (ko by default)
PRD_LANGUAGE="${PRD_LANGUAGE:-ko}"

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

# Show usage
show_usage() {
    echo ""
    echo -e "${CYAN}${BOLD}/prd - PRD Creator v3.0${NC}"
    echo ""
    echo "Usage:"
    echo "  /prd                     # 기본: 핑퐁 대화 모드 (구조화된 요구사항 수집)"
    echo "  /prd -f, --free          # 프리토킹 모드 (자유로운 대화)"
    echo "  /prd <type> [options]    # 특정 타입으로 직접 생성"
    echo ""
    echo "Types:"
    echo "  feature        - 새로운 기능 개발"
    echo "  bug            - 버그 수정"
    echo "  refactor       - 리팩토링"
    echo "  hotfix         - 긴급 핫픽스 (fast-track)"
    echo "  experiment     - 실험적 기능"
    echo "  api            - API 개발 (v2.4)"
    echo "  migration      - DB 마이그레이션 (v2.4)"
    echo "  ml             - ML 모델 개발 (v2.4)"
    echo "  devops         - DevOps 자동화 (v2.4)"
    echo ""
    echo "Options:"
    echo "  -p, --pingpong         핑퐁 대화 모드 (기본)"
    echo "  -f, --free             프리토킹 모드 (자유로운 대화)"
    echo "  --non-interactive      비대응형 모드 (타입 필수)"
    echo "  --output <path>        출력 파일 경로"
    echo "  --language <lang>      PRD 언어 (ko, en, zh, ja)"
    echo "  --auto-pipeline        PRD 생성 후 자동 pipeline 실행"
    echo "  --auto-lint            Pipeline 완료 후 자동 lint 실행"
    echo ""
    echo "Examples:"
    echo "  /prd                     # 핑퐁 모드 (구조화된 Q&A)"
    echo "  /prd -f                  # 프리토킹 모드 (자유 대화)"
    echo "  /prd feature            # 기능 PRD 직접 생성"
    echo "  /prd bug --output prd/fix-login.md"
    echo "  /prd api"
    echo ""
}

# Detect PRD type from user input (for fallback)
detect_type_from_input() {
    local input="$1"

    if echo "$input" | grep -qiE "bug|fix|error|crash|issue|broken"; then
        echo "bug"
    elif echo "$input" | grep -qiE "hotfix|urgent|critical|production|emergency"; then
        echo "hotfix"
    elif echo "$input" | grep -qiE "refactor|clean|reorganize|restructure"; then
        echo "refactor"
    elif echo "$input" | grep -qiE "experiment|test|try|prototype|poc"; then
        echo "experiment"
    elif echo "$input" | grep -qiE "api|endpoint|rest|graphql|api\]|webhook"; then
        echo "api"
    elif echo "$input" | grep -qiE "migration|database|schema|db|migrate"; then
        echo "migration"
    elif echo "$input" | grep -qiE "ml|machine learning|model|training|inference|ai model"; then
        echo "ml"
    elif echo "$input" | grep -qiE "devops|ci/cd|deploy|pipeline|automation|infra"; then
        echo "devops"
    else
        echo "feature"
    fi
}

# Save session context
save_session() {
    local prd_type="$1"
    local prd_file="$2"
    local status="$3"

    cat > "$SESSION_FILE" <<EOF
{
  "prd_type": "$prd_type",
  "prd_file": "$prd_file",
  "status": "$status",
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "project_root": "$PROJECT_ROOT"
}
EOF
}

# Check Python
check_python() {
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 not found"
        return 1
    fi

    # Check version
    PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
    PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
    PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)

    if [[ "$PYTHON_MAJOR" -lt 3 ]] || [[ "$PYTHON_MAJOR" -eq 3 && "$PYTHON_MINOR" -lt 8 ]]; then
        log_error "Python 3.8+ required, found $PYTHON_VERSION"
        return 1
    fi

    return 0
}

# ═══════════════════════════════════════════════════════════════════════════
# 핑퐁 대화 모드 (v3.0) - 아이디어 정리에서 PRD로
# ═══════════════════════════════════════════════════════════════════════════

# 대화 세션 저장소
PINGPONG_SESSION_DIR="${PROJECT_ROOT}/.claude/.pingpong"
PINGPONG_SESSION_FILE="${PINGPONG_SESSION_DIR}/current-session.json"

# 대화 세션 초기화
pingpong_init_session() {
    mkdir -p "$PINGPONG_SESSION_DIR"

    cat > "$PINGPONG_SESSION_FILE" << EOF
{
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "topic": "",
  "messages": [],
  "extracted": {
    "goal": "",
    "features": [],
    "constraints": [],
    "priorities": [],
    "stakeholders": []
  },
  "round": 0
}
EOF
}

# 대화 메시지 추가
pingpong_add_message() {
    local role="$1"
    local content="$2"

    local temp_file=$(mktemp)
    jq --arg role "$role" --arg content "$content" --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
        .messages += [{role: $role, content: $content, timestamp: $timestamp}] |
        .round += 1
    ' "$PINGPONG_SESSION_FILE" > "$temp_file"
    mv "$temp_file" "$PINGPONG_SESSION_FILE"
}

# 컨텍스트 기반 다음 질문 생성
pingpong_next_question() {
    local session_data=$(cat "$PINGPONG_SESSION_FILE")
    local round=$(echo "$session_data" | jq -r '.round')
    local last_user_msg=$(echo "$session_data" | jq -r '.messages | reverse | .[0] | select(.role == "user") | .content' 2>/dev/null || echo "")

    # 라운드별 질문
    case $round in
        0)
            echo "어떤 기능이나 아이디어를 계획하고 계신가요? 자유롭게 말씀해 주세요."
            ;;
        1)
            # 첫 답변 후 - 목표/기능 확인
            if echo "$last_user_msg" | grep -qiE "기능|만들|추가|개발|구현"; then
                echo "구체적으로 어떤 기능들을 생각하고 계신가요?"
            elif echo "$last_user_msg" | grep -qiE "문제|이슈|버그|에러|수정"; then
                echo "어떤 문제가 발생하고 있나요? 증상을 설명해 주시겠어요?"
            elif echo "$last_user_msg" | grep -qiE "디자인|UI|화면|변경"; then
                echo "어떤 스타일로 변경하고 싶으신가요?"
            else
                echo "조금 더 자세히 말씀해 주시겠어요? 어떤 목표를 가지고 계신가요?"
            fi
            ;;
        2)
            # 제약사항 확인
            echo "제약사항이 있나요? (예: 성능, 마감일약, 기술 스택, 리소스 등)"
            ;;
        3)
            # 우선순위 확인
            echo "우선순위는 어떻게 되시나요? (긴급 / 높음 / 보통 / 낮음)"
            ;;
        4)
            # 대상 사용자 확인
            echo "주요 사용자나 이해관계자는 누구인가요?"
            ;;
        *)
            # 추가 확인
            echo "추가로 말씀하고 싶으신 게 있으신가요? (없으면 /done 또는 빈 줄 입력)"
            ;;
    esac
}

# 핑퐁 대화 모드 실행
pingpong_mode() {
    echo ""
    echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║     💬 핑퐁 모드 - PRD 작성 (기본 모드)            ║${NC}"
    echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}자연스러운 대화로 PRD를 작성합니다.${NC}"
    echo "질문을 통해 요구사항을 명확히 정리해 드릴게요."
    echo ""
    echo -e "${YELLOW}명령어:${NC} /done (완료), /cancel (취소)"
    echo ""

    pingpong_init_session

    local round=0
    while true; do
        # 질문 표시
        local question=$(pingpong_next_question)
        echo -e "${MAGENTA}Q${NC}: $question"
        echo ""

        # 사용자 입력 받기
        read -p "> " user_input

        # 명령어 처리
        if [[ "$user_input" == "/done" ]] || [[ "$user_input" == "/cancel" ]] || [[ -z "$user_input" ]]; then
            if [[ "$user_input" == "/cancel" ]]; then
                echo ""
                log_info "취소되었습니다."
                return 1
            fi
            break
        fi

        # 메시지 저장
        pingpong_add_message "user" "$user_input"

        # 간단한 피드백
        echo ""
        echo -e "${GREEN}✓${NC} 입력받았습니다: $user_input"
        echo ""

        round=$((round + 1))
        if [[ $round -ge 6 ]]; then
            echo -e "${YELLOW}충분한 정보를 수집했습니다. /done를 입력하시면 PRD를 생성합니다.${NC}"
            echo ""
        fi
    done

    # PRD 생성을 위해 타입 결정
    local session_data=$(cat "$PINGPONG_SESSION_FILE")
    local all_messages=$(echo "$session_data" | jq -r '.messages[].content' | tr '\n' ' ')

    local prd_type=$(detect_type_from_input "$all_messages")

    echo ""
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}  PRD 생성 시작${NC}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "감지된 타입: ${GREEN}${prd_type}${NC}"
    echo ""

    # 세션 정보를 PRD 생성에 활용 (TODO: Python 스크립트에 전달)
    # 현재는 기존 방식대로 진행

    echo "$prd_type"
}

# ═══════════════════════════════════════════════════════════════════════════
# Main entry point
# ═══════════════════════════════════════════════════════════════════════════

main() {
    local prd_type=""
    local user_input=""
    local non_interactive=""
    local output_path=""
    local language="ko"
    local language_explicit=false  # --language 옵션 사용 여부
    local pingpong_mode=false  # v3.0: 핑퐁 모드 (기본값으로 동작)
    local freetalk_mode=false   # v3.0: 프리토킹 모드

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            --pingpong|-p)
                pingpong_mode=true
                shift
                ;;
            --free|-f)
                freetalk_mode=true
                shift
                ;;
            --non-interactive)
                non_interactive="--non-interactive"
                shift
                ;;
            --output)
                output_path="$2"
                shift 2
                ;;
            --language)
                language="$2"
                language_explicit=true
                shift 2
                ;;
            --auto-pipeline)
                AUTO_PIPELINE=true
                shift
                ;;
            --auto-lint)
                AUTO_LINT=true
                AUTO_PIPELINE=true  # --auto-lint implies --auto-pipeline
                shift
                ;;
            feature|bug|refactor|hotfix|experiment|api|migration|ml|devops)
                prd_type="$1"
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                user_input="$*"
                break
                ;;
        esac
    done

    # 프리토킹 모드 (v3.0) - brainstorm.sh 위임
    if [[ "$freetalk_mode" == true ]]; then
        local BRAINSTORM_CMD="${SCRIPT_DIR}/brainstorm.sh"
        if [[ -f "$BRAINSTORM_CMD" ]]; then
            exec "$BRAINSTORM_CMD" --free
        else
            log_error "brainstorm.sh not found"
            exit 1
        fi
    fi

    # 핑퐁 모드 진입 (v3.0)
    if [[ "$pingpong_mode" == true ]] || [[ -z "$prd_type" && -z "$non_interactive" ]]; then
        prd_type=$(pingpong_mode)
        if [[ -z "$prd_type" ]]; then
            log_info "취소되었습니다."
            exit 0
        fi
        # 핑퐁 모드에서 타입을 감지했으므로 계속 진행
    fi

    # Validate language
    case "$language" in
        ko|en|zh|ja)
            ;;
        *)
            log_error "Invalid language: $language (supported: ko, en, zh, ja)"
            exit 1
            ;;
    esac

    # Ask for language if not specified via --language option (only in interactive mode)
    if [[ "$language_explicit" == false ]] && [[ -z "$non_interactive" ]]; then
        echo ""
        echo -e "${CYAN}${BOLD}🌐 Select Language / 언어 선택${NC}"
        echo ""
        echo "  1) 한국어 (ko)"
        echo "  2) English (en)"
        echo "  3) 中文 (zh)"
        echo "  4) 日本語 (ja)"
        echo ""
        echo -e "${YELLOW}Press Enter for English (default)${NC}"
        echo ""
        read -p "Select / 선택 (1-4, Enter=English): " lang_choice

        case "$lang_choice" in
            1|ko|한국어) language="ko" ;;
            2|en|""|English) language="en" ;;
            3|zh|中文) language="zh" ;;
            4|ja|日本語) language="ja" ;;
            *)
                log_info "Defaulting to English"
                language="en"
                ;;
        esac
        log_info "Language set to: $language"
        echo ""
    fi

    # If no type provided, try to detect from input
    if [[ -z "$prd_type" ]]; then
        if [[ -n "$user_input" ]]; then
            prd_type=$(detect_type_from_input "$user_input")
        else
            echo ""
            echo -e "${CYAN}${BOLD}🚀 PRD Creator v2.4${NC}"
            echo ""
            log_info "PRD 타입을 선택해주세요:"
            echo ""
            echo "  1) feature    - 새로운 기능 개발"
            echo "  2) bug        - 버그 수정"
            echo "  3) refactor   - 리팩토링"
            echo "  4) hotfix     - 긴급 핫픽스"
            echo "  5) experiment - 실험적 기능"
            echo "  6) api        - API 개발"
            echo "  7) migration  - DB 마이그레이션"
            echo "  8) ml         - ML 모델 개발"
            echo "  9) devops     - DevOps 자동화"
            echo ""
            read -p "선택 (1-9): " choice

            case "$choice" in
                1) prd_type="feature" ;;
                2) prd_type="bug" ;;
                3) prd_type="refactor" ;;
                4) prd_type="hotfix" ;;
                5) prd_type="experiment" ;;
                6) prd_type="api" ;;
                7) prd_type="migration" ;;
                8) prd_type="ml" ;;
                9) prd_type="devops" ;;
                *)
                    log_error "잘못된 선택"
                    exit 1
                    ;;
            esac
        fi
    fi

    # Validate PRD type
    case "$prd_type" in
        feature|bug|refactor|hotfix|experiment|api|migration|ml|devops)
            ;;
        *)
            log_error "Invalid PRD type: $prd_type"
            show_usage
            exit 1
            ;;
    esac

    # Check Python
    if ! check_python; then
        log_error "PRD 생성을 위해 Python 3.8+가 필요합니다"
        exit 1
    fi

    # Build output path if not specified
    if [[ -z "$output_path" ]]; then
        timestamp=$(date +%Y%m%d-%H%M%S)
        output_path="${PRD_DIR}/${prd_type}-${timestamp}.md"
    fi

    # Save session
    save_session "$prd_type" "$output_path" "in_progress"

    # Call Python PRD creator
    echo ""
    log_info "PRD Creator 실행 중... (Language: $language)"
    echo ""

    local args="--type $prd_type --output $output_path --language $language $non_interactive"

    if python3 "$PRD_CREATOR" $args; then
        # Success
        save_session "$prd_type" "$output_path" "completed"

        echo ""
        log_success "PRD 생성 완료!"
        echo ""
        echo -e "  ${CYAN}파일:${NC} $output_path"
        echo ""

        # 자동 개선 제안 체크 (Harness)
        local improvement_script="${PROJECT_ROOT}/scripts/auto_improvement.py"
        if [[ -f "$improvement_script" ]]; then
            local improvement_output
            improvement_output=$(python3 "$improvement_script" analyze --alert critical --quiet 2>&1)
            local exit_code=$?

            if [[ $exit_code -ne 0 ]] && [[ -n "$improvement_output" ]]; then
                echo ""
                echo -e "${YELLOW}${BOLD}💡 하네스 개선 제안${NC}"
                echo "=" "=" 60
                echo "$improvement_output"
                echo "=" "=" 60
                echo -e "Run ${CYAN}/harness improve${NC} for details"
                echo ""
            fi
        fi

        # Auto-run pipeline if requested
        if [[ "$AUTO_PIPELINE" == true ]]; then
            echo ""
            log_step "자동 Pipeline 실행 시작..."
            echo ""

            if [[ -f "$PIPELINE_SCRIPT" ]]; then
                "$PIPELINE_SCRIPT" "$output_path"
                local pipeline_exit=$?

                if [[ $pipeline_exit -eq 0 ]] && [[ "$AUTO_LINT" == true ]]; then
                    echo ""
                    log_step "자동 Lint 실행 시작..."
                    echo ""

                    local lint_script="${SCRIPT_DIR}/lint-smart.sh"
                    if [[ -f "$lint_script" ]]; then
                        "$lint_script"
                    else
                        log_warn "lint-smart.sh를 찾을 수 없습니다"
                    fi
                fi
            else
                log_warn "pipeline.sh를 찾을 수 없습니다"
            fi
        else
            echo "다음 단계:"
            echo "  1. PRD 내용 확인 후 수정"
            echo "  2. /pipeline $output_path"
            echo "  또는 /prd --auto-pipeline feature"
            echo ""
        fi

        # Export for Claude
        export PRD_TYPE="$prd_type"
        export PRD_FILE="$output_path"
        export PRD_DIR="$PRD_DIR"

    else
        # Failed
        save_session "$prd_type" "$output_path" "failed"
        exit 1
    fi
}

# Run main
main "$@"
