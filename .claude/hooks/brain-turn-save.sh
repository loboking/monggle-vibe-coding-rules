#!/bin/bash
#
# brain-turn-save.sh - Stop 훅
#
# Claude 응답이 끝날 때마다 실행됨. 직전 사용자 메시지를 중요도 선별하여
# '의미있는' 턴만 메시지 단위 뉴런으로 저장한다 (잡담 폭증 방지).
#
# 선별 (v1: 자동 2단계):
#   1) 키워드 신호: 결정/버그/수정/하지마/기억해/중요/주의 등 → 저장 + 감정 상향
#   2) 행동 신호:   이번 세션에 git 변경(파일 수정/커밋)이 있으면 저장
#   (AI 판단은 v3)
#
# 입력(stdin): {"transcript_path": "...", "session_id": "...", ...}
# 안전: 어떤 실패도 대화를 막지 않는다 (항상 exit 0).
# 재진입 가드: 이 훅은 brain_* 만 호출하고 새 턴을 만들지 않으므로 Stop 루프 없음.

set -uo pipefail

INPUT="$(cat 2>/dev/null || echo '{}')"

command -v jq &>/dev/null || exit 0

TRANSCRIPT="$(printf '%s' "$INPUT" | jq -r '.transcript_path // ""' 2>/dev/null || echo "")"
[[ -z "$TRANSCRIPT" || ! -f "$TRANSCRIPT" ]] && exit 0

