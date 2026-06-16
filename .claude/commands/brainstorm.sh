#!/bin/bash
#
# brainstorm.sh - monggle: 아이디어 정리 및 요구사항 수집
#
# 자연스러운 대화 형식으로 아이디어를 정리하고 PRD로 연계합니다.
#
# Usage: /brainstorm [topic] [options]
# Examples:
#   /brainstorm                    # 구조화된 모드로 시작
#   /brainstorm --free             # 프리토킹 모드 (자유로운 대화)
#   /brainstorm 로그인 기능        # 주제와 함께 시작
#   /brainstorm --to-prd           # 현재 세션을 PRD로 변환
#   /brainstorm --analyze          # 제약사항 분석 표시
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
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SESSION_DIR="${PROJECT_ROOT}/.claude/.brainstorm"
SESSION_FILE="${SESSION_DIR}/current-session.json"
EXPORT_FILE="${SESSION_DIR}/export.md"

# 세션 디렉토리 생성
mkdir -p "$SESSION_DIR"

# 로그 함수
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_brain() { echo -e "${MAGENTA}[🧠]${NC} $*"; }

# 사용법 표시
show_usage() {
    cat << EOF
${BOLD}아이디어 정리 모드 v3.0${NC}

사용법:
  /brainstorm [주제]         구조화된 모드로 시작
  /brainstorm --free, -f     프리토킹 모드 (자유로운 대화)
  /brainstorm --analyze      현재 세션 분석 (제약사항 등)
  /brainstorm --to-prd       현재 세션을 PRD로 변환
  /brainstorm --export       현재 세션을 markdown으로 내보내기
  /brainstorm --list         이전 세션 목록
  /brainstorm --clear        현재 세션 초기화

명령어 (대화 중):
  /analyze                   추출된 정보 분석 표시
  /constraints               제약사항만 표시
  /save                      현재까지 저장
  /prd                       PRD 생성 시작
  /done                      세션 종료

EOF
}

# 세션 초기화
init_session() {
    local topic="${1:-}"

    cat > "$SESSION_FILE" << EOF
{
  "session_id": "$(date +%s)",
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "topic": "$topic",
  "messages": [],
  "extracted_info": {
    "goal": "",
    "features": [],
    "constraints": [],
    "priorities": [],
    "stakeholders": [],
    "performance": [],
    "memory": [],
    "platform": [],
    "security": [],
    "design": [],
    "data": [],
    "priority": "",
    "deadline": ""
  },
  "status": "in_progress"
}
EOF

    if [[ -n "$topic" ]]; then
        add_message "system" "주제: $topic"
        extract_info "$topic"
        extract_constraints_advanced "$topic"
    fi
}

# 메시지 추가
add_message() {
    local role="$1"
    local content="$2"

    local temp_file=$(mktemp)
    jq --arg role "$role" --arg content "$content" --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
        .messages += [{"role": $role, "content": $content, "timestamp": $timestamp}]
    ' "$SESSION_FILE" > "$temp_file"
    mv "$temp_file" "$SESSION_FILE"
}

# ═══════════════════════════════════════════════════════════════════════════
# 고도화된 정보 추출 (v3.0)
# ═══════════════════════════════════════════════════════════════════════════

# 정보 추출 (간단 버전 - 기존 호환)
extract_info() {
    local text="$1"

    local temp_file=$(mktemp)

    # 제약사항 추출 키워드
    if echo "$text" | grep -qiE "성능|속도|빠름|O\(|n²|메모리|용량|제한|제약"; then
        jq '.extracted_info.constraints += ["성능/제약사항 언급됨"]' "$SESSION_FILE" > "$temp_file"
        mv "$temp_file" "$SESSION_FILE"
    fi

    # 우선순위 추출
    if echo "$text" | grep -qiE "긴급|우선|중요|P0|P1|빨리"; then
        jq '.extracted_info.priorities += ["우선순위 높음"]' "$SESSION_FILE" > "$temp_file"
        mv "$temp_file" "$SESSION_FILE"
    fi

    # 기능 키워드
    if echo "$text" | grep -qiE "기능|추가|만들|구현|개발"; then
        jq '.extracted_info.features += ["기능 개발"]' "$SESSION_FILE" > "$temp_file"
        mv "$temp_file" "$SESSION_FILE"
    fi
}

