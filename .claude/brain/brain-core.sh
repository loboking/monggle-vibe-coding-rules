#!/bin/bash
#
# brain-core.sh - 뇌 시스템 코어 라이브러리
# Version: 1.0.0
#
# 뇌 시스템의 핵심 기능 구현
# - 뉴런 관리
# - 시냅스 연결
# - 망각 곡선
# - 기억 검색
#

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

BRAIN_HOME="${CLAUDE_BRAIN_HOME:-$HOME/.claude/brain}"
NEURONS_DIR="$BRAIN_HOME/neurons"
HIPPOCAMPUS_DIR="$BRAIN_HOME/hippocampus"
SYNAPSES_FILE="$BRAIN_HOME/synapses/index.json"
AMYGDALA_FILE="$BRAIN_HOME/amygdala/emotional_weights.json"
CORTEX_FILE="$BRAIN_HOME/cortex/hot-cache.md"

# 임계값
CONSOLIDATION_THRESHOLD=0.5     # 기억 고착화 임계값
FORGET_THRESHOLD=0.2            # 망각 임계값
PREDICTION_ERROR_THRESHOLD=0.3  # 예측 오류 임계값
HIPPOCAMPUS_RETENTION_HOURS=24  # 해마 보유 시간

# ============================================================================
# Utility Functions
# ============================================================================

_log() {
    local level="$1"
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" >&2
}

log_debug() { _log "DEBUG" "$@"; }
log_info() { _log "INFO" "$@"; }
log_warn() { _log "WARN" "$@"; }
log_error() { _log "ERROR" "$@"; }

# ISO-8601 타임스탬프를 epoch 초로 변환 (GNU/BSD date 양쪽 호환)
# last_accessed 포맷: "YYYY-MM-DDTHH:MM:SSZ" (jq의 `now | todate`)
# 성공 시 epoch 출력 후 0 반환, 실패 시 아무것도 출력 안 하고 1 반환.
brain_iso_to_epoch() {
    local ts="$1"
    local epoch

    # GNU date (-d): Linux
    if epoch=$(date -d "$ts" +%s 2>/dev/null); then
        echo "$epoch"
        return 0
    fi

    # BSD date (-u -j -f): macOS
    # 타임스탬프는 UTC('Z')로 저장되므로 -u 로 UTC 해석해야 로컬 TZ offset 왜곡이 없다.
    # 전체 ISO 포맷 우선, cut 등으로 잘린 입력(날짜+시 등)도 폴백 처리
    local fmt
    for fmt in "%Y-%m-%dT%H:%M:%SZ" "%Y-%m-%dT%H:%M:%S" "%Y-%m-%dT%H"; do
        if epoch=$(date -u -j -f "$fmt" "$ts" +%s 2>/dev/null); then
            echo "$epoch"
            return 0
        fi
    done

    return 1
}

# ============================================================================
# Initialization
# ============================================================================

brain_init() {
    log_info "뇌 시스템 초기화 중..."

    # 디렉토리 생성
    # 정본은 brain_create_neuron 이 쓰는 단수형($type). 단수형을 만들되,
    # 기존 복수형 디렉토리 호환을 위해 양쪽 모두 mkdir -p (데이터 손실 없음).
    mkdir -p "$NEURONS_DIR"/{decision,pattern,bug,context,todo}
    mkdir -p "$NEURONS_DIR"/{decisions,patterns,bugs,contexts,todos}
    mkdir -p "$HIPPOCAMPUS_DIR/sessions"
    mkdir -p "$(dirname "$SYNAPSES_FILE")"
    mkdir -p "$(dirname "$AMYGDALA_FILE")"
    mkdir -p "$(dirname "$CORTEX_FILE")"

    # 시냅스 인덱스 초기화
    if [[ ! -f "$SYNAPSES_FILE" ]]; then
        cat > "$SYNAPSES_FILE" << 'EOF'
{
  "synapses": {},
  "neurons": {},
  "last_update": null
}
EOF
    fi

    # 감정 가중치 초기화
    if [[ ! -f "$AMYGDALA_FILE" ]]; then
        cat > "$AMYGDALA_FILE" << 'EOF'
{
  "emotions": {
    "urgent": 1.0,
    "critical": 0.9,
    "important": 0.7,
    "normal": 0.5,
    "low": 0.3
  },
  "last_update": null
}
EOF
    fi

    # 핫 캐시 초기화
    if [[ ! -f "$CORTEX_FILE" ]]; then
        echo "# 🧠 핫 캐시 (자주 쓰는 기억)" > "$CORTEX_FILE"
        echo "" >> "$CORTEX_FILE"
        echo "> 자주 접근하는 뉴런이 여기에 표시됩니다" >> "$CORTEX_FILE"
    fi

    log_info "뇌 시스템 초기화 완료"
}

