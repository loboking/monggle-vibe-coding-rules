#!/bin/bash
#
# loop_detection.sh - Doom Loop Detection Library
#
# Usage:
#   source .claude/lib/loop_detection.sh
#   loop_detect_init
#   loop_check_file <file_path>
#   loop_record_attempt <file_path> <status>
#   loop_is_detected <file_path>
#

set -euo pipefail

# Cross-platform helpers (provides iso8601_to_epoch for BSD/GNU date compatibility)
if ! declare -F iso8601_to_epoch >/dev/null 2>&1; then
    _LOOP_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "${_LOOP_LIB_DIR}/cross-platform.sh" ]]; then
        # shellcheck source=/dev/null
        source "${_LOOP_LIB_DIR}/cross-platform.sh"
    fi
fi

# Configuration
# 통합 하네스 경로: 실행 위치와 무관하게 한 곳에 모은다 (HARNESS_HOME으로 오버라이드).
HARNESS_DIR="${HARNESS_HOME:-${HOME}/.claude/.harness}"
LOOP_DETECTION_FILE="${HARNESS_DIR}/loop-detection.json"

# Default thresholds
LOOP_MAX_MODIFICATIONS=${LOOP_MAX_MODIFICATIONS:-5}
LOOP_MAX_CONSECUTIVE_FAILURES=${LOOP_MAX_CONSECUTIVE_FAILURES:-3}
LOOP_COOLDOWN_MINUTES=${LOOP_COOLDOWN_MINUTES:-30}

# PRD Loop Detection (v3.0)
PRD_LOOP_DETECTION_FILE="${HARNESS_DIR}/prd-loop-detection.json"
PRD_LOOP_MAX_FAILURES=${PRD_LOOP_MAX_FAILURES:-3}

# Colors for output
readonly LC_RED='\033[0;31m'
readonly LC_YELLOW='\033[1;33m'
readonly LC_GREEN='\033[0;32m'
readonly LC_BLUE='\033[0;34m'
readonly LC_NC='\033[0m'

# Initialize loop detection file
loop_detect_init() {
    if [[ ! -d "$HARNESS_DIR" ]]; then
        mkdir -p "$HARNESS_DIR"
    fi

    if [[ ! -f "$LOOP_DETECTION_FILE" ]]; then
        cat > "$LOOP_DETECTION_FILE" << 'EOF'
{
  "version": "1.0.0",
  "last_updated": "2025-01-12T00:00:00Z",
  "files": {},
  "thresholds": {
    "max_modifications": 5,
    "max_consecutive_failures": 3,
    "cooldown_minutes": 30
  }
}
EOF
    fi
}

# Get file key (normalized path)
_loop_get_file_key() {
    local file_path="$1"
    # Convert to relative path from project root
    local rel_path="${file_path#$PROJECT_ROOT/}"
    # Normalize slashes
    echo "$rel_path" | sed 's|^\./||' | tr '/' '_'
}

# Get current timestamp in ISO 8601
_loop_get_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Check if file is in cooldown period
_loop_is_in_cooldown() {
    local file_key="$1"
    local last_modified=$(jq -r ".files[\"$file_key\"].last_modified // empty" "$LOOP_DETECTION_FILE" 2>/dev/null)

    if [[ -z "$last_modified" ]] || [[ "$last_modified" == "empty" ]]; then
        return 1  # No previous modification, not in cooldown
    fi

    # Calculate time difference (portable BSD/GNU date conversion)
    local last_epoch
    if declare -F iso8601_to_epoch >/dev/null 2>&1; then
        last_epoch=$(iso8601_to_epoch "$last_modified")
    else
        # Inline fallback if cross-platform.sh is unavailable
        case "${OSTYPE:-}" in
            darwin*) last_epoch=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$last_modified" +%s 2>/dev/null) ;;
            *)       last_epoch=$(date -u -d "$last_modified" +%s 2>/dev/null) ;;
        esac
        # Fallback to current time (elapsed 0) instead of epoch 0 to avoid ~55000yr skew
        [[ -z "$last_epoch" ]] && last_epoch=$(date +%s)
    fi
    local current_epoch=$(date +%s)
    local diff_minutes=$(( (current_epoch - last_epoch) / 60 ))

    if [[ $diff_minutes -lt $LOOP_COOLDOWN_MINUTES ]]; then
        return 0  # In cooldown
    fi

    return 1  # Cooldown expired
}