# 고도화된 제약사항 추출 (v3.0)
extract_constraints_advanced() {
    local text="$1"
    local temp_file=$(mktemp)

    # 성능 제약사항
    if echo "$text" | grep -qiE "O\(([1n]|log n|n log n|n²|2^n)\)"; then
        local time_complex=$(echo "$text" | grep -oE "O\([1nlog ]+\)" | head -1)
        jq --arg c "시간복잡도: $time_complex" '.extracted_info.performance += [$c]' "$SESSION_FILE" > "$temp_file"
        mv "$temp_file" "$SESSION_FILE"
    fi

    if echo "$text" | grep -qiE "([0-9]+ms|밀리초|초 내|latency|지연시간|응답시간|반응속도)"; then
        local latency=$(echo "$text" | grep -oE "([0-9]+ms|([0-9]+\.?[0-9]*)초)" | head -1)
        jq --arg c "지연시간: $latency" '.extracted_info.performance += [$c]' "$SESSION_FILE" > "$temp_file"
        mv "$temp_file" "$SESSION_FILE"
    fi

    if echo "$text" | grep -qiE "TPS|QPS|처리량|吞吐량|초당.*요청"; then
        jq '.extracted_info.performance += ["높은 처리량 요구"]' "$SESSION_FILE" > "$temp_file"
        mv "$temp_file" "$SESSION_FILE"
    fi

    # 메모리 제약사항
    if echo "$text" | grep -qiE "메모리.*([0-9]+(GB|MB|KB)|제한|상한)"; then
        local mem=$(echo "$text" | grep -oE "([0-9]+(GB|MB|KB))" | head -1)
        jq --arg c "메모리: $mem" '.extracted_info.memory += [$c]' "$SESSION_FILE" > "$temp_file"
        mv "$temp_file" "$SESSION_FILE"
    fi

    if echo "$text" | grep -qiE "저메모리|메모리.*적게|메모리.*효율"; then
        jq '.extracted_info.memory += ["메모리 효율성 중요"]' "$SESSION_FILE" > "$temp_file"
        mv "$temp_file" "$SESSION_FILE"
    fi

    # 플랫폼/브라우저 제약
    if echo "$text" | grep -qiE "IE|Internet Explorer|익스플로러"; then
        jq '.extracted_info.platform += ["IE 지원"]' "$SESSION_FILE" > "$temp_file"
        mv "$temp_file" "$SESSION_FILE"
    fi

    if echo "$text" | grep -qiE "모바일|앱|iOS|안드로이드|Android|responsive|반응형"; then
        jq '.extracted_info.platform += ["모바일/반응형"]' "$SESSION_FILE" > "$temp_file"
        mv "$temp_file" "$SESSION_FILE"
    fi

    if echo "$text" | grep -qiE "Chrome|Firefox|Safari|Edge|브라우저"; then
        jq '.extracted_info.platform += ["브라우저 호환성"]' "$SESSION_FILE" > "$temp_file"
        mv "$temp_file" "$SESSION_FILE"
    fi

    # 보안 제약
    if echo "$text" | grep -qiE "보안|암호화|인증|로그인|권한|auth|security|encrypt"; then
        jq '.extracted_info.security += ["인증/보안 필요"]' "$SESSION_FILE" > "$temp_file"
        mv "$temp_file" "$SESSION_FILE"
    fi

    if echo "$text" | grep -qiE "PII|개인정보|민감|GDPR"; then
        jq '.extracted_info.security += ["개인정보 보호"]' "$SESSION_FILE" > "$temp_file"
        mv "$temp_file" "$SESSION_FILE"
    fi

    # UI/UX 제약
    if echo "$text" | grep -qiE "심플|깔끔|minimal|미니멀"; then
        jq '.extracted_info.design += ["심플/미니멀"]' "$SESSION_FILE" > "$temp_file"
        mv "$temp_file" "$SESSION_FILE"
    fi

    if echo "$text" | grep -qiE "화려|다이내믹|animation|애니메이션"; then
        jq '.extracted_info.design += ["다이내믹/애니메이션"]' "$SESSION_FILE" > "$temp_file"
        mv "$temp_file" "$SESSION_FILE"
    fi

    # 기간 제약
    if echo "$text" | grep -qiE "내일|이번 주|금주|다음 주|금주|오늘 안|급함|긴급"; then
        jq '.extracted_info.deadline = "긴급"' "$SESSION_FILE" > "$temp_file"
        mv "$temp_file" "$SESSION_FILE"
    fi

    if echo "$text" | grep -qiE "P0|최우선|가장 중요|제일 중요"; then
        jq '.extracted_info.priority = "P0"' "$SESSION_FILE" > "$temp_file"
        mv "$temp_file" "$SESSION_FILE"
    elif echo "$text" | grep -qiE "P1|우선|중요"; then
        jq '.extracted_info.priority = "P1"' "$SESSION_FILE" > "$temp_file"
        mv "$temp_file" "$SESSION_FILE"
    fi

    # 데이터 제약
    if echo "$text" | grep -qiE "대용량|빅데이터|수백만|수천만|GB|TB"; then
        jq '.extracted_info.data += ["대용량 데이터"]' "$SESSION_FILE" > "$temp_file"
        mv "$temp_file" "$SESSION_FILE"
    fi

    if echo "$text" | grep -qiE "실시간|real-time|realtime|즉시"; then
        jq '.extracted_info.data += ["실시간 처리"]' "$SESSION_FILE" > "$temp_file"
        mv "$temp_file" "$SESSION_FILE"
    fi
}

