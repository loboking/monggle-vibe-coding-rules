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
# user role 의 가장 최근 텍스트 한 건.
LAST_USER="$(jq -rs '
    map(select(.type? == "user" or .role? == "user"))
    | last
    | (.message.content // .content // "")
    | if type == "array" then (map(.text? // "") | join(" ")) else tostring end
' "$TRANSCRIPT" 2>/dev/null || echo "")"

# 폴백: 위 스키마가 안 맞으면 마지막 user 라인 raw
[[ -z "$LAST_USER" || "$LAST_USER" == "null" ]] && \
    LAST_USER="$(grep -E '"role"\s*:\s*"user"|"type"\s*:\s*"user"' "$TRANSCRIPT" 2>/dev/null | tail -1 | jq -r '.message.content // .content // ""' 2>/dev/null | head -c 500 || echo "")"

[[ -z "$LAST_USER" || "$LAST_USER" == "null" ]] && exit 0

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
[[ $IMPORTANT -eq 0 && $ACTION -eq 0 ]] && exit 0

# --- 뇌 코어 로드 후 저장 ---
BRAIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../brain" 2>/dev/null && pwd)" || exit 0
[[ -f "$BRAIN_ROOT/brain-core.sh" ]] || exit 0
source "$BRAIN_ROOT/brain-core.sh" >/dev/null 2>&1 || exit 0

PROJECT="$(basename "$(pwd)" 2>/dev/null || echo "")"

# 제목: 메시지 앞부분 요약(80자), 내용: 메시지 전문(1000자 제한)
TITLE="$(printf '%s' "$LAST_USER" | tr '\n' ' ' | head -c 80)"
CONTENT="$(printf '%s' "$LAST_USER" | head -c 1000)"

# 태그: project + 프로젝트명 + 신호 종류 + 의미 키워드 일부
TAGS="project"
[[ -n "$PROJECT" ]] && TAGS="$TAGS,$PROJECT"
[[ $IMPORTANT -eq 1 ]] && TAGS="$TAGS,decision"
[[ $ACTION -eq 1 ]] && TAGS="$TAGS,change"
KW="$(printf '%s' "$LAST_USER" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]가-힣' '\n' | awk 'length($0)>=2' | head -4 | paste -sd ',' - 2>/dev/null || echo "")"
[[ -n "$KW" ]] && TAGS="$TAGS,$KW"

# 메시지 단위 뉴런 저장 (조용히)
brain_create_neuron "context" "$TITLE" "$CONTENT" "$TAGS" "$EMOTION" >/dev/null 2>&1 || true

exit 0