# --- 마지막 사용자 메시지 추출 (transcript 는 JSONL) ---
# user role 의 가장 최근 '진짜 사람 입력' 한 건.
#   content 가 array 면 type=="text" 블록만 취하고 tool_result/tool_use 는 제외.
#   (도구 결과·도구 호출 블록은 사람 입력이 아니므로 본문 저장 대상이 아님)
LAST_USER="$(jq -rs '
    map(select(.type? == "user" or .role? == "user"))
    | last
    | (.message.content // .content // "")
    | if type == "array" then
        ( map(select((.type? == "text") or (.type? == null and (.text? != null))))
          | map(.text? // "")
          | map(select(. != ""))
          | join(" ") )
      else tostring end
' "$TRANSCRIPT" 2>/dev/null || echo "")"

# 폴백: 위 스키마가 안 맞으면 마지막 user 라인 raw (text 블록만)
[[ -z "$LAST_USER" || "$LAST_USER" == "null" ]] && \
    LAST_USER="$(grep -E '"role"[[:space:]]*:[[:space:]]*"user"|"type"[[:space:]]*:[[:space:]]*"user"' "$TRANSCRIPT" 2>/dev/null | tail -1 | jq -r '
        (.message.content // .content // "")
        | if type == "array" then
            ( map(select((.type? == "text") or (.type? == null and (.text? != null))))
              | map(.text? // "") | map(select(. != "")) | join(" ") )
          else tostring end
    ' 2>/dev/null | head -c 500 || echo "")"

[[ -z "$LAST_USER" || "$LAST_USER" == "null" ]] && exit 0

# --- [ⓐ] 시스템/도구 메시지 본문 저장 차단 ---
# Claude 응답에 섞인 시스템 메시지(task-notification, tool_result, hook context 등)가
# 'user 메시지'로 오인돼 본문째 저장되는 것을 막는다. 패턴 매치 시 조용히 종료.
# grep -F: 정규식 특수문자(< " :)를 리터럴로 취급. -i: 대소문자 무시.
if printf '%s' "$LAST_USER" | grep -qiF \
    -e '<task-notification' \
    -e '<command-' \
    -e 'tool_use_id' \
    -e 'tool_result' \
    -e '"type":"tool' \
    -e '"type": "tool' \
    -e 'Workflow launched' \
    -e 'hook additional context' \
    -e 'system-reminder' \
    -e 'Caveat:'; then
    exit 0
fi

# --- 잡담 컷: 너무 짧은 메시지(인사/확인)는 제외 ---
LEN=${#LAST_USER}
[[ $LEN -lt 8 ]] && exit 0

# --- 1) 키워드 신호 ---
EMOTION="normal"
IMPORTANT=0
if printf '%s' "$LAST_USER" | grep -qiE '결정|채택|버그|오류|수정|고침|고쳐|하지\s?마|금지|기억해|중요|주의|반드시|never|always|decision|important|bug|fix'; then
    IMPORTANT=1
    EMOTION="important"
fi
# 긴급 신호는 더 강하게
if printf '%s' "$LAST_USER" | grep -qiE '긴급|반드시|절대|critical|urgent|배포|deploy'; then
    EMOTION="critical"
fi

# --- 2) 행동 신호: 이번 작업트리에 변경이 있었나 (git) ---
ACTION=0
if command -v git &>/dev/null && git rev-parse --git-dir &>/dev/null 2>&1; then
    if [[ -n "$(git status --porcelain 2>/dev/null | head -1)" ]]; then
        ACTION=1
    fi
fi

# 키워드도 행동도 없으면 저장 안 함 (잡담/단순질문 컷)
# (기본 원칙 유지: ⓒ 휴리스틱은 저장 여부를 바꾸지 않고 emotion 가중치만 미세조정)
[[ $IMPORTANT -eq 0 && $ACTION -eq 0 ]] && exit 0

# --- [ⓒ] AI 중요도 '약한 신호' 휴리스틱 (emotion 미세조정만) ---
# 키워드/행동으로 이미 저장이 확정된 턴에 한해, 약한 신호로 가중치를 살짝 조정.
# (저장 여부는 절대 바꾸지 않음. 실제 LLM 판단은 v4 백로그.)
# normal 인 경우에만 상향 후보 — 이미 important/critical 이면 건드리지 않음.
if [[ "$EMOTION" == "normal" ]]; then
    WEAK=0
    # 신호1: 충분히 긴 본문(설명/맥락이 담긴 메시지일 가능성)
    [[ $LEN -ge 200 ]] && WEAK=$((WEAK + 1))
    # 신호2: 코드블록 포함(코드 공유/구현 논의 가능성)
    printf '%s' "$LAST_USER" | grep -qF '```' && WEAK=$((WEAK + 1))
    # 신호3: 물음표 '부재' (질문이 아닌 지시/서술은 결정·기록 가치가 더 높은 경향)
    case "$LAST_USER" in (*'?'*|*'？'*) : ;; (*) WEAK=$((WEAK + 1)) ;; esac
    # 약한 신호 2개 이상이면 normal -> important 로만 한 단계 상향
    [[ $WEAK -ge 2 ]] && EMOTION="important"
fi

# --- 뇌 코어 로드 후 저장 ---
BRAIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../brain" 2>/dev/null && pwd)" || exit 0
[[ -f "$BRAIN_ROOT/brain-core.sh" ]] || exit 0
source "$BRAIN_ROOT/brain-core.sh" >/dev/null 2>&1 || exit 0

PROJECT="$(basename "$(pwd)" 2>/dev/null || echo "")"

# 제목: 메시지 앞부분 요약(80B), 내용: 메시지 전문(BRAIN_BODY_MAXCHARS B, 기본 2500).
# head -c 는 바이트 단위라 한글(UTF-8 3바이트) 중간에서 잘리면 깨진 바이트가
# 남는다 → iconv -c 로 불완전 멀티바이트 시퀀스를 제거(없으면 원본 유지).
# 본문 한도는 키워드 추출 원천 보존을 위해 brain-core 와 동일 변수로 통일.
BRAIN_BODY_MAXCHARS="${BRAIN_BODY_MAXCHARS:-2500}"
TITLE="$(printf '%s' "$LAST_USER" | tr '\n' ' ' | head -c 80 | iconv -c -f UTF-8 -t UTF-8 2>/dev/null || printf '%s' "$LAST_USER" | tr '\n' ' ' | head -c 80)"
CONTENT="$(printf '%s' "$LAST_USER" | head -c "$BRAIN_BODY_MAXCHARS" | iconv -c -f UTF-8 -t UTF-8 2>/dev/null || printf '%s' "$LAST_USER" | head -c "$BRAIN_BODY_MAXCHARS")"

# 태그: project + 프로젝트명 + 신호 종류 + 의미 키워드 일부
TAGS="project"
[[ -n "$PROJECT" ]] && TAGS="$TAGS,$PROJECT"
[[ $IMPORTANT -eq 1 ]] && TAGS="$TAGS,decision"
[[ $ACTION -eq 1 ]] && TAGS="$TAGS,change"
KW="$(brain_extract_keywords "$LAST_USER" 4 2>/dev/null || echo "")"
[[ -n "$KW" ]] && TAGS="$TAGS,$KW"

# 메시지 단위 뉴런 저장 (조용히)
brain_create_neuron "context" "$TITLE" "$CONTENT" "$TAGS" "$EMOTION" >/dev/null 2>&1 || true

exit 0