# 추출된 제약사항 분석 표시
show_constraints_analysis() {
    if [[ ! -f "$SESSION_FILE" ]]; then
        log_error "활성 세션이 없습니다."
        return 1
    fi

    local session_data=$(cat "$SESSION_FILE")

    echo ""
    echo -e "${CYAN}${BOLD}📋 추출된 제약사항 분석${NC}"
    echo ""

    # 성능
    local performance=$(echo "$session_data" | jq -r '.extracted_info.performance // [] | if length == 0 then "없음" else join(", ") end')
    echo -e "${YELLOW}⚡ 성능:${NC} $performance"

    # 메모리
    local memory=$(echo "$session_data" | jq -r '.extracted_info.memory // [] | if length == 0 then "없음" else join(", ") end')
    echo -e "${YELLOW}💾 메모리:${NC} $memory"

    # 플랫폼
    local platform=$(echo "$session_data" | jq -r '.extracted_info.platform // [] | if length == 0 then "없음" else join(", ") end')
    echo -e "${YELLOW}🖥️  플랫폼:${NC} $platform"

    # 보안
    local security=$(echo "$session_data" | jq -r '.extracted_info.security // [] | if length == 0 then "없음" else join(", ") end')
    echo -e "${YELLOW}🔒 보안:${NC} $security"

    # 디자인
    local design=$(echo "$session_data" | jq -r '.extracted_info.design // [] | if length == 0 then "없음" else join(", ") end')
    echo -e "${YELLOW}🎨 디자인:${NC} $design"

    # 우선순위
    local priority=$(echo "$session_data" | jq -r '(.extracted_info.priority // "") | if . == "" then "미설정" else . end')
    echo -e "${YELLOW}🎯 우선순위:${NC} $priority"

    # 기간
    local deadline=$(echo "$session_data" | jq -r '(.extracted_info.deadline // "") | if . == "" then "미설정" else . end')
    echo -e "${YELLOW}📅 기간:${NC} $deadline"

    # 데이터
    local data=$(echo "$session_data" | jq -r '.extracted_info.data // [] | if length == 0 then "없음" else join(", ") end')
    echo -e "${YELLOW}📊 데이터:${NC} $data"

    echo ""
}