# ============================================================================
# Neuron Management
# ============================================================================

# 뉴런 ID 생성
# 같은 초 + 같은 type 충돌을 막기 위해 랜덤 suffix 추가
brain_generate_id() {
    local type="$1"
    local rand
    rand=$(printf '%04x' "$((RANDOM % 65536))")
    echo "n$(date +%Y%m%d%H%M%S)-${type}-${rand}"
}

# 뉴런 생성
brain_create_neuron() {
    local type="$1"
    local title="$2"
    local content="$3"
    local tags="${4:-}"
    local emotion="${5:-normal}"

    local neuron_id
    neuron_id=$(brain_generate_id "$type")

    local neuron_dir="$NEURONS_DIR/$type"
    local neuron_file="$neuron_dir/${neuron_id}.md"

    # 디렉토리 생성 (bash 3.x 호환)
    mkdir -p "$neuron_dir"

    # 감정 가중치 가져오기
    local emotional_weight
    emotional_weight=$(jq -r ".emotions.${emotion} // 0.5" "$AMYGDALA_FILE")

    # 뉴런 파일 생성
    cat > "$neuron_file" << EOF
---
id: ${neuron_id}
type: ${type}
created: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
last_accessed: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
access_count: 0
emotional_weight: ${emotional_weight}
tags: [${tags}]
links: []
prediction_error: 0.0
---

# ${title}

## 내용
${content}

## 맥락
- **When**: $(date '+%Y-%m-%d %H:%M')
- **Session**: $$
- **Emotion**: ${emotion}
EOF

    # 시냅스 인덱스 업데이트
    brain_register_neuron "$neuron_id" "$type" "$tags" "$emotional_weight"

    log_info "뉴런 생성됨: $neuron_id ($type)"
    echo "$neuron_id"
}

# 뉴런 등록
brain_register_neuron() {
    local neuron_id="$1"
    local type="$2"
    local tags="$3"
    local emotional_weight="$4"

    local tmp_file="${SYNAPSES_FILE}.tmp"

    # 태그 파싱 (JSON 배열로)
    local tags_json="[$(echo "$tags" | tr ',' '\n' | sed 's/\(.*\)/"\1"/' | paste -sd ',' -)]"

    jq --arg id "$neuron_id" \
       --arg type "$type" \
       --argjson tags "$tags_json" \
       --argjson weight "$emotional_weight" \
       '
       .neurons[$id] = {
         "type": $type,
         "tags": $tags,
         "emotional_weight": $weight,
         "synapses_out": [],
         "created": (now | todate),
         "last_accessed": (now | todate)
       }
       ' "$SYNAPSES_FILE" > "$tmp_file"

    mv "$tmp_file" "$SYNAPSES_FILE"
}

# ============================================================================
# Synapse Management
# ============================================================================

