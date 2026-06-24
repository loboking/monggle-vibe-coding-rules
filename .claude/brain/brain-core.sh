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

# 주의: 이 파일은 라이브러리로 'source' 되어 쓰인다.
# set -e/-u/pipefail 을 전역으로 걸면 호출 셸(훅·스킬)로 누출되어,
# 함수 내 사소한 비-제로 종료가 호출자 전체를 중단시킨다.
# 따라서 직접 실행될 때만 strict 모드를 적용한다.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    set -euo pipefail
fi

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

# 텍스트에서 '의미있는' 키워드 태그를 추출 (불용어/시스템토큰 제거).
# 사용: brain_extract_keywords "<text>" [max=4]
#   - 소문자화, 영숫자/한글만, 길이 3+ 영문 / 2+ 한글
#   - 시스템·잡토큰(tool, use, id, task, notification 등) + 흔한 불용어 제거
#   - 빈도 높은 순 상위 max개 (단순 빈도 정렬)
brain_extract_keywords() {
    local text="$1"
    local max="${2:-4}"
    # 불용어/시스템토큰 (공백 구분, 한 줄). 회상·저장 양쪽 공통.
    # 한국어 불용어는 조사제거 후 어근형도 포함(예: '예전에'→'예전').
    local STOP="tool tools toolu tooluse use used using id ids task tasks notification result results output input system command hook hooks the and for with that this you your are was were has have had not but can will would should could just 그리고 그래서 하지만 그런데 이거 저거 그거 우리 너무 지금 이제 그럼 근데 해줘 해서 했어 한거 인거 중인데 예전 비슷 고치 위해 대한 같은 어디 어떻게 무엇 흐름 추가 안함 즉시 필요 정리 항목마다 한시간"
    printf '%s' "$text" \
        | tr '[:upper:]' '[:lower:]' \
        | tr -cs '[:alnum:]가-힣' '\n' \
        | awk -v stop="$STOP" '
            BEGIN {
                n=split(stop, a, " "); for(i=1;i<=n;i++) if(a[i]!="") sw[a[i]]=1
                # 한국어 조사/어미 접미사 (긴 것 우선). UTF-8 한글=3바이트.
                ns=split("으로부터 에서부터 에게서 으로서 으로써 에서 에게 부터 까지 한테 으로 처럼 보다 이라 라고 하며 하고 해서 하는 했다 한다 하기 되어 되는 됐다 이 가 을 를 은 는 의 에 로 도 만 나 와 과 시 때 중 후 전", suf, " ")
            }
            # 한글 토큰 끝의 조사/어미 1회 제거. 어근 바이트>=6(한글2자) 보존(과도제거 차단).
            function strip_josa(w,   i,s,blen,wlen) {
                if (w !~ /[가-힣]/) return w
                wlen=length(w)
                for(i=1;i<=ns;i++){
                    s=suf[i]; blen=length(s)
                    if (wlen-blen >= 6 && substr(w, wlen-blen+1)==s) return substr(w, 1, wlen-blen)
                }
                return w
            }
            {
                w=$0
                # 길이 필터: 한글 포함이면 2자+(바이트 6+), 순영숫자면 3자+
                if (w ~ /[가-힣]/) { if (length(w) < 6) next }
                else { if (length(w) < 3) next }
                w=strip_josa(w)
                if (length(w) < 2) next
                if (w in sw) next
                if (!(w in seen)) { seen[w]=1; order[++c]=w }
                cnt[w]++
            }
            END { for(i=1;i<=c;i++) print cnt[order[i]], order[i] }
        ' \
        | sort -rn \
        | awk '{print $2}' \
        | head -n "$max" \
        | paste -sd ',' - 2>/dev/null || echo ""
}

