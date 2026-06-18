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
# BRAIN_ROOT: 글로벌 '코드' 위치 (변경 금지). CLAUDE_BRAIN_HOME: 프로젝트 '데이터' 위치.
BRAIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../brain" 2>/dev/null && pwd)" || exit 0
[[ -f "$BRAIN_ROOT/brain-core.sh" ]] || exit 0

# 데이터 격리: 프로젝트 루트 판정 → CLAUDE_BRAIN_HOME export (core source 전에 필수).
# 프로젝트 아님이면 회상할 프로젝트 brain 이 없으므로 조용히 종료(폴더 미생성).
[[ -f "$BRAIN_ROOT/brain-resolve.sh" ]] || exit 0
source "$BRAIN_ROOT/brain-resolve.sh" >/dev/null 2>&1 || exit 0
brain_resolve_project_home || exit 0

# log_* 가 stdout 을 오염시키지 않도록 회상 출력만 캡처
source "$BRAIN_ROOT/brain-core.sh" >/dev/null 2>&1 || exit 0

# --- 프롬프트에서 검색 태그 추출 ---
# 프로젝트명 + 프롬프트의 의미있는 토큰(영문/한글 키워드) 일부.
PROJECT="$(basename "$(pwd)" 2>/dev/null || echo "")"

# 키워드: 공통 추출기로 불용어/시스템토큰 제거 후 의미 토큰만
KEYWORDS="$(brain_extract_keywords "$PROMPT" 6 2>/dev/null || echo "")"

SEARCH="project"
[[ -n "$PROJECT" ]] && SEARCH="$SEARCH,$PROJECT"
[[ -n "$KEYWORDS" ]] && SEARCH="$SEARCH,$KEYWORDS"

# --- 회상 (조용히, 실패 무시) ---
# min_overlap=2: 의미 태그가 2개 이상 겹칠 때만 회상(프로젝트명 단독 노이즈 컷)
# brain_query_with_links: 직접 태그 매칭 + 연결된(시냅스) 기억까지 확장 회상.
# (v2 미배선 해소 — 함수가 없으면 기존 query 로 폴백)
if type brain_query_with_links &>/dev/null; then
    RECALL="$(brain_query_with_links "$SEARCH" 5 2 2>/dev/null || echo "")"
else
    RECALL="$(brain_query_by_tags "$SEARCH" 5 2 2>/dev/null || echo "")"
fi

# 회상 결과가 없으면 아무것도 주입하지 않음 (노이즈 0)
[[ -z "$RECALL" ]] && exit 0

# --- [ⓑ] 상위 1~2건 본문 발췌 추가 ---
# RECALL 라인 형식: "- <id> (<type>): ..." 에서 id 만 뽑아 상위 2개의 '## 내용'
# 본문 첫 200자를 읽기 전용(access_count 미증가)으로 발췌해 함께 주입.
EXCERPTS=""
if type brain_recall_excerpt &>/dev/null; then
    TOP_IDS="$(printf '%s\n' "$RECALL" | sed -n 's/^- \([^ ]*\) .*/\1/p' | head -2)"
    while IFS= read -r _id; do
        [[ -z "$_id" ]] && continue
        _ex="$(brain_recall_excerpt "$_id" 200 2>/dev/null || echo "")"
        [[ -z "$_ex" ]] && continue
        EXCERPTS="${EXCERPTS}
  • ${_id}: ${_ex}"
    done <<< "$TOP_IDS"
fi

# --- additionalContext 로 조용히 주입 ---
CONTEXT="🧠 Brain 회상 (관련 과거 기억):
$RECALL"
[[ -n "$EXCERPTS" ]] && CONTEXT="$CONTEXT

📄 본문 발췌:$EXCERPTS"

jq -nc --arg ctx "$CONTEXT" \
    '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}' \
    2>/dev/null || true

exit 0