# 시냅스 생성 (연결)
brain_create_synapse() {
    local source="$1"
    local target="$2"
    local weight="${3:-0.5}"

    local synapse_id="${source}-${target}"
    local tmp_file="${SYNAPSES_FILE}.tmp"

    jq --arg src "$source" \
       --arg tgt "$target" \
       --arg synapse "$synapse_id" \
       --argjson weight "$weight" \
       '
       .synapses[$synapse] = {
         "source": $src,
         "target": $tgt,
         "weight": $weight,
         "decay_rate": 0.001,
         "last_activation": (now | todate),
         "activation_count": 1,
         "emotional_weight": (.neurons[$src].emotional_weight // 0.5),
         "prediction_error": 0.0,
         "created": (now | todate)
       } |
       .neurons[$src].synapses_out += [$tgt]
       ' "$SYNAPSES_FILE" > "$tmp_file"

    mv "$tmp_file" "$SYNAPSES_FILE"

    log_debug "시냅스 생성됨: $synapse_id (weight: $weight)"
}

# 시냅스 강화
brain_strengthen_synapse() {
    local synapse_id="$1"
    local boost="${2:-0.1}"

    local tmp_file="${SYNAPSES_FILE}.tmp"

    jq --arg synapse "$synapse_id" \
       --argjson boost "$boost" \
       '
       .synapses[$synapse].weight += $boost |
       .synapses[$synapse].weight = ([.synapses[$synapse].weight, 1.0] | min) |
       .synapses[$synapse].activation_count += 1 |
       .synapses[$synapse].last_activation = (now | todate)
       ' "$SYNAPSES_FILE" > "$tmp_file"

    mv "$tmp_file" "$SYNAPSES_FILE"
}

# ============================================================================
# Memory Retrieval
# ============================================================================

# 태그로 뉴런 검색
brain_query_by_tags() {
    local tags="$1"  # 콤마로 구분
    local limit="${2:-10}"

    local tmp_file="${SYNAPSES_FILE}.tmp"

    # 태그 배열로 변환
    local search_tags="[$(echo "$tags" | tr ',' '\n' | sed 's/\(.*\)/"\1"/' | paste -sd ',' -)]"

    jq -r --argjson tags "$search_tags" \
       --argjson limit "$limit" \
       '
       .neurons |
       to_entries[] |
       select(.value.tags as $t | $tags | inside($t)) |
       {id: .key, type: .value.type, weight: .value.emotional_weight, tags: .value.tags} |
       "- \(.id) (\(.type)): \(.tags | join(", ")) (weight: \(.weight))"
       ' "$SYNAPSES_FILE" | head -n "$limit"
}

# 뉴런 내용 로드
brain_recall_neuron() {
    local neuron_id="$1"

    local neuron_file
    neuron_file=$(find "$NEURONS_DIR" -name "${neuron_id}.md" 2>/dev/null)

    if [[ -z "$neuron_file" ]]; then
        log_error "뉴런을 찾을 수 없음: $neuron_id"
        return 1
    fi

    # 접근 카운트 증가
    brain_update_access "$neuron_id"

    cat "$neuron_file"
}

# 접근 업데이트
brain_update_access() {
    local neuron_id="$1"

    local tmp_file="${SYNAPSES_FILE}.tmp"

    jq --arg id "$neuron_id" \
       '
       .neurons[$id].last_accessed = (now | todate) |
       .neurons[$id].access_count += 1
       ' "$SYNAPSES_FILE" > "$tmp_file"

    mv "$tmp_file" "$SYNAPSES_FILE"
}

# ============================================================================
# Forgetting Curve
# ============================================================================

# 기억 유지율 계산 (지수 감쇠 모델 / 에빙하우스 망각 곡선)
#
# 공식: retention = e^(-age_hours / half_life)
#   half_life = BASE_HALF_LIFE_HOURS * (1 + emo*EMO_COEF + act*ACT_COEF)
#
# Properties:
#   - age_hours=0 -> retention=1.0 (방금 만든 기억)
#   - monotonically decreasing, convex (에빙하우스 곡선)
#   - 감정/반복은 half_life(분모)를 키워 곡선을 평평하게 -> 중요 기억 장기 생존
#   - 0 < retention <= 1 (지수함수 특성. 안전 클램프만 유지)
#
# 검증된 반감기:
#   LOW (emo0.3,act0): 202h(8.4d), 망각 13.5d | MED(emo0.5,act1): 317h(13.2d)
#   HIGH(emo0.9,act5): 605h(25.2d), 30d시점 0.30 생존 | MAX(emo1.0,act10): 792h(33d)
#
# 참고: 기존 0.1 하한을 제거(자연 감쇠 0까지 허용). 0.1 하한은 절대 망각 불가 버그였음.
brain_calc_retention() {
    local last_access="$1"
    local emotional_weight="$2"
    local activation_count="$3"

    # 파라미터 (실측으로 요구사항 충족 검증됨)
    local BASE_HALF_LIFE_HOURS=72   # 3일. 감정/반복 없는 기본 반감기
    local EMO_COEF=6.0              # 감정 가중치 계수 (입력 0~1)
    local ACT_COEF=0.4             # 반복(access_count) 계수

    local now
    now=$(date +%s)
    local last
    if ! last=$(brain_iso_to_epoch "$last_access"); then
        # 파싱 실패 -> now 폴백(age=0->retention 1.0). 깨진 기억이 안 죽는 부작용 경고.
        log_warn "타임스탬프 파싱 실패, now 폴백: '$last_access'"
        last="$now"
    fi

    local age_hours=$(( (now - last) / 3600 ))
    # age<0 (시계 역행/미래 타임스탬프) -> 음수 지수로 retention>1 발생. 0으로 클램프.
    (( age_hours < 0 )) && age_hours=0

    # age=0 (1시간 미만 신규 기억) -> 명시적으로 1.0
    if (( age_hours == 0 )); then
        echo "1.00"
        return 0
    fi

    # emo 입력 0~1 클램프 (공식 가정)
    local emo="$emotional_weight"
    if [[ $(echo "$emo < 0" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then emo=0; fi
    if [[ $(echo "$emo > 1" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then emo=1; fi
    local act="$activation_count"

    # 지수함수 계산: 1차 bc, 2차 awk, 3차 python3, 최종 폴백 0.5
    # 동일 공식이라 폴백 간 수치 일관.
    local retention=""

    # --- 1차: bc -l ---
    # 주의: 지수에 반드시 괄호. e(- $age / hl)는 bc 오파싱(~0.9999) 버그.
    retention=$(bc -l 2>/dev/null << BCEOF
scale=10
half_life = $BASE_HALF_LIFE_HOURS * (1 + $emo * $EMO_COEF + $act * $ACT_COEF)
result = e(-($age_hours) / half_life)
if (result > 1) result = 1
if (result < 0) result = 0
result
BCEOF
)

    # bc leading-dot 정규화 (.367 -> 0.367)
    if [[ "$retention" == .* ]]; then retention="0$retention"; fi
    if [[ "$retention" == -.* ]]; then retention="-0${retention#-}"; fi

    # bc 실패 또는 빈 출력 -> 2차: awk exp() (macOS 기본 탑재)
    if [[ -z "$retention" ]]; then
        retention=$(awk -v age="$age_hours" -v base="$BASE_HALF_LIFE_HOURS" \
            -v emo="$emo" -v ec="$EMO_COEF" -v act="$act" -v ac="$ACT_COEF" \
            'BEGIN {
                hl = base * (1 + emo * ec + act * ac);
                r = exp(-age / hl);
                if (r > 1) r = 1;
                if (r < 0) r = 0;
                printf "%.10f", r;
            }' 2>/dev/null)
    fi

    # awk 실패 -> 3차: python3 math.exp
    if [[ -z "$retention" ]]; then
        retention=$(python3 -c "
import math
hl = $BASE_HALF_LIFE_HOURS * (1 + $emo * $EMO_COEF + $act * $ACT_COEF)
r = math.exp(-$age_hours / hl)
r = min(1.0, max(0.0, r))
print('%.10f' % r)
" 2>/dev/null)
    fi

    # 최종 폴백
    if [[ -z "$retention" ]]; then
        log_warn "지수함수 계산 실패(bc/awk/python3), 폴백 0.5"
        retention="0.5"
    fi

    # 안전 클램프 (0 <= r <= 1)
    if [[ $(echo "$retention < 0" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
        retention="0"
    elif [[ $(echo "$retention > 1" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
        retention="1"
    fi

    # 소수 2자리 반올림
    retention=$(printf "%.2f" "$retention" 2>/dev/null || echo "$retention")

    echo "$retention"
}

# 오래된 기억 청소 (bash 3.x 호환 - 임시 파일 사용)
brain_cleanup_forgotten() {
    log_info "망각된 기억 청소 중..."

    local tmp_remove="${SYNAPSES_FILE}.remove"
    > "$tmp_remove"  # 비우기

    # 낮은 유지율의 뉴런 찾아서 임시 파일에 저장
    while IFS= read -r line; do
        local neuron_id=$(echo "$line" | cut -d: -f1)
        local last_access=$(echo "$line" | cut -d: -f2)
        local emotional_weight=$(echo "$line" | cut -d: -f3)
        local activation_count=$(echo "$line" | cut -d: -f4)

        local retention
        retention=$(brain_calc_retention "$last_access" "$emotional_weight" "$activation_count")

        if [[ $(echo "$retention < $FORGET_THRESHOLD" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
            echo "$neuron_id" >> "$tmp_remove"
            log_debug "망감 예정: $neuron_id (retention: $retention)"
        fi
    done < <(jq -r '.neurons | to_entries[] | "\(.key):\(.value.last_accessed):\(.value.emotional_weight):\(.value.access_count)"' "$SYNAPSES_FILE")

    # 제거
    local count=0
    while IFS= read -r neuron_id; do
        [[ -n "$neuron_id" ]] && brain_remove_neuron "$neuron_id"
        count=$((count + 1))
    done < "$tmp_remove"

    rm -f "$tmp_remove"
    log_info "청소 완료: ${count}개 뉴런 제거됨"
}

# 뉴런 제거
brain_remove_neuron() {
    local neuron_id="$1"

    # 파일 제거
    find "$NEURONS_DIR" -name "${neuron_id}.md" -delete 2>/dev/null || true

    # 시냅스에서 제거
    local tmp_file="${SYNAPSES_FILE}.tmp"
    jq --arg id "$neuron_id" 'del(.neurons[$id]) | del(.synapses[$id+"-*"]) | del(.synapses["*-"+$id])' "$SYNAPSES_FILE" > "$tmp_file"
    mv "$tmp_file" "$SYNAPSES_FILE"

    log_debug "뉴런 제거됨: $neuron_id"
}

# ============================================================================
# Hippocampus (Session Memory)
# ============================================================================

# 세션 시작
brain_session_start() {
    local session_id="session-$$-$(date +%s)"
    local session_file="$HIPPOCAMPUS_DIR/sessions/${session_id}.md"

    cat > "$session_file" << EOF
# Session: $session_id

**Started**: $(date '+%Y-%m-%d %H:%M:%S')
**PID**: $$
**Working Directory**: $(pwd)

## Context

EOF

    echo "$session_id"
}

# 세션 기록
brain_session_record() {
    local session_id="$1"
    local event_type="$2"  # decision, bug, pattern, etc.
    local content="$3"

    local session_file="$HIPPOCAMPUS_DIR/sessions/${session_id}.md"

    cat >> "$session_file" << EOF

### [$event_type] $(date '+%H:%M:%S')

$content
EOF
}

# 세션 종료 및 고착화
brain_session_end() {
    local session_id="$1"

    local session_file="$HIPPOCAMPUS_DIR/sessions/${session_id}.md"

    # 종료 시간 기록
    cat >> "$session_file" << EOF

---

**Ended**: $(date '+%H:%M:%S')

EOF

    # 고착화 (중요한 것만 뉴런으로)
    brain_consolidate_session "$session_file"

    log_info "세션 종료: $session_id"
}

# 세션 고착화
brain_consolidate_session() {
    local session_file="$1"

    log_info "세션 고착화 중: $(basename "$session_file")"

    # TODO: 중요도 분석 후 뉴런 생성
    # 일단은 전체를 "conversation" 타입으로 저장
    local neuron_id
    neuron_id=$(brain_create_neuron "conversation" "Session Summary" "$(cat "$session_file")" "session,consolidated" "normal")

    log_info "고착화 완료: $neuron_id"
}

# ============================================================================
# Statistics
# ============================================================================

brain_stats() {
    echo "🧠 뇌 통계"
    echo ""

    local neuron_count=$(jq '.neurons | length' "$SYNAPSES_FILE")
    local synapse_count=$(jq '.synapses | length' "$SYNAPSES_FILE")

    echo "뉴런 수: $neuron_count"
    echo "시냅스 수: $synapse_count"

    if [[ "$neuron_count" -gt 0 ]]; then
        echo ""
        echo "타입별 분포:"
        jq -r '.neurons | [.[] | .type] | group_by(.) | map({type: .[0], count: length}) | .[] | "  \(.type): \(.count)"' "$SYNAPSES_FILE"

        echo ""
        echo "감정 분포:"
        jq -r '.neurons | [.[] | .emotional_weight] | group_by(.) | map({weight: .[0], count: length}) | sort_by(.weight) | reverse | .[] | "  weight=\(.weight): \(.count)"' "$SYNAPSES_FILE"
    else
        echo ""
        echo "(아직 저장된 기억이 없습니다. /brain save로 저장하세요)"
    fi
}

# ============================================================================
# Export for use
# ============================================================================

export -f brain_init
export -f brain_create_neuron
export -f brain_create_synapse
export -f brain_strengthen_synapse
export -f brain_query_by_tags
export -f brain_recall_neuron
export -f brain_session_start
export -f brain_session_end
export -f brain_stats