# Reset loop count (after cooldown or successful completion)
loop_reset_file() {
    local file_path="$1"
    loop_detect_init

    local file_key=$(_loop_get_file_key "$file_path")

    # Remove file entry or reset count
    local temp_file=$(mktemp)
    jq --arg key "$file_key" '
        if .files[$key] then
            del .files[$key]
        else
            .
        end
    ' "$LOOP_DETECTION_FILE" > "$temp_file"
    mv "$temp_file" "$LOOP_DETECTION_FILE"

    # Update timestamp
    jq --arg ts "$(_loop_get_timestamp)" '
        .last_updated = $ts
    ' "$LOOP_DETECTION_FILE" > "${LOOP_DETECTION_FILE}.tmp"
    mv "${LOOP_DETECTION_FILE}.tmp" "$LOOP_DETECTION_FILE"
}

# Check if a file is currently in a doom loop
loop_is_detected() {
    local file_path="$1"
    loop_detect_init

    local file_key=$(_loop_get_file_key "$file_path")

    # Check if file exists in tracking
    local count=$(jq -r ".files[\"$file_key\"].count // 0" "$LOOP_DETECTION_FILE" 2>/dev/null)

    if [[ $count -ge $LOOP_MAX_MODIFICATIONS ]]; then
        return 0  # Loop detected
    fi

    return 1  # No loop
}

# Record an attempt (success or failure)
loop_record_attempt() {
    local file_path="$1"
    local status="$2"  # "success" | "failure"
    loop_detect_init

    local file_key=$(_loop_get_file_key "$file_path")
    local timestamp=$(_loop_get_timestamp)

    # Check cooldown first
    if _loop_is_in_cooldown "$file_key"; then
        # Still in cooldown, don't update
        return 0
    fi

    # Create temp file for atomic update
    local temp_file=$(mktemp)

    if [[ "$status" == "success" ]]; then
        # Success: reset the count
        jq --arg key "$file_key" --arg ts "$timestamp" '
            if .files[$key] then
                .files[$key].count = 0 |
                .files[$key].consecutive_failures = 0 |
                .files[$key].last_modified = $ts |
                .last_updated = $ts
            else
                .
            end
        ' "$LOOP_DETECTION_FILE" > "$temp_file"
    else
        # Failure: increment counters
        jq --arg key "$file_key" --arg ts "$timestamp" '
            if .files[$key] then
                .files[$key].count += 1 |
                .files[$key].consecutive_failures += 1 |
                .files[$key].last_modified = $ts |
                .last_updated = $ts
            else
                .files[$key] = {
                    count: 1,
                    consecutive_failures: 1,
                    last_modified: $ts
                } |
                .last_updated = $ts
            end
        ' "$LOOP_DETECTION_FILE" > "$temp_file"
    fi

    mv "$temp_file" "$LOOP_DETECTION_FILE"
}

# Get loop status for a file
loop_get_status() {
    local file_path="$1"
    loop_detect_init

    local file_key=$(_loop_get_file_key "$file_path")

    jq -r --arg key "$file_key" '
        if .files[$key] then
            "File: \($key)\nModifications: \(.files[$key].count)\nConsecutive Failures: \(.files[$key].consecutive_failures)\nLast Modified: \(.files[$key].last_modified)"
        else
            "File: \($key)\nStatus: Not tracked"
        end
    ' "$LOOP_DETECTION_FILE" 2>/dev/null || echo "Error reading loop detection file"
}

# Check file before processing (returns exit code 1 if in loop)
loop_check_file() {
    local file_path="$1"

    if loop_is_detected "$file_path"; then
        echo -e "${LC_YELLOW}[LOOP WARNING]${LC_NC} Doom loop detected for: $file_path"
        echo "  Modifications: $(jq -r ".files[\"$(_loop_get_file_key "$file_path")\"].count" "$LOOP_DETECTION_FILE" 2>/dev/null)"
        echo "  Threshold: $LOOP_MAX_MODIFICATIONS"
        echo ""
        echo "Suggestions:"
        echo "  1. Review .harness/on-the-loop.md for remediation"
        echo "  2. Run /harness loops for detailed analysis"
        echo "  3. Use /harness improve to add new guides/sensors"
        return 1
    fi

    return 0
}