# 세션 분석 전체 표시
show_full_analysis() {
    if [[ ! -f "$SESSION_FILE" ]]; then
        log_error "활성 세션이 없습니다."
        return 1
    fi

    local session_data=$(cat "$SESSION_FILE")
    local topic=$(echo "$session_data" | jq -r '.topic')
    local msg_count=$(echo "$session_data" | jq -r '.messages | length')

    echo ""
    echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║     📊 세션 분석 보고서                       ║${NC}"
    echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════╝${NC}"
    echo ""

    echo -e "${BOLD}주제:${NC} $topic"
    echo -e "${BOLD}대화 수:${NC} ${msg_count}회"
    echo ""

    show_constraints_analysis

    # 메시지 요약
    echo -e "${BOLD}💬 대화 요약:${NC}"
    echo "$session_data" | jq -r '.messages[] | select(.role != "system") |
        "  \(.role): \(.content)"' | head -5
    local visible_count=$(echo "$session_data" | jq -r '[.messages[] | select(.role != "system")] | length')
    if [[ $visible_count -gt 5 ]]; then
        echo "  ... (외 $((visible_count - 5))개 메시지)"
    fi
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════
# 프리토킹 모드 (v3.0)
# ═══════════════════════════════════════════════════════════════════════════

# 프리토킹 모드 초기화
freetalk_init_session() {
    local topic="${1:-}"

    cat > "$SESSION_FILE" << EOF
{
  "session_id": "$(date +%s)",
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "mode": "freetalk",
  "topic": "$topic",
  "messages": [],
  "extracted_info": {
    "goal": "",
    "features": [],
    "constraints": [],
    "performance": [],
    "memory": [],
    "platform": [],
    "security": [],
    "design": [],
    "data": [],
    "priority": "",
    "deadline": ""
  },
  "status": "in_progress"
}
EOF

    if [[ -n "$topic" ]]; then
        add_message "system" "주제: $topic (프리토킹 모드)"
    fi
}

# 프리토킹 모드 시작
start_freetalk() {
    local topic="${1:-}"

    echo ""
    echo -e "${MAGENTA}${BOLD}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}${BOLD}║     🗣️  프리토킹 모드 (Free Talk)              ║${NC}"
    echo -e "${MAGENTA}${BOLD}╚════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}자유롭게 대화하세요.${NC}"
    echo "자연스러운 대화 흐름으로 아이디어를 정리합니다."
    echo ""
    echo -e "${YELLOW}명령어:${NC}"
    echo "  ${CYAN}/analyze${NC}   - 현재까지 추출된 정보 분석"
    echo "  ${CYAN}/constraints${NC} - 제약사항만 표시"
    echo "  ${CYAN}/prd${NC}       - PRD 생성으로 전환"
    echo "  ${CYAN}/done${NC}      - 세션 종료"
    echo ""

    freetalk_init_session "$topic"

    if [[ -n "$topic" ]]; then
        echo -e "${MAGENTA}주제: ${topic}${NC}"
        echo ""
        echo -e "${CYAN}이 주제에 대해 자유롭게 이야기해 주세요.${NC}"
    else
        echo -e "${CYAN}무엇이든 말씀해 주세요. 어떤 이야기든 좋습니다.${NC}"
    fi
    echo ""
}

# 프리토킹 질문 생성 (자연스러운 대화)
freetalk_next_response() {
    local session_data=$(cat "$SESSION_FILE")
    local msg_count=$(echo "$session_data" | jq '.messages | length')

    if [[ $msg_count -eq 0 ]]; then
        echo "아직 아무것도 없네요. 무슨 이야기를 하고 싶으신가요?"
        return
    fi

    # 마지막 사용자 메시지
    local last_user_msg=$(echo "$session_data" | jq -r '.messages | reverse | .[0] | select(.role == "user") | .content' 2>/dev/null || echo "")

    # 대화 맥락 기반 자연스러운 응답
    if echo "$last_user_msg" | grep -qiE "안녕|hello|hi|반갑"; then
        echo "안녕하세요! 오늘 어떤 이야기를 나눠볼까요?"
    elif echo "$last_user_msg" | grep -qiE "잘 모르겠|잘 안 생각나|모르겠"; then
        echo "괜찮아요. 천천히 생각해 봐요. 간단한 것부터 시작해 볼까요?"
    elif echo "$last_user_msg" | grep -qiE "음|글쎄|잠깐만|생각"; then
        echo "네, 천천히 생각하셔도 됩니다."
    elif [[ $msg_count -lt 3 ]]; then
        echo "흥미롭네요. 더 이야기해 주실래요?"
    elif [[ $msg_count -lt 6 ]]; then
        echo "그렇군요. 혹시 제약사항이나 조건 같은 것도 있나요?"
    else
        echo "내용이 잘 정리되고 있네요. /analyze로 분석해 볼까요?"
    fi
}

# 다음 질문 생성 (컨텍스트 기반)
generate_next_question() {
    local session_data=$(cat "$SESSION_FILE")
    local msg_count=$(echo "$session_data" | jq '.messages | length')

    # 첫 질문
    if [[ $msg_count -eq 0 ]]; then
        echo "어떤 아이디어를 정리하고 싶으신가요? 자유롭게 이야기해 주세요."
        return
    fi

    # 마지막 사용자 메시지 확인
    local last_user_msg=$(echo "$session_data" | jq -r '.messages | reverse | .[0] | select(.role == "user") | .content' 2>/dev/null || echo "")

    # 컨텍스트 기반 질문
    if echo "$last_user_msg" | grep -qiE "기능|만들|추가"; then
        echo "구체적으로 어떤 기능을 생각하고 계신가요?"
    elif echo "$last_user_msg" | grep -qiE "문제|이슈|버그|에러"; then
        echo "어떤 문제가 발생하고 있나요? 재현 가능한가요?"
    elif echo "$last_user_msg" | grep -qiE "사용자|고객|대상"; then
        echo "주요 사용자층은 누구인가요?"
    elif echo "$last_user_msg" | grep -qiE "디자인|UI|화면|페이지"; then
        echo "어떤 스타일을 원하시나요? (심플, 화려, 등등)"
    elif echo "$last_user_msg" | grep -qiE "데이터|DB|저장|관리"; then
        echo "어떤 데이터를 다루게 되나요?"
    elif echo "$last_user_msg" | grep -qiE "API|연동|외부|서비스"; then
        echo "어떤 외부 서비스와 연동이 필요한가요?"
    elif [[ $msg_count -lt 5 ]]; then
        echo "흥미롭네요. 더 자세히 말씀해 주시겠어요?"
    else
        echo "추가로 말씀하고 싶으신 게 있으신가요? (/prd로 PRD 생성 가능)"
    fi
}

# 대화 모드 시작
start_conversation() {
    local topic="${1:-}"

    echo ""
    echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║     🧠 아이디어 정리 모드                      ║${NC}"
    echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "자유롭게 아이디어를 이야기해 주세요."
    echo "완료되면 ${GREEN}/prd${NC}로 PRD를 생성할 수 있습니다."
    echo ""

    init_session "$topic"

    # 첫 질문
    local question=$(generate_next_question)
    echo -e "${MAGENTA}질문:${NC} $question"
    echo ""
}

# 세션 내보내기 (고도화)
export_session() {
    if [[ ! -f "$SESSION_FILE" ]]; then
        log_error "활성 세션이 없습니다."
        return 1
    fi

    local session_data=$(cat "$SESSION_FILE")
    local topic=$(echo "$session_data" | jq -r '.topic')
    local started_at=$(echo "$session_data" | jq -r '.started_at')
    local mode=$(echo "$session_data" | jq -r '.mode // "structured"')

    cat > "$EXPORT_FILE" << EOF
# 아이디어 정리

**주제:** $topic
**시작 시간:** $started_at
**모드:** $mode

---

## 대화 내용

EOF

    echo "$session_data" | jq -r '.messages[] | select(.role != "system") |
        "**\(.role):** \(.content)\n"' >> "$EXPORT_FILE"

    cat >> "$EXPORT_FILE" << EOF

---

## 추출된 제약사항

### ⚡ 성능
EOF

    local performance=$(echo "$session_data" | jq -r '.extracted_info.performance // [] | if length == 0 then "없음" else join(", ") end')
    echo "$performance" >> "$EXPORT_FILE"

    cat >> "$EXPORT_FILE" << EOF

### 💾 메모리
EOF

    local memory=$(echo "$session_data" | jq -r '.extracted_info.memory // [] | if length == 0 then "없음" else join(", ") end')
    echo "$memory" >> "$EXPORT_FILE"

    cat >> "$EXPORT_FILE" << EOF

### 🖥️ 플랫폼
EOF

    local platform=$(echo "$session_data" | jq -r '.extracted_info.platform // [] | if length == 0 then "없음" else join(", ") end')
    echo "$platform" >> "$EXPORT_FILE"

    cat >> "$EXPORT_FILE" << EOF

### 🔒 보안
EOF

    local security=$(echo "$session_data" | jq -r '.extracted_info.security // [] | if length == 0 then "없음" else join(", ") end')
    echo "$security" >> "$EXPORT_FILE"

    cat >> "$EXPORT_FILE" << EOF

### 🎨 디자인
EOF

    local design=$(echo "$session_data" | jq -r '.extracted_info.design // [] | if length == 0 then "없음" else join(", ") end')
    echo "$design" >> "$EXPORT_FILE"

    cat >> "$EXPORT_FILE" << EOF

### 📊 데이터
EOF

    local data=$(echo "$session_data" | jq -r '.extracted_info.data // [] | if length == 0 then "없음" else join(", ") end')
    echo "$data" >> "$EXPORT_FILE"

    cat >> "$EXPORT_FILE" << EOF

### 🎯 우선순위 / 📅 기간
EOF

    local priority=$(echo "$session_data" | jq -r '(.extracted_info.priority // "") | if . == "" then "미설정" else . end')
    local deadline=$(echo "$session_data" | jq -r '(.extracted_info.deadline // "") | if . == "" then "미설정" else . end')
    echo "우선순위: $priority, 기간: $deadline" >> "$EXPORT_FILE"

    log_success "내보내기 완료: $EXPORT_FILE"
}

# 세션 목록
list_sessions() {
    echo ""
    echo -e "${BOLD}이전 세션 목록:${NC}"
    echo ""

    if [[ ! -d "$SESSION_DIR" ]]; then
        log_info "저장된 세션이 없습니다."
        return 0
    fi

    # 간단 목록 표시
    find "$SESSION_DIR" -name "*.json" -not -name "current-session.json" 2>/dev/null | while read -r file; do
        local basename=$(basename "$file")
        echo "  - $basename"
    done
}

# 세션 저장 (별도 보관)
save_session_archive() {
    if [[ ! -f "$SESSION_FILE" ]]; then
        log_error "활성 세션이 없습니다."
        return 1
    fi

    local archive_file="${SESSION_DIR}/session-$(date +%Y%m%d-%H%M%S).json"
    cp "$SESSION_FILE" "$archive_file"
    log_success "세션 저장됨: $archive_file"
}

# 메인 함수
main() {
    local topic=""
    local action="conversation"
    local mode="structured"  # v3.0: structured | freetalk

    # 인자 파싱
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            --free|-f)
                mode="freetalk"
                shift
                ;;
            --analyze|--analysis)
                show_full_analysis
                exit 0
                ;;
            --constraints)
                show_constraints_analysis
                exit 0
                ;;
            --to-prd)
                action="to-prd"
                shift
                ;;
            --export)
                export_session
                exit 0
                ;;
            --list)
                list_sessions
                exit 0
                ;;
            --clear)
                rm -f "$SESSION_FILE"
                log_success "세션 초기화됨"
                exit 0
                ;;
            --save)
                save_session_archive
                exit 0
                ;;
            -*)
                log_error "알 수 없는 옵션: $1"
                show_usage
                exit 1
                ;;
            *)
                if [[ -n "$topic" ]]; then
                    topic="$topic $1"
                else
                    topic="$1"
                fi
                shift
                ;;
        esac
    done

    case "$action" in
        to-prd)
            if [[ ! -f "$SESSION_FILE" ]]; then
                log_error "활성 세션이 없습니다. 먼저 /brainstorm를 실행하세요."
                exit 1
            fi
            log_info "세션을 PRD로 변환합니다..."
            # TODO: PRD 생성 스크립트 연동
            log_warn "PRD 변환 기능은 구현 중입니다."
            ;;
        conversation)
            if [[ "$mode" == "freetalk" ]]; then
                start_freetalk "$topic"
            else
                start_conversation "$topic"
            fi
            ;;
    esac
}

# 실행
main "$@"
