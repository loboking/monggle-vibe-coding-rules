#!/bin/bash
#
# prd.sh - Interactive PRD Creation Command v2.4
#
# Usage: /prd [type] [options]
#
# Options:
#   --non-interactive    비대화형 모드 (기본값 사용)
#   --output <path>      출력 파일 경로 지정
#   --language <lang>    PRD 언어 선택 (ko|en|zh)
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

set -eo pipefail

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
PIPELINE_SCRIPT="${SCRIPT_DIR}/pipeline.sh"
AUTO_PIPELINE=false
AUTO_LINT=false

# Ensure PRD directory exists
mkdir -p "$PRD_DIR"
mkdir -p "$(dirname "$SESSION_FILE")"

# Load installation config if exists
if [ -f "$INSTALL_CONFIG" ]; then
    source "$INSTALL_CONFIG"
fi

# Default language if not set
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
    echo -e "${CYAN}${BOLD}/prd - PRD Creator v2.4${NC}"
    echo ""
    echo "Usage:"
    echo "  /prd <type> [options]"
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
    echo "  --non-interactive    비대화형 모드"
    echo "  --output <path>      출력 파일 경로"
    echo "  --language <lang>    PRD 언어 (ko, en, zh)"
    echo "  --auto-pipeline      PRD 생성 후 자동 pipeline 실행"
    echo "  --auto-lint          Pipeline 완료 후 자동 lint 실행"
    echo ""
    echo "Examples:"
    echo "  /prd feature"
    echo "  /prd api"
    echo "  /prd --auto-pipeline feature"
    echo "  /prd --auto-lint bug"
    echo "  /prd --output prd/my-feature.md feature"
    echo "  /prd --language en feature"
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

    if [ "$PYTHON_MAJOR" -lt 3 ] || ([ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 8 ]); then
        log_error "Python 3.8+ required, found $PYTHON_VERSION"
        return 1
    fi

    return 0
}

# Main entry point
main() {
    local prd_type=""
    local user_input=""
    local non_interactive=""
    local output_path=""
    local language="ko"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
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

    # Validate language
    case "$language" in
        ko|en|zh)
            ;;
        *)
            log_error "Invalid language: $language (supported: ko, en, zh)"
            exit 1
            ;;
    esac

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
