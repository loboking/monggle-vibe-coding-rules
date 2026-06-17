#!/bin/bash
#
# brain-prompt-recall.sh - UserPromptSubmit 훅
#
# 사용자가 메시지를 보낼 때마다 실행됨. 메시지 내용에서 키워드를 뽑아
# 관련 과거 뉴런을 회상하고, hookSpecificOutput.additionalContext 로
# Claude 컨텍스트에 '조용히' 주입한다 (사용자 화면을 덮지 않음).
#
# 입력(stdin): {"prompt": "...", "session_id": "...", "cwd": "...", ...}
# 출력(stdout): {"hookSpecificOutput": {"hookEventName": "UserPromptSubmit",
#                "additionalContext": "..."}}
#
# 안전: 어떤 실패도 대화를 막지 않는다 (항상 exit 0, 실패 시 빈 출력).

set -uo pipefail

# --- 입력 읽기 (stdin JSON) ---
INPUT="$(cat 2>/dev/null || echo '{}')"

# jq 없으면 조용히 통과 (회상 불가하나 대화는 정상)
if ! command -v jq &>/dev/null; then
    exit 0
fi

PROMPT="$(printf '%s' "$INPUT" | jq -r '.prompt // ""' 2>/dev/null || echo "")"
[[ -z "$PROMPT" ]] && exit 0

# --- 뇌 코어 로드 ---
BRAIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../brain" 2>/dev/null && pwd)" || exit 0
[[ -f "$BRAIN_ROOT/brain-core.sh" ]] || exit 0
# log_* 가 stdout 을 오염시키지 않도록 회상 출력만 캡처
source "$BRAIN_ROOT/brain-core.sh" >/dev/null 2>&1 || exit 0

# --- 프롬프트에서 검색 태그 추출 ---
# 프로젝트명 + 프롬프트의 의미있는 토큰(영문/한글 키워드) 일부.
PROJECT="$(basename "$(pwd)" 2>/dev/null || echo "")"

# 키워드 후보: 한글/영문 단어 중 길이 2+ 인 것 상위 몇 개 (잡토큰 최소화)
KEYWORDS="$(printf '%s' "$PROMPT" \
    | tr '[:upper:]' '[:lower:]' \
    | tr -cs '[:alnum:]가-힣' '\n' \
    | awk 'length($0) >= 2' \
    | head -6 \
    | paste -sd ',' - 2>/dev/null || echo "")"

SEARCH="project"
[[ -n "$PROJECT" ]] && SEARCH="$SEARCH,$PROJECT"
[[ -n "$KEYWORDS" ]] && SEARCH="$SEARCH,$KEYWORDS"

# --- 회상 (조용히, 실패 무시) ---
# min_overlap=2: 의미 태그가 2개 이상 겹칠 때만 회상(프로젝트명 단독 노이즈 컷)
RECALL="$(brain_query_by_tags "$SEARCH" 5 2 2>/dev/null || echo "")"

# 회상 결과가 없으면 아무것도 주입하지 않음 (노이즈 0)
[[ -z "$RECALL" ]] && exit 0

# --- additionalContext 로 조용히 주입 ---
CONTEXT="🧠 Brain 회상 (관련 과거 기억):
$RECALL"

jq -nc --arg ctx "$CONTEXT" \
    '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}' \
    2>/dev/null || true

exit 0