# Get all files in loop
loop_get_all_loops() {
    loop_detect_init

    jq -r '.files | to_entries[] |
        select(.value.count >= '"$LOOP_MAX_MODIFICATIONS"') |
        "\(.key): \(.value.count) modifications (last: \(.value.last_modified))"' \
        "$LOOP_DETECTION_FILE" 2>/dev/null || echo ""
}

# Generate loop report
loop_report() {
    loop_detect_init

    echo ""
    echo -e "${LC_BLUE}=== Doom Loop Detection Report ===${LC_NC}"
    echo ""

    local loop_count=$(jq '.files | to_entries[] | select(.value.count >= 5) | length' "$LOOP_DETECTION_FILE" 2>/dev/null || echo "0")

    if [[ "$loop_count" -eq 0 ]]; then
        echo -e "${LC_GREEN}✓ No doom loops detected${LC_NC}"
        echo "  Threshold: $LOOP_MAX_MODIFICATIONS modifications"
        return 0
    fi

    echo -e "${LC_YELLOW}⚠ $loop_count file(s) in doom loop:${LC_NC}"
    echo ""

    loop_get_all_loops | while read -r line; do
        echo -e "${LC_RED}  → $line${LC_NC}"
    done

    echo ""
    echo "Recommendations:"
    echo "  1. Review failing files for root cause"
    echo "  2. Add additional guides/sensors"
    echo "  3. Consider improving PRD templates"
}

# ═══════════════════════════════════════════════════════════════════════════
# PRD 단위 루프 감지 (v3.0)
# ═══════════════════════════════════════════════════════════════════════════

# PRD 루프 감지 파일 초기화
loop_prd_init() {
    if [[ ! -d "$HARNESS_DIR" ]]; then
        mkdir -p "$HARNESS_DIR"
    fi

    if [[ ! -f "$PRD_LOOP_DETECTION_FILE" ]]; then
        cat > "$PRD_LOOP_DETECTION_FILE" << 'EOF'
{
  "version": "1.0.0",
  "last_updated": "2025-01-12T00:00:00Z",
  "prd_files": {},
  "thresholds": {
    "max_failures": 3
  }
}
EOF
    fi
}

# PRD 키 가져오기
_loop_get_prd_key() {
    local prd_file="$1"
    # PRD 파일명을 키로 사용
    basename "$prd_file"
}

# PRD 실패 기록
loop_record_prd_attempt() {
    local prd_file="$1"
    local status="$2"  # "success" | "failure"
    local stage="${3:-patch}"  # gate, scan, fold, verdict, patch, trace
    local files="${4:-}"  # 수정된 파일 목록 (콤마 구분)

    loop_prd_init

    local prd_key=$(_loop_get_prd_key "$prd_file")
    local timestamp=$(_loop_get_timestamp)

    local temp_file=$(mktemp)

    if [[ "$status" == "success" ]]; then
        # 성공: PRD 기록 초기화
        jq --arg key "$prd_key" --arg ts "$timestamp" '
            if .prd_files[$key] then
                .prd_files[$key].failures = 0 |
                .prd_files[$key].last_status = "success" |
                .prd_files[$key].last_modified = $ts |
                .prd_files[$key].attempts += 1 |
                .last_updated = $ts
            else
                .
            end
        ' "$PRD_LOOP_DETECTION_FILE" > "$temp_file"
    else
        # 실패: 실패 횟수 증가
        jq --arg key "$prd_key" --arg ts "$timestamp" --arg stage "$stage" --arg files "$files" '
            if .prd_files[$key] then
                .prd_files[$key].failures += 1 |
                .prd_files[$key].consecutive_failures += 1 |
                .prd_files[$key].last_status = "failure" |
                .prd_files[$key].last_stage = $stage |
                .prd_files[$key].last_files = $files |
                .prd_files[$key].last_modified = $ts |
                .prd_files[$key].attempts += 1 |
                .prd_files[$key].history += [
                    {
                        timestamp: $ts,
                        stage: $stage,
                        status: "failure",
                        files: $files
                    }
                ] |
                .last_updated = $ts
            else
                .prd_files[$key] = {
                    failures: 1,
                    consecutive_failures: 1,
                    last_status: "failure",
                    last_stage: $stage,
                    last_files: $files,
                    last_modified: $ts,
                    attempts: 1,
                    history: [
                        {
                            timestamp: $ts,
                            stage: $stage,
                            status: "failure",
                            files: $files
                        }
                    ]
                } |
                .last_updated = $ts
            end
        ' "$PRD_LOOP_DETECTION_FILE" > "$temp_file"
    fi

    mv "$temp_file" "$PRD_LOOP_DETECTION_FILE"
}

