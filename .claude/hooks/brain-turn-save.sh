#!/bin/bash
#
# brain-turn-save.sh - 응답 끝 훅 (Claude·Codex: Stop, Gemini: AfterAgent)
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

# 기억은 개인 데이터 — 새로 만드는 파일은 본인만 읽게 한다.
umask 077

INPUT="$(cat 2>/dev/null || echo '{}')"
# 도구가 훅을 프로젝트가 아닌 곳에서 실행할 수 있다(Codex). 입력의 작업 폴더로 옮겨야 프로젝트 기억을 찾는다.
_cwd="$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)"
[[ -n "$_cwd" && -d "$_cwd" ]] && cd "$_cwd"

command -v jq &>/dev/null || exit 0

TRANSCRIPT="$(printf '%s' "$INPUT" | jq -r '.transcript_path // ""' 2>/dev/null || echo "")"
# Codex 의 Stop 입력에는 사용자 발언이 없다 → 질문 훅이 세션별 임시 파일에 남겨 두고 저장 훅이 쓴 뒤 지운다.
_sid="$(printf '%s' "$INPUT" | jq -r '.session_id // .conversation_id // empty' 2>/dev/null | tr -cd 'A-Za-z0-9_-')"
STASH="${TMPDIR:-/tmp}/brain-prompt-${_sid:-none}"

# --- 마지막 사용자 발언·AI 응답 추출 (transcript 는 JSONL) ---
# 도구를 쓴 턴은 마지막 user 항목이 tool_result 라서, '마지막을 집고 나서 거르면' 빈 값이 된다
# (코딩 턴 대부분이 저장되지 않던 원인). 텍스트가 있는 사람 발언만 먼저 거른 뒤 마지막을 고른다.
# isMeta(스킬 본문 등 도구가 넣은 메시지)는 사람 발언이 아니다.
# 큰 transcript 를 통째로 읽지 않도록 끝부분만 본다.
_texts() {
    tail -n 400 "$TRANSCRIPT" 2>/dev/null | jq -rs --arg role "$1" '
        map(select((.type? == $role or .role? == $role or .message.role? == $role) and (.isMeta? != true))
            | (.message.content // .content // "")
            | if type == "array" then (map(select(.type? == "text") | .text) | join(" ")) else tostring end
            # 도구가 사람 발언 앞에 붙이는 안내 블록은 잘라 낸다(통째로 버리면 실제 발언까지 저장되지 않는다).
            | gsub("(?s)<system-reminder>.*?</system-reminder>"; "") | gsub("^\\s+|\\s+$"; "")
            | select(. != "" and . != "null"))
        | last // ""' 2>/dev/null
}
# 도구마다 넘겨주는 값이 다르다: Gemini(AfterAgent)는 prompt, Claude 는 기록 파일(JSONL), Codex 는 임시 파일.
LAST_USER="$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)"
[[ -z "$LAST_USER" && -f "$TRANSCRIPT" ]] && LAST_USER="$(_texts user)"
[[ -z "$LAST_USER" && -f "$STASH" ]] && LAST_USER="$(cat "$STASH" 2>/dev/null)"
rm -f "$STASH" 2>/dev/null
[[ -z "$LAST_USER" ]] && exit 0
# 사용자가 붙여 넣은 키·비밀번호가 본문·태그로 저장되지 않게 먼저 가린다.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/brain-core.sh" >/dev/null 2>&1 \
    || source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../brain/brain-core.sh" >/dev/null 2>&1 || exit 0
LAST_USER="$(brain_redact "$LAST_USER")"

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

# 키워드 신호가 없으면 저장 안 함. 작업트리 변경(ACTION)은 태그로만 쓴다 —
# 변경이 남아 있는 동안 모든 메시지(잡담 포함)가 저장되던 문제 때문.
[[ $IMPORTANT -eq 0 ]] && exit 0

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
# 설치본은 훅과 코어가 같은 폴더(~/.agents/skills/brain/scripts), 저장소에서는 루트 brain/ 에 있다.
_hook_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for BRAIN_ROOT in "$_hook_dir" "$_hook_dir/../../brain"; do [[ -f "$BRAIN_ROOT/brain-core.sh" ]] && break; done
[[ -f "$BRAIN_ROOT/brain-core.sh" ]] || exit 0
# 다른 훅과 같은 프로젝트 데이터 위치에 저장한다(없으면 ~/brain 으로 새어 나감).
source "$BRAIN_ROOT/brain-resolve.sh" >/dev/null 2>&1 || exit 0
brain_resolve_project_home || exit 0
source "$BRAIN_ROOT/brain-core.sh" >/dev/null 2>&1 || exit 0
brain_lock || exit 0

PROJECT="$(basename "$(pwd)" 2>/dev/null || echo "")"

# 제목: 메시지 앞부분 요약(80B), 내용: 메시지 전문(BRAIN_BODY_MAXCHARS B, 기본 2500).
# head -c 는 바이트 단위라 한글(UTF-8 3바이트) 중간에서 잘리면 깨진 바이트가
# 남는다 → iconv -c 로 불완전 멀티바이트 시퀀스를 제거(없으면 원본 유지).
# 본문 한도는 키워드 추출 원천 보존을 위해 brain-core 와 동일 변수로 통일.
BRAIN_BODY_MAXCHARS="${BRAIN_BODY_MAXCHARS:-2500}"
# macOS iconv 는 -c 를 줘도 잘린 글자에서 실패 코드를 내서, '|| 원본' 을 붙이면 출력이 두 번 붙었다.
TITLE="$(printf '%s' "$LAST_USER" | tr '\n' ' ' | head -c 80 | iconv -c -f UTF-8 -t UTF-8 2>/dev/null; true)"
CONTENT="$(printf '%s' "$LAST_USER" | head -c "$BRAIN_BODY_MAXCHARS" | iconv -c -f UTF-8 -t UTF-8 2>/dev/null; true)"
# 결정·결과도 남긴다: 이번 턴 AI 응답 앞부분을 '결과'로 붙인다.
LAST_AI="$(printf '%s' "$INPUT" | jq -r '.prompt_response // .last_assistant_message // empty' 2>/dev/null)"
[[ -z "$LAST_AI" && -f "$TRANSCRIPT" ]] && LAST_AI="$(_texts assistant)"
LAST_AI="$(brain_redact "$LAST_AI" | head -c 600 | iconv -c -f UTF-8 -t UTF-8 2>/dev/null; true)"
[[ -n "$LAST_AI" ]] && CONTENT="$CONTENT

## 결과
$LAST_AI"

# 태그: project + 프로젝트명 + 신호 종류 + 의미 키워드 일부
# 프로젝트명 태그는 넣지 않는다 — 기억이 이미 프로젝트별로 나뉘어 있어, 모든 뉴런에 같은 태그가 붙으면
# 키워드 하나만 겹쳐도 회상·연결 기준(겹침 2개)을 넘어 노이즈가 된다.
TAGS="project"
[[ $IMPORTANT -eq 1 ]] && TAGS="$TAGS,decision"
[[ $ACTION -eq 1 ]] && TAGS="$TAGS,change"
# 4개면 빈도가 같은 단어 중 무엇이 뽑힐지 정해지지 않아 핵심어가 빠지곤 했다 → 넉넉히 8개.
KW="$(brain_extract_keywords "$LAST_USER" 8 2>/dev/null || echo "")"
[[ -n "$KW" ]] && TAGS="$TAGS,$KW"

# 메시지 단위 뉴런 저장 (조용히)
brain_create_neuron "context" "$TITLE" "$CONTENT" "$TAGS" "$EMOTION" >/dev/null 2>&1 || true

exit 0
