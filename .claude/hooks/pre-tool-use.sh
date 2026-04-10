#!/bin/bash
#
# pre-tool-use.sh - PRD Validation Hook v2.4 (Auto-Detect)
#
# 개발 작업 자동 감지 → PRD 모드 자동 실행
#
# Features:
# - 자연어에서 개발 의도 감지
# - PRD 타입 자동 분류
# - PRD가 없으면 자동으로 PRD 생성 시작
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
LOG_DIR="${PROJECT_ROOT}/logs"
PRD_DIR="${PROJECT_ROOT}/prd"
PRD_BACKUP_DIR="${PRD_DIR}/.backup"
LOG_FILE="${LOG_DIR}/prd-validation-$(date +%Y%m%d-%H%M%S).log"
TRIGGER_FILE="${PROJECT_ROOT}/.claude/.auto-prd-trigger"

# Ensure directories exist
mkdir -p "${LOG_DIR}"
mkdir -p "${PRD_BACKUP_DIR}"
mkdir -p "$(dirname "$TRIGGER_FILE")"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "${LOG_FILE}"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1" | tee -a "${LOG_FILE}"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "${LOG_FILE}"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1" | tee -a "${LOG_FILE}"
}

# Detect PRD type from natural language input
detect_prd_type_from_input() {
    local input="$1"

    # 순서 중요 - 더 구체적인 키워드 먼저

    # API 관련
    if echo "$input" | grep -qiE "api|endpoint|rest|graphql|웹api|api만들|api개발|api구현"; then
        echo "api"
        return 0
    fi

    # ML 관련
    if echo "$input" | grep -qiE "ml|machine learning|모델|학습|예측|분류|ai모델|인공지능"; then
        echo "ml"
        return 0
    fi

    # DB Migration 관련
    if echo "$input" | grep -qiE "migration|마이그레이션|스키마|db변경|데이터이전|table"; then
        echo "migration"
        return 0
    fi

    # DevOps 관련
    if echo "$input" | grep -qiE "devops|ci/cd|배포|파이프라인|자동화|인프라|deploy"; then
        echo "devops"
        return 0
    fi

    # Bug
    if echo "$input" | grep -qiE "bug|버그|에러|에러수정|오류|고쳐|fix|잘안"; then
        echo "bug"
        return 0
    fi

    # Refactor
    if echo "$input" | grep -qiE "refactor|리팩토링|개선|최적화|정리|구조|reorganize"; then
        echo "refactor"
        return 0
    fi

    # Hotfix
    if echo "$input" | grep -qiE "hotfix|긴급|즉시|urgent|critical|production|운영"; then
        echo "hotfix"
        return 0
    fi

    # Experiment
    if echo "$input" | grep -qiE "experiment|실험|poc|프로토타입|test|시도"; then
        echo "experiment"
        return 0
    fi

    # Default: feature
    echo "feature"
}

# Check if input indicates development work
is_development_work() {
    local input="$1"

    # 개발 키워드 (부정은 제외)
    local dev_keywords="개발|추가|만들|구현|생성|build|implement|create|add|write|코드|함수|클래스|기능|feature"

    # 제외 키워드 (설명/질문)
    local exempt_keywords="설명|어떻게|방법|가이드|explain|how to|what is|보여줘|show|알려줘|review|분석"

    # 제외 키워드가 있으면 개발 작업으로 간주하지 않음
    if echo "$input" | grep -qiE "$exempt_keywords"; then
        return 1
    fi

    # 개발 키워드가 있으면 개발 작업으로 간주
    if echo "$input" | grep -qiE "$dev_keywords"; then
        return 0
    fi

    return 1
}

# Find latest PRD
find_latest_prd() {
    if [[ ! -d "$PRD_DIR" ]]; then
        return 1
    fi

    local latest
    latest=$(find "$PRD_DIR" -maxdepth 1 -name "*.md" -type f 2>/dev/null | while read -r f; do stat -f "%m %N" "$f"; done | sort -n | tail -1 | cut -d' ' -f2-)

    if [[ -n "$latest" && -f "$latest" ]]; then
        echo "$latest"
        return 0
    fi

    return 1
}

# Check if PRD exists and is valid
check_prd_valid() {
    local prd_file="$1"

    if [[ ! -f "$prd_file" ]]; then
        return 1
    fi

    # 크기 검증
    local size
    size=$(stat -f%z "$prd_file" 2>/dev/null || stat -c%s "$prd_file" 2>/dev/null)

    if [[ $size -lt 100 ]]; then
        return 1
    fi

    # 필수 섹션 검증 (마크다운 헤더 확인)
    if ! grep -qE "^# |^## " "$prd_file"; then
        return 1
    fi

    # 프론트매터 확인
    if ! grep -q "^---" "$prd_file"; then
        return 1
    fi

    return 0
}

# Trigger PRD creation
trigger_prd_creation() {
    local input="$1"
    local prd_type
    prd_type=$(detect_prd_type_from_input "$input")

    # 트리거 파일 생성 (Claude가 감지하도록)
    cat > "$TRIGGER_FILE" <<EOF
{
  "action": "create_prd",
  "prd_type": "$prd_type",
  "user_input": "$input",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

    # 사용자 메시지
    echo ""
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}🚀 PRD 자동 생성 모드${NC}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BOLD}감지된 내용:${NC} $input"
    echo -e "${BOLD}PRD 타입:${NC} ${GREEN}$prd_type${NC}"
    echo ""
    echo -e "${YELLOW}PRD가 없습니다. PRD를 생성하고 시작하겠습니다.${NC}"
    echo ""

    # init.sh 실행
    local init_script="${SCRIPT_DIR}/../commands/init.sh"

    if [[ -f "$init_script" ]]; then
        bash "$init_script" "$prd_type"
        rm -f "$TRIGGER_FILE"
        return 0
    fi

    return 1
}

# Main entry point
main() {
    # 트리거 파일이 있으면 PRD 생성 중 -> 스킵
    if [[ -f "$TRIGGER_FILE" ]]; then
        return 0
    fi

    # 현재 모드 확인
    local config_file="${PROJECT_ROOT}/monggle.config.yaml"
    local current_mode="solo"

    if [[ -f "$config_file" ]]; then
        current_mode=$(grep "^mode:" "$config_file" 2>/dev/null | awk '{print $2}' | tr -d '"')
    fi

    # Solo 모드면 PRD 강제하지 않음
    if [[ "$current_mode" == "solo" ]]; then
        return 0
    fi

    # 사용자 입력 받기 (환경 변수나 인자)
    local user_input=""

    if [[ -n "${CLAUDE_USER_INPUT:-}" ]]; then
        user_input="$CLAUDE_USER_INPUT"
    elif [[ $# -gt 0 ]]; then
        user_input="$*"
    fi

    # 입력이 없으면 종료
    if [[ -z "$user_input" ]]; then
        return 0
    fi

    # 개발 작업인지 확인
    if ! is_development_work "$user_input"; then
        return 0
    fi

    # 최신 PRD 찾기
    local latest_prd
    latest_prd=$(find_latest_prd)

    # PRD가 없거나 유효하지 않으면 생성
    if [[ -z "$latest_prd" ]] || ! check_prd_valid "$latest_prd"; then
        trigger_prd_creation "$user_input"
        return $?
    fi

    # PRD가 있으면 통과
    log_info "PRD found: $latest_prd"
    return 0
}

# Run main
main "$@"