# PRD 루프 감지
loop_is_prd_in_loop() {
    local prd_file="$1"
    loop_prd_init

    local prd_key=$(_loop_get_prd_key "$prd_file")
    local failures=$(jq -r ".prd_files[\"$prd_key\"].consecutive_failures // 0" "$PRD_LOOP_DETECTION_FILE" 2>/dev/null)

    [[ $failures -ge $PRD_LOOP_MAX_FAILURES ]]
}

# PRD 루프 체크 (pipeline에서 호출)
loop_check_prd() {
    local prd_file="$1"

    if loop_is_prd_in_loop "$prd_file"; then
        local prd_key=$(_loop_get_prd_key "$prd_file")
        local failures=$(jq -r ".prd_files[\"$prd_key\"].consecutive_failures" "$PRD_LOOP_DETECTION_FILE")
        local last_stage=$(jq -r ".prd_files[\"$prd_key\"].last_stage" "$PRD_LOOP_DETECTION_FILE")
        local last_files=$(jq -r ".prd_files[\"$prd_key\"].last_files" "$PRD_LOOP_DETECTION_FILE")

        echo ""
        echo -e "${LC_RED}╔════════════════════════════════════════════════════════════╗${LC_NC}"
        echo -e "${LC_RED}║  FAIL-FAST: PRD 루프 감지                                   ║${LC_NC}"
        echo -e "${LC_RED}╚════════════════════════════════════════════════════════════╝${LC_NC}"
        echo ""
        echo -e "  PRD: ${LC_YELLOW}$(basename "$prd_file")${LC_NC}"
        echo -e "  연속 실패: ${LC_RED}${failures}회${LC_NC} (한계: ${PRD_LOOP_MAX_FAILURES}회)"
        echo -e "  마지막 단계: ${last_stage}"
        echo -e "  관련 파일: ${last_files}"
        echo ""
        echo -e "${LC_YELLOW}원인 분석:${LC_NC}"
        echo "  → 동일 PRD에서 반복 실패가 발생하고 있습니다."
        echo "  → 기획의 모호함이나 기술적 제약이 있을 수 있습니다."
        echo ""
        echo -e "${LC_YELLOW}다음 단계:${LC_NC}"
        echo "  1. ${LC_CYAN}/prd --update${LC_NC} 로 PRD를 수정하세요"
        echo "  2. 제약사항을 명확히 하세요"
        echo "  3. --force로 강제 진행 (권장하지 않음)"
        echo ""
        return 1
    fi

    return 0
}

# ═══════════════════════════════════════════════════════════════════════════
# 고도화된 실패 분석 (v3.0)
# ═══════════════════════════════════════════════════════════════════════════