# jq 결과 tmp 파일을 정본으로 안전하게 커밋.
# tmp 가 비었거나 유효한 JSON 이 아니면 mv 하지 않고 정본을 보존(데이터 소실 방지).
# 사용: jq '...' "$SYNAPSES_FILE" > "$tmp" && brain_atomic_commit "$tmp" "$SYNAPSES_FILE"
#   또는 mv 자리에 그대로 호출. 성공 0 / 실패(보존) 1.
brain_atomic_commit() {
    local tmp="$1" dest="$2"
    if [[ -s "$tmp" ]] && jq -e . "$tmp" >/dev/null 2>&1; then
        mv "$tmp" "$dest"
        return 0
    fi
    # 손상/빈 산출물 → 정본 보존, tmp 정리
    rm -f "$tmp" 2>/dev/null
    log_warn "brain: jq 산출물이 유효하지 않아 쓰기를 건너뜀(데이터 보존): $dest"
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
# 같은 초 + 같은 type 충돌을 막기 위해 고유 suffix 추가.
# 주의: $RANDOM 은 $(...) 서브셸에서 같은 값을 반복 반환하므로 단독 사용 금지.
# 나노초(있으면) + PID 조합으로 같은 초 다중 생성에도 충돌 없음.
brain_generate_id() {
    local type="$1"
    local nsec
    nsec=$(date +%N 2>/dev/null)
    # %N 미지원(BSD date) 시 '%N' 리터럴이 나오므로 폴백
    case "$nsec" in (*[!0-9]*|"") nsec=$(printf '%05d' "$((RANDOM % 100000))") ;; esac
    echo "n$(date +%Y%m%d%H%M%S)-${type}-${nsec:0:6}$$"
}

# 뉴런 생성
brain_create_neuron() {
    local type="$1"
    local title="$2"
    local content="$3"
    local tags="${4:-}"
    local emotion="${5:-normal}"

    # 본문 키워드 자동흡수: 본문(content)에서 의미 키워드를 추출해 태그에 병합.
    # 영문 태그만 들어와도 한글 본문어가 인덱스 tags에 포함되어 한글 질의 진입 가능.
    # (조사제거된 어근형 — brain_extract_keywords가 처리). 중복은 정규화 단계에서 제거.
    if [[ -n "$content" ]]; then
        local _body_kw
        _body_kw=$(brain_extract_keywords "$content" "${BRAIN_BODY_TAG_MAX:-5}" 2>/dev/null || echo "")
        if [[ -n "$_body_kw" ]]; then
            [[ -n "$tags" ]] && tags="${tags},${_body_kw}" || tags="$_body_kw"
            # 콤마 중복/공백 정규화 + 태그 dedup (순서 보존)
            tags=$(printf '%s' "$tags" | tr ',' '\n' | sed 's/^ *//;s/ *$//;/^$/d' | awk '!seen[$0]++' | paste -sd ',' -)
        fi
    fi

    # 중복 저장 방지(dedup): 같은 type 에 동일 title 의 뉴런이 최근 DEDUP_WINDOW 초
    # 내에 있으면 새로 만들지 않고 기존 id 반환. 훅 이중 등록/재발화 등 어떤 경로로
    # 중복돼도 메모리 오염을 막는 근본 안전장치.
    local _dd_window="${BRAIN_DEDUP_WINDOW:-300}"
    local _dd_dir="$NEURONS_DIR/$type"
    if [[ -n "$title" && -d "$_dd_dir" ]]; then
        local _dd_now _dd_f _dd_mt
        _dd_now=$(date +%s)
        for _dd_f in $(ls -t "$_dd_dir"/*.md 2>/dev/null | head -20); do
            _dd_mt=$(stat -f %m "$_dd_f" 2>/dev/null || stat -c %Y "$_dd_f" 2>/dev/null || echo 0)
            (( _dd_now - _dd_mt > _dd_window )) && break
            if grep -qxF "# ${title}" "$_dd_f" 2>/dev/null; then
                basename "$_dd_f" .md
                return 0
            fi
        done
    fi

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

    # Brain v2: 의미 태그 교집합 기반 자동 시냅스 연결 (조용히, 실패 무시).
    # link 실패가 뉴런 생성을 막지 않도록 항상 성공으로 흡수.
    brain_link_to_related "$neuron_id" >/dev/null 2>&1 || true

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
    # 빈 태그는 [] 로 정규화(빈 문자열이 [""] 가 되어 false-match 유발하는 것 방지)
    local tags_json
    if [[ -z "$tags" ]]; then
        tags_json="[]"
    else
        tags_json="[$(echo "$tags" | tr ',' '\n' | sed '/^$/d; s/\(.*\)/"\1"/' | paste -sd ',' -)]"
    fi

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
         "access_count": 0,
         "created": (now | todate),
         "last_accessed": (now | todate)
       }
       ' "$SYNAPSES_FILE" > "$tmp_file"

    brain_atomic_commit "$tmp_file" "$SYNAPSES_FILE" || return 1
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

    brain_atomic_commit "$tmp_file" "$SYNAPSES_FILE" || return 1

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

    brain_atomic_commit "$tmp_file" "$SYNAPSES_FILE" || return 1
}

# ============================================================================
# Synapse Auto-Linking (Brain v2)
# ============================================================================

# 신규 뉴런을 기존 뉴런과 '의미 태그' 교집합 기준으로 자동 연결.
#   - 'project' 등 흔한 공통 태그는 점수에서 제외(brain_query_by_tags와 동일 기준).
#   - overlap >= MIN_OVERLAP(2) 인 기존 뉴런과 양방향 시냅스 생성/강화.
#   - weight = 0.3 + overlap*0.1 (max 1.0).
#   - 자기 자신 제외, overlap 상위 MAX_LINKS(5)개로 제한.
#   - 성능/원자성을 위해 단일 jq 트랜잭션으로 처리.
# 사용: brain_link_to_related "<new_neuron_id>"
# 실패해도 0 반환(뉴런 생성을 막지 않도록 호출처에서 '|| true' 사용 권장).
brain_link_to_related() {
    local new_id="$1"
    local MAX_LINKS="${2:-5}"
    # MIN_OVERLAP 1: 의미태그 1개만 겹쳐도 연결(연상회상 강화).
    # MAX_LINKS 상한 + 대칭 trim 으로 허브 과연결은 별도 통제됨.
    local MIN_OVERLAP="${3:-1}"

    [[ -z "$new_id" ]] && return 0
    [[ -f "$SYNAPSES_FILE" ]] || return 0

    local tmp_file="${SYNAPSES_FILE}.tmp"

    # 단일 jq 트랜잭션:
    #   1) 신규 뉴런의 의미태그($sig) 계산
    #   2) 다른 모든 뉴런과 overlap 계산, MIN_OVERLAP 이상만, overlap 내림차순 상위 MAX_LINKS
    #   3) 각 대상에 대해 양방향 시냅스 생성(없으면) 또는 강화(있으면 weight += 0.1, max 1.0)
    #   4) synapses_out 에 중복 없이 추가
    jq --arg new "$new_id" \
       --argjson maxlinks "$MAX_LINKS" \
       --argjson minoverlap "$MIN_OVERLAP" \
       '
       # 흔한 공통 태그 제외 기준 (query 로직과 동일)
       def strip: . - ["project"];

       . as $root |
       ($root.neurons[$new].tags // []) as $newtags |
       ($newtags | strip) as $sig |

       # 연결 후보: 자기 자신 제외, 의미태그 overlap >= minoverlap, 상위 maxlinks
       (
         $root.neurons
         | to_entries
         | map(select(.key != $new))
         | map(. + {overlap: (((.value.tags // []) | strip) - ((((.value.tags // []) | strip)) - $sig) | length)})
         | map(select(.overlap >= $minoverlap))
         | sort_by(-(.overlap))
         | .[0:$maxlinks]
       ) as $targets |

       # weight 헬퍼
       def linkweight(o): ([0.3 + (o * 0.1), 1.0] | min);

       # 각 후보에 대해 양방향 시냅스 생성/강화 (reduce 누적)
       reduce $targets[] as $t (.;
         . as $st |
         $t.key as $tid |
         linkweight($t.overlap) as $w |
         ($new + "-" + $tid) as $fwd |
         ($tid + "-" + $new) as $bwd |

         # 정방향 시냅스: 신규 -> 대상
         (if ($st.synapses[$fwd]) then
            $st
            | .synapses[$fwd].weight = ([.synapses[$fwd].weight + 0.1, 1.0] | min)
            | .synapses[$fwd].activation_count += 1
            | .synapses[$fwd].last_activation = (now | todate)
          else
            $st
            | .synapses[$fwd] = {
                "source": $new,
                "target": $tid,
                "weight": $w,
                "decay_rate": 0.001,
                "last_activation": (now | todate),
                "activation_count": 1,
                "emotional_weight": (.neurons[$new].emotional_weight // 0.5),
                "prediction_error": 0.0,
                "created": (now | todate),
                "auto_linked": true
              }
            | .neurons[$new].synapses_out =
                (((.neurons[$new].synapses_out // []) + [$tid]) | unique)
          end)
         | . as $st2 |

         # 역방향 시냅스: 대상 -> 신규
         (if ($st2.synapses[$bwd]) then
            $st2
            | .synapses[$bwd].weight = ([.synapses[$bwd].weight + 0.1, 1.0] | min)
            | .synapses[$bwd].activation_count += 1
            | .synapses[$bwd].last_activation = (now | todate)
          else
            $st2
            | .synapses[$bwd] = {
                "source": $tid,
                "target": $new,
                "weight": $w,
                "decay_rate": 0.001,
                "last_activation": (now | todate),
                "activation_count": 1,
                "emotional_weight": (.neurons[$tid].emotional_weight // 0.5),
                "prediction_error": 0.0,
                "created": (now | todate),
                "auto_linked": true
              }
            | .neurons[$tid].synapses_out =
                (((.neurons[$tid].synapses_out // []) + [$new]) | unique)
          end)
       )
       # MAX_LINKS 대칭 보정 (Brain v4 ③):
       #   허브 뉴런 무한 누적 방지를 위해 각 뉴런의 정방향 링크를 weight 상위
       #   maxlinks 로 trim 하되, 시냅스를 쌍(pair) 단위로 유지/제거하여 양방향 대칭
       #   불변식을 보장한다 (A→B 존재 ⟺ B→A 존재).
       #
       #   절차:
       #   1) 각 뉴런 nid 의 keep 집합 = 정방향 weight 상위 maxlinks 의 target.
       #   2) 페어 a-b 가 살아남으려면 [a 의 keep 에 b] AND [b 의 keep 에 a] 둘 다.
       #      한쪽이라도 trim 되면 양방향 모두 제거(동반 삭제) -> 대칭 유지.
       #   3) 살아남은 정방향 시냅스로 synapses_out 재구성(dangling/orphan 0).
       | . as $final
       # 각 뉴런별 keep 집합을 객체로 구성: { nid: [keepTargets] }
       | reduce ($final.neurons | keys[]) as $nid ({keepmap: {}, root: $final};
           .root as $r
           | ((($r.neurons[$nid].synapses_out // [])
               | map({tid: ., w: ($r.synapses[($nid + "-" + .)].weight // 0)})
               | sort_by(-(.w))
               | .[0:$maxlinks]
               | map(.tid))) as $keep
           | .keepmap[$nid] = $keep
         )
       | .keepmap as $keepmap
       | $final
       # 시냅스: 양쪽 모두 서로를 keep 할 때만 생존
       | .synapses = (.synapses | with_entries(
           .value.source as $s
           | .value.target as $t
           | select(
               (($keepmap[$s] // []) | index($t)) != null
               and (($keepmap[$t] // []) | index($s)) != null
             )))
       # synapses_out: 생존한 정방향 시냅스 기준으로 재구성 (대칭/일관성)
       | .synapses as $surv
       | .neurons = (.neurons | with_entries(
           .key as $nid
           | .value.synapses_out = (
               $surv | to_entries
               | map(select(.value.source == $nid) | .value.target)
               | unique)
         ))
       ' "$SYNAPSES_FILE" > "$tmp_file" 2>/dev/null || { rm -f "$tmp_file"; return 0; }

    # jq 산출물이 유효 JSON 인지 확인 후 교체(원자성 + 손상 방지)
    if [[ -s "$tmp_file" ]] && jq -e . "$tmp_file" >/dev/null 2>&1; then
        mv "$tmp_file" "$SYNAPSES_FILE"
        log_debug "자동 시냅스 연결 완료: $new_id"
    else
        rm -f "$tmp_file"
    fi

    return 0
}

# ============================================================================
# Memory Retrieval
# ============================================================================

# 태그로 뉴런 검색
brain_query_by_tags() {
    local tags="$1"  # 콤마로 구분
    local limit="${2:-10}"
    local min_overlap="${3:-1}"  # 최소 교집합 수 (흔한 공통태그 노이즈 컷용)

    local tmp_file="${SYNAPSES_FILE}.tmp"

    # 태그 배열로 변환 (질의 태그 lowercase 정규화 — 대소문자 무관 매칭)
    local search_tags="[$(echo "$tags" | tr ',' '\n' | tr '[:upper:]' '[:lower:]' | sed 's/^ *//;s/ *$//;/^$/d; s/\(.*\)/"\1"/' | paste -sd ',' -)]"

    # 매칭: 검색 태그와 뉴런 태그의 '교집합'이 1개 이상이면 회상(OR).
    #   - 겹치는 태그 수(overlap)가 많을수록, 감정가중치가 높을수록 상위.
    #   - 흔한 공통 태그('project', 프로젝트명)만 겹치는 경우를 피하려면
    #     overlap >= 2 를 우선하되, 1개라도 의미태그면 포함.
    jq -r --argjson tags "$search_tags" \
       --argjson limit "$limit" \
       --argjson min_overlap "$min_overlap" \
       '
       # 흔한 공통 태그(거의 모든 뉴런에 붙는 것)는 매칭 점수에서 제외
       ($tags - ["project"]) as $sig |
       .neurons |
       to_entries
       # 뉴런 태그도 lowercase 정규화 (저장 측 대소문자 무관)
       | map(.ntags = ((.value.tags // []) | map(ascii_downcase)))
       # overlap: 질의태그 q 중, 어떤 저장태그 t 와든 매칭되는 개수
       #   - q 길이 3+(영문)/2+(한글): 양방향 substring (부분일치)
       #   - q 짧음: 정확일치만 (과매칭 가드)
       | map(.overlap = ([ $sig[] as $q
             | (if (($q|test("[가-힣]")) and ($q|length)>=2) or (($q|length)>=3) then "sub" else "exact" end) as $mode
             | select(any(.ntags[]; . as $t |
                 if $mode=="sub" then ($t|contains($q)) or ($q|contains($t)) else ($t==$q) end)) ] | length))
       | map(select(.overlap >= $min_overlap))
       | sort_by(-(.overlap), -(.value.emotional_weight))
       | .[]
       | {id: .key, type: .value.type, weight: .value.emotional_weight, tags: .value.tags, overlap: .overlap}
       | "- \(.id) (\(.type)): \(.tags | join(", ")) (weight: \(.weight), match: \(.overlap))"
       ' "$SYNAPSES_FILE" 2>/dev/null | head -n "$limit"
}

# 태그 검색 + 시냅스 확장 회상 (Brain v2)
#   1차: 태그 overlap 매칭(brain_query_by_tags 와 동일 기준).
#   2차: 1차 결과 뉴런의 synapses_out 으로 연결된 뉴런을 추가(중복 제거).
#   - 연결로 들어온 뉴런은 match=0 + '(linked)' 표시.
#   - 전체 limit 내로 자른다(1차 우선, 남는 자리에 2차 채움).
# 시그니처는 brain_query_by_tags 와 동일(tags, limit, min_overlap).
brain_query_with_links() {
    local tags="$1"
    local limit="${2:-10}"
    local min_overlap="${3:-1}"
    # linked 표면화 게이트: 이 weight 미만 + 질의무관 연결은 노이즈로 컷.
    # 0.45: 본문키워드 흡수로 생긴 약한 태그연결(w0.4, 흔한 본문어 공유)은 컷,
    #       진짜 태그연결(w0.5+)·질의관련 연결은 보존.
    local floor="${BRAIN_LINK_SURFACE_FLOOR:-0.45}"

    local search_tags="[$(echo "$tags" | tr ',' '\n' | tr '[:upper:]' '[:lower:]' | sed 's/^ *//;s/ *$//;/^$/d; s/\(.*\)/"\1"/' | paste -sd ',' -)]"

    jq -r --argjson tags "$search_tags" \
       --argjson limit "$limit" \
       --argjson min_overlap "$min_overlap" \
       --argjson floor "$floor" \
       '
       ($tags - ["project"]) as $sig |
       . as $root |

       # 1차: 직접 태그 매칭 (정규화+부분일치, brain_query_by_tags와 동일 기준)
       (
         $root.neurons
         | to_entries
         | map(.ntags = ((.value.tags // []) | map(ascii_downcase)))
         | map(.overlap = ([ $sig[] as $q
               | (if (($q|test("[가-힣]")) and ($q|length)>=2) or (($q|length)>=3) then "sub" else "exact" end) as $mode
               | select(any(.ntags[]; . as $t |
                   if $mode=="sub" then ($t|contains($q)) or ($q|contains($t)) else ($t==$q) end)) ] | length))
         | map(select(.overlap >= $min_overlap))
         | sort_by(-(.overlap), -(.value.emotional_weight))
       ) as $primary |

       ($primary | map(.key)) as $primary_ids |

       # 2차: 1차 결과의 synapses_out (연결된 뉴런), 1차에 없는 것만, 중복 제거.
       #   게이트: 연결 시냅스 weight >= floor (태그연결급) OR
       #           linked 노드 태그가 질의어와 부분일치(질의관련성) 일 때만 표면화.
       #   → match:0 순수 구조 노이즈(약한 본문연결·무관 클러스터) 제거.
       (
         [ $primary[] | .key as $src | (.value.synapses_out // [])[]
           | { tid: ., w: ($root.synapses[($src + "-" + .)].weight // 0) } ]
         | group_by(.tid) | map({tid: .[0].tid, w: ([.[].w] | max)})
         | map(select(.tid as $id | ($primary_ids | index($id)) | not))
         | map(select(.tid as $id | $root.neurons[$id] != null))
         # 게이트 적용
         | map(. + {ntags: ((($root.neurons[.tid].tags) // []) | map(ascii_downcase))})
         | map(select(
             (.w >= $floor)
             # 질의어가 linked 노드 태그와 부분일치하는지. .ntags를 변수로 고정해
             # any($sig[];...) 내부에서 '.'이 $sig 원소로 바뀌어도 안전하게 참조.
             or (.ntags as $nt | any($sig[]; . as $q | any($nt[]; . as $t | ($t|contains($q)) or ($q|contains($t)))))
           ))
         | map({key: .tid, value: $root.neurons[.tid], overlap: 0, linked: true, lw: .w})
       ) as $linked |

       # 1차 + 2차 결합 후 limit 컷 (1차 우선)
       ($primary + $linked)
       | .[0:$limit]
       | .[]
       | {id: .key, type: .value.type, weight: .value.emotional_weight, tags: .value.tags, overlap: .overlap, linked: (.linked // false), lw: (.lw // 0)}
       | "- \(.id) (\(.type)): \(.tags | join(", ")) (weight: \(.weight), match: \(.overlap))\(if .linked then " (linked w\(.lw))" else "" end)"
       ' "$SYNAPSES_FILE" 2>/dev/null | head -n "$limit"
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

# 뉴런 본문 발췌 (읽기 전용, access_count 미증가)
#   - frontmatter(--- ... ---) 제외, '## 내용' 섹션 본문만 추출.
#   - 다음 '## ' 헤더 또는 EOF 까지를 내용으로 본다.
#   - 시스템 JSON 오염 본문(차단 패턴)은 발췌하지 않고 빈 출력(노이즈 컷).
#   - maxchars(기본 200) 로 자르고, 한 줄로 정규화하여 한 줄 발췌로 반환.
# 사용: brain_recall_excerpt "<neuron_id>" [maxchars=200]
# 성공 시 발췌 출력, 없거나 차단/빈 본문이면 빈 문자열 + 0 반환(안전).
brain_recall_excerpt() {
    local neuron_id="$1"
    local maxchars="${2:-200}"

    [[ -z "$neuron_id" ]] && return 0

    local neuron_file
    neuron_file=$(find "$NEURONS_DIR" -name "${neuron_id}.md" 2>/dev/null | head -1)
    [[ -z "$neuron_file" || ! -f "$neuron_file" ]] && return 0

    # '## 내용' 다음 줄부터 다음 '## ' 또는 EOF 전까지 본문 추출 (awk, BSD 호환).
    local body
    body=$(awk '
        /^## 내용[[:space:]]*$/ { grab=1; next }
        grab && /^## / { grab=0 }
        grab { print }
    ' "$neuron_file" 2>/dev/null)

    # 앞뒤 빈 줄 제거 + 한 줄로 정규화
    body=$(printf '%s' "$body" | tr '\n' ' ' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/[[:space:]]\{2,\}/ /g')

    [[ -z "$body" ]] && return 0

    # 시스템/도구 JSON 으로 오염된 본문은 발췌 차단 (회상 노이즈 0)
    case "$body" in
        *'<task-notification'*|*'<command-'*|*'tool_use_id'*|*'tool_result'*|\
        *'"type":"tool'*|*'"type": "tool'*|*'Workflow launched'*|\
        *'hook additional context'*|*'system-reminder'*|*'Caveat:'*)
            return 0 ;;
    esac

    # maxchars 로 자르기 (잘리면 … 부착)
    # head -c 바이트 절단 후 iconv -c 로 깨진 멀티바이트(한글 중간 잘림) 제거
    if [[ ${#body} -gt $maxchars ]]; then
        body="$(printf '%s' "$body" | head -c "$maxchars" | iconv -c -f UTF-8 -t UTF-8 2>/dev/null || printf '%s' "$body" | head -c "$maxchars")…"
    fi

    printf '%s' "$body"
    return 0
}

# 접근 업데이트
brain_update_access() {
    local neuron_id="$1"

    local tmp_file="${SYNAPSES_FILE}.tmp"

    jq --arg id "$neuron_id" \
       '
       .neurons[$id].last_accessed = (now | todate) |
       .neurons[$id].access_count = ((.neurons[$id].access_count // 0) + 1)
       ' "$SYNAPSES_FILE" > "$tmp_file"

    brain_atomic_commit "$tmp_file" "$SYNAPSES_FILE" || return 1
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
    brain_atomic_commit "$tmp_file" "$SYNAPSES_FILE" || return 1

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

# 세션 고착화 (Brain v4 ②: 중요도 필터)
#   - 세션 통째 덤프 폐지. 중요도 판정 후 의미있는 세션만 뉴런화.
#   - 스킵 조건:
#       (a) 시스템메시지/도구 오염 패턴 포함 → 미저장(오염 세션)
#       (b) 정제 본문 길이가 너무 짧음 → 미저장(잡음)
#   - 중요도:
#       감정/키워드(결정/버그/수정/중요 등) 신호 있으면 important, 없으면 normal
#   - 저장 시: 세션 통째가 아니라 시스템 라인 제외한 핵심 본문 1000자 제한.
#     태그는 brain_extract_keywords 로 추출.
#   - 안전: 어떤 실패도 세션종료 흐름을 막지 않음(항상 0 반환).
brain_consolidate_session() {
    local session_file="$1"

    [[ -f "$session_file" ]] || return 0

    log_info "세션 고착화 중: $(basename "$session_file")"

    # 1) 시스템/도구 메시지 라인 제외 + Markdown 헤더/구분선 제외하여 정제 본문 추출.
    #    grep -v 로 라인 단위 차단(BSD/macOS grep 호환, -E 사용).
    local clean
    clean=$(grep -vE '<task-notification|<command-|tool_use_id|tool_result|"type":[[:space:]]*"tool|Workflow launched|hook additional context|system-reminder|Caveat:|^#|^---|^\*\*Started|^\*\*Ended|^\*\*PID|^\*\*Working' "$session_file" 2>/dev/null \
        | tr -s '[:space:]' ' ' \
        | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

    # 2) (a) 오염 세션 차단: 정제 전 원본에 시스템 차단 패턴이 광범위하면 스킵.
    #    정제로 라인 제거가 되더라도, 본문 전반이 시스템 메시지인 세션은 미저장.
    if grep -qE '<task-notification|tool_use_id|tool_result|"type":[[:space:]]*"tool|system-reminder|Workflow launched' "$session_file" 2>/dev/null; then
        # 차단 패턴이 존재하면, 정제 후 의미본문이 충분히 남았는지로 판단.
        # 정제 본문이 짧으면(오염이 본문 대부분) 스킵.
        if [[ ${#clean} -lt 80 ]]; then
            log_info "고착화 스킵(오염 세션): $(basename "$session_file")"
            return 0
        fi
    fi

    # 3) (b) 너무 짧은 세션 스킵 (의미 미달)
    if [[ ${#clean} -lt 40 ]]; then
        log_info "고착화 스킵(본문 부족): $(basename "$session_file")"
        return 0
    fi

    # 4) 중요도 판정: 감정/핵심 키워드 신호
    local emotion="normal"
    case "$clean" in
        *결정*|*버그*|*수정*|*중요*|*긴급*|*에러*|*오류*|*고침*|*해결*|\
        *decision*|*bug*|*fix*|*important*|*critical*|*urgent*|*error*)
            emotion="important" ;;
    esac

    # 5) 핵심 본문 1000자 제한
    local body="$clean"
    if [[ ${#body} -gt 1000 ]]; then
        body="$(printf '%s' "$body" | head -c 1000 | iconv -c -f UTF-8 -t UTF-8 2>/dev/null || printf '%s' "$body" | head -c 1000)…"
    fi

    # 6) 태그 추출 (키워드 + 메타 태그)
    local kw
    kw=$(brain_extract_keywords "$clean" 4 2>/dev/null || echo "")
    local tags="session,consolidated"
    [[ -n "$kw" ]] && tags="$tags,$kw"

    local neuron_id
    neuron_id=$(brain_create_neuron "conversation" "Session Summary" "$body" "$tags" "$emotion" 2>/dev/null || echo "")

    if [[ -n "$neuron_id" ]]; then
        log_info "고착화 완료: $neuron_id ($emotion)"
    else
        log_warn "고착화 실패(무시): $(basename "$session_file")"
    fi

    return 0
}

# ============================================================================
# Cortex Hot-Cache (Brain v4 ①)
# ============================================================================

# 인덱스에서 access_count 상위 N개 뉴런으로 핫캐시($CORTEX_FILE)를 재작성.
#   - 정렬: access_count desc, 동률 시 emotional_weight desc, 그다음 last_accessed desc
#   - 형식: "# 🧠 핫 캐시" 헤더 + "- <id> (type): <태그 일부> [접근 N회]" 한 줄씩
#   - 빈 뇌면 기존 placeholder 유지(덮어쓰지 않음)
#   - 안전: 실패해도 정본 보존, 호출 흐름 비차단 (항상 0 반환)
# 사용: brain_update_hotcache [N=7]
brain_update_hotcache() {
    local top_n="${1:-7}"

    [[ -f "$SYNAPSES_FILE" ]] || return 0
    mkdir -p "$(dirname "$CORTEX_FILE")" 2>/dev/null || true

    # 뉴런이 하나도 없으면 placeholder 보존
    local ncount
    ncount=$(jq -r '.neurons | length' "$SYNAPSES_FILE" 2>/dev/null || echo "0")
    case "$ncount" in (*[!0-9]*|"") ncount=0 ;; esac
    if [[ "$ncount" -eq 0 ]]; then
        return 0
    fi

    local tmp_file="${CORTEX_FILE}.tmp"

    {
        echo "# 🧠 핫 캐시"
        echo ""
        # 정렬 키: access_count desc, emotional_weight desc, last_accessed desc.
        # jq sort_by 는 안정 정렬이지만 문자열 desc 를 음수로 못 만들므로,
        # last_accessed 는 먼저(asc) 정렬한 뒤 reverse 로 desc 화하고,
        # 이후 access_count/emotional_weight 안정 정렬을 적용하면
        # 동률 그룹 내에서 last_accessed desc 가 유지된다.
        jq -r --argjson n "$top_n" '
            .neurons
            | to_entries
            | sort_by(.value.last_accessed // "")
            | reverse
            | sort_by(-((.value.access_count // 0)), -((.value.emotional_weight // 0)))
            | .[0:$n]
            | .[]
            | . as $e
            | (($e.value.tags // []) | .[0:2] | join(", ")) as $tagpart
            | "- \($e.key) (\($e.value.type // "?")): \($tagpart) [접근 \(($e.value.access_count // 0))회]"
        ' "$SYNAPSES_FILE" 2>/dev/null
    } > "$tmp_file"

    # 산출물이 헤더만이라도 있으면(>0) 교체. 빈 산출물이면 정본 보존.
    if [[ -s "$tmp_file" ]]; then
        mv "$tmp_file" "$CORTEX_FILE" 2>/dev/null || rm -f "$tmp_file" 2>/dev/null
    else
        rm -f "$tmp_file" 2>/dev/null
    fi

    return 0
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
export -f brain_link_to_related
export -f brain_query_by_tags
export -f brain_query_with_links
export -f brain_extract_keywords
export -f brain_atomic_commit
export -f brain_recall_neuron
export -f brain_recall_excerpt
export -f brain_update_hotcache
export -f brain_session_start
export -f brain_session_end
export -f brain_stats