# 패턴 분석: 반복되는 실패 패턴 감지
_loop_analyze_patterns() {
    local prd_key="$1"

    local data=$(jq -r --arg key "$prd_key" '
        .prd_files[$key].history // []
    ' "$PRD_LOOP_DETECTION_FILE")

    # 같은 파일 반복 실패 분석
    local repeated_files=$(echo "$data" | jq -r '
        map(.files) | add(",") | split(",") | map(select(. != "")) |
        group_by(.) | map({file: .[0], count: length}) | sort_by(.count) | reverse
    ' 2>/dev/null)

    # 같은 단계 반복 실패 분석
    local repeated_stages=$(echo "$data" | jq -r '
        map(.stage) | group_by(.) | map({stage: .[0], count: length}) | sort_by(.count) | reverse
    ' 2>/dev/null)

    echo "FILES:$repeated_files"
    echo "STAGES:$repeated_stages"
}

# 실패 시각화 (스파크라인)
_loop_create_sparkline() {
    local values="$1"  # 공간 구분된 숫자들
    local max_val=0
    local sparkline=""

    # 최대값 찾기
    for val in $values; do
        if (( $(echo "$val > $max_val" | bc -l) )); then
            max_val=$val
        fi
    done

    [[ $max_val -eq 0 ]] && max_val=1

    # 스파크라인 생성
    for val in $values; do
        local height=$(( (val * 5) / max_val ))
        case $height in
            0) sparkline="${sparkline}_" ;;
            1) sparkline="${sparkline}▁" ;;
            2) sparkline="${sparkline}▂" ;;
            3) sparkline="${sparkline}▃" ;;
            4) sparkline="${sparkline}▄" ;;
            5) sparkline="${sparkline}▅" ;;
            *) sparkline="${sparkline}▆" ;;
        esac
    done

    echo "$sparkline"
}

# 타임라인 생성
_loop_create_timeline() {
    local prd_key="$1"

    jq -r --arg key "$prd_key" '
        .prd_files[$key].history[-10:] // [] |
        .[] | "\(.timestamp | .[0:10])[ \(.stage)]"
    ' "$PRD_LOOP_DETECTION_FILE" 2>/dev/null | while read -r line; do
        local date=$(echo "$line" | cut -d'[' -f1)
        local stage=$(echo "$line" | cut -d'[' -f2 | cut -d']' -f1)
        case $stage in
            gate)    echo "  $date │ G" ;;
            scan)    echo "  $date │ Sc" ;;
            fold)    echo "  $date │ F" ;;
            verdict) echo "  $date │ V" ;;
            patch)   echo "  $date │ P ✗" ;;
            trace)   echo "  $date │ T" ;;
            *)       echo "  $date │ ?" ;;
        esac
    done
}

# 원인 분석 및 권장 사항 생성
_loop_classify_root_cause() {
    local prd_key="$1"
    local repeated_files="$2"
    local repeated_stages="$3"

    local cause_type=""
    local recommendations=()

    # 같은 파일 반복 = 기술적 제약 또는 복잡도
    if echo "$repeated_files" | jq -e '.[0].count > 2' >/dev/null 2>&1; then
        cause_type="${cause_type},technical_complexity"
        recommendations+=("반복 실패하는 파일: $(echo "$repeated_files" | jq -r '.[0].file')")
        recommendations+=("→ 파일을 더 작은 단위로 분할 고려")
    fi

    # 같은 단계 반복 = 해당 단계 문제
    if echo "$repeated_stages" | jq -e '.[0].count > 2' >/dev/null 2>&1; then
        local failing_stage=$(echo "$repeated_stages" | jq -r '.[0].stage')
        cause_type="${cause_type},stage_blocker"

        case $failing_stage in
            gate)
                recommendations+=("Gate 단계 반복 실패: PRD 자체가 불충분")
                recommendations+=("→ /prd --update로 PRD를 처음부터 재작성")
                ;;
            verdict)
                recommendations+=("Verdict 단계 반복 실패: 요구사항이 모호함")
                recommendations+=("→ '제약사항' 섹션을 명확히 작성")
                ;;
            patch)
                recommendations+=("Patch 단계 반복 실패: 구현 난이도 높음")
                recommendations+=("→ 프로토타입 먼저 구현 후 본 개발")
                ;;
            *)
                recommendations+=("${failing_stage} 단계에서 반복 실패")
                ;;
        esac
    fi

    # 원인 유형 분류
    if [[ -z "$cause_type" ]]; then
        cause_type="unknown"
    fi

    echo "$cause_type"
    for rec in "${recommendations[@]}"; do
        echo "$rec"
    done
}

# PRD 실패 분석 보고서 생성 (고도화)
loop_generate_failure_report() {
    local prd_file="$1"

    # [v3.5] 무한 루프 감지 시 오염된 단기 기억 세척 (Garbage Collection)
    local active_mem="${PROJECT_ROOT}/.claude/session/current/active_synapses.md"
    if [ -f "$active_mem" ]; then
        echo "⚠️ [BRAIN GC] 무한 루프가 감지되어 오염된 단기 기억(에러 로그 누적)을 초기화합니다." >&2
        # 에이전트가 리프레시 할 수 있도록 헤더만 남기고 리셋
        {
            echo "### 🧠 [Synapse Reset] 루프 감지로 인한 기억 리셋"
            echo "- 리셋 시간: $(date '+%Y-%m-%d %H:%M:%S')"
            echo "- 사유: PRD 루프 감지 ($prd_file)"
            echo ""
            echo "이전 기억이 초기화되었습니다. 새로운 시작을 준비합니다."
        } > "$active_mem"
    fi

    local prd_key=$(_loop_get_prd_key "$prd_file")
    local report_file="${HARNESS_DIR}/failure-analysis-$(date +%Y%m%d-%H%M%S).md"
    local timestamp=$(_loop_get_timestamp)

    cat > "$report_file" << EOF
# 🔍 Failure Analysis Report

> **PRD:** \`$(basename "$prd_file")\`
> **생성 시간:** $timestamp
> **분석 버전:** v3.0

---

## 📊 실패 요약

EOF

    # 기본 통계
    local stats=$(jq -r --arg key "$prd_key" '
        "### 연속 실패: \(.prd_files[$key].consecutive_failures)회 / 3회 (한계 도달)\n",
        "### 총 시도 횟수: \(.prd_files[$key].attempts)회\n",
        "### 마지막 실패 단계: **\(.prd_files[$key].last_stage)**\n",
        "### 관련 파일: \(.prd_files[$key].last_files // "없음")\n"
    ' "$PRD_LOOP_DETECTION_FILE")
    echo -e "$stats" >> "$report_file"

    cat >> "$report_file" << EOF

---

## 📈 실패 패턴 분석

EOF

    # 패턴 분석 수행
    local patterns=$(_loop_analyze_patterns "$prd_key")
    local repeated_files=$(echo "$patterns" | grep "^FILES:" | cut -d':' -f2-)
    local repeated_stages=$(echo "$patterns" | grep "^STAGES:" | cut -d':' -f2-)

    # 반복 파일 표시
    if [[ -n "$repeated_files" ]] && echo "$repeated_files" | jq -e '.[0]' >/dev/null 2>&1; then
        echo "### 🔁 반복 실패 파일" >> "$report_file"
        echo "\`\`\`" >> "$report_file"
        echo "$repeated_files" | jq -r '.[] | "  \(.file): \(.count)회"' >> "$report_file" 2>/dev/null || echo "  없음" >> "$report_file"
        echo "\`\`\`" >> "$report_file"
        echo "" >> "$report_file"
    fi

    # 반복 단계 표시
    if [[ -n "$repeated_stages" ]] && echo "$repeated_stages" | jq -e '.[0]' >/dev/null 2>&1; then
        echo "### 🔄 반복 실패 단계" >> "$report_file"
        echo "\`\`\`" >> "$report_file"
        echo "$repeated_stages" | jq -r '.[] | "  \(.stage): \(.count)회"' >> "$report_file" 2>/dev/null || echo "  없음" >> "$report_file"
        echo "\`\`\`" >> "$report_file"
        echo "" >> "$report_file"
    fi

    cat >> "$report_file" << EOF

---

## 📅 타임라인 (최근 10회)

\`\`\`
날짜       │ 단계
─────────────────────
EOF

    _loop_create_timeline "$prd_key" >> "$report_file"

    cat >> "$report_file" << EOF

\`\`\`

---

## 🔬 원인 분류

EOF

    # 원인 분석
    local classification=$(_loop_classify_root_cause "$prd_key" "$repeated_files" "$repeated_stages")
    local cause_type=$(echo "$classification" | head -1)

    # 원인 유형 시각화
    case "$cause_type" in
        *technical_complexity*)
            echo "### 🏗️ 기술적 복잡도" >> "$report_file"
            echo "- 같은 파일에서 반복적으로 실패가 발생하고 있습니다." >> "$report_file"
            echo "- 파일이 너무 크거나 복잡할 가능성이 높습니다." >> "$report_file"
            ;;
        *stage_blocker*)
            echo "### 🚫 단계별 장애물" >> "$report_file"
            echo "- 특정 파이프라인 단계에서 계속 실패합니다." >> "$report_file"
            echo "- 해당 단계의 요구사항을 충족하지 못하고 있습니다." >> "$report_file"
            ;;
        *,*)
            echo "### 🔀 복합적 원인" >> "$report_file"
            echo "- 여러 유형의 문제가 복합적으로 발생하고 있습니다." >> "$report_file"
            ;;
        *)
            echo "### ❓ 미분류" >> "$report_file"
            echo "- 패턴이 명확하지 않습니다. 추가 데이터가 필요합니다." >> "$report_file"
            ;;
    esac

    cat >> "$report_file" << EOF

---

## 💡 권장 조치

EOF

    # 권장 사항
    echo "$classification" | tail -n +2 | while read -r line; do
        if [[ -n "$line" ]]; then
            echo "- $line" >> "$report_file"
        fi
    done

    # 기본 권장 사항 추가
    cat >> "$report_file" << EOF

### 다음 단계

1. **PRD 수정**
   \`\`\`bash
   /prd --update $prd_file
   \`\`\`

2. **제약사항 명확화**
   - 성능 요구사항 (O(n), 메모리 상한 등)
   - 기술적 제약사항 (사용 불가능한 라이브러리 등)
   - 환경 제약사항 (브라우저, OS 등)

3. **범위 축소**
   - 너무 큰 기능은 더 작은 단위로 분할
   - MVP(Minimum Viable Product) 먼저 구현

4. **전문가 상담**
   - 기술적 난이도가 높은 경우 사전 검토 요청

---

## 📋 전체 실패 이력

| 시간 | 단계 | 상태 | 관련 파일 |
|------|------|------|----------|
EOF

    jq -r --arg key "$prd_key" '
        .prd_files[$key].history[] |
        "| \(.timestamp) | \(.stage) | \(.status) | \(.files // "-") |"
    ' "$PRD_LOOP_DETECTION_FILE" >> "$report_file"

    cat >> "$report_file" << EOF


---

*이 보고서는 Vibe Coding Rules v3.0 실패 분석 시스템에 의해 자동 생성되었습니다.*
*자세한 내용: \`/harness loops\` 또는 \`cat $report_file\`*
EOF

    echo "$report_file"
}

# PRD 루프 상태 초기화 (성공 또는 PRD 수정 후)
loop_reset_prd() {
    local prd_file="$1"
    loop_prd_init

    local prd_key=$(_loop_get_prd_key "$prd_file")
    local temp_file=$(mktemp)

    jq --arg key "$prd_key" '
        if .prd_files[$key] then
            .prd_files[$key].failures = 0 |
            .prd_files[$key].consecutive_failures = 0 |
            .prd_files[$key].last_status = "reset"
        else
            .
        end
    ' "$PRD_LOOP_DETECTION_FILE" > "$temp_file"
    mv "$temp_file" "$PRD_LOOP_DETECTION_FILE"
}

# PRD 루프 상태 조회
loop_get_prd_status() {
    local prd_file="$1"
    loop_prd_init

    local prd_key=$(_loop_get_prd_key "$prd_file")

    jq -r --arg key "$prd_key" '
        if .prd_files[$key] then
            "PRD: \($key)\nFailures: \(.prd_files[$key].consecutive_failures)/'"$PRD_LOOP_MAX_FAILURES"'\nLast Stage: \(.prd_files[$key].last_stage)\nLast Status: \(.prd_files[$key].last_status)"
        else
            "PRD: \($key)\nStatus: Not tracked"
        end
    ' "$PRD_LOOP_DETECTION_FILE" 2>/dev/null || echo "Error reading PRD loop detection file"
}

# Export PRD loop functions
export -f loop_prd_init
export -f loop_record_prd_attempt
export -f loop_is_prd_in_loop
export -f loop_check_prd
export -f loop_generate_failure_report
export -f loop_reset_prd
export -f loop_get_prd_status

# ═══════════════════════════════════════════════════════════════════════════
# 기존 함수 export (파일 단위)
# ═══════════════════════════════════════════════════════════════════════════

export -f loop_detect_init
export -f loop_is_detected
export -f loop_record_attempt
export -f loop_reset_file
export -f loop_check_file
export -f loop_get_status
export -f loop_get_all_loops
export -f loop_report
