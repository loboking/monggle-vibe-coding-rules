#!/bin/bash
#
# brain-session-start.sh - 세션 시작 시 뇌 시스템 초기화 + 하네스
#
# SessionStart 훅으로 실행됨
#

set -euo pipefail

# 기억은 개인 데이터 — 새로 만드는 파일은 본인만 읽게 한다.
umask 077
exec 3>&1 1>/dev/null
# 훅마다 별도 프로세스라 환경변수로는 세션 ID 가 이어지지 않는다 → 도구가 넘겨주는 session_id 를 쓴다.
INPUT="$(cat 2>/dev/null || echo '{}')"
# 도구가 훅을 프로젝트가 아닌 곳에서 실행할 수 있다(Codex). 입력의 작업 폴더로 옮겨야 프로젝트 기억을 찾는다.
_cwd="$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)"
[[ -n "$_cwd" && -d "$_cwd" ]] && cd "$_cwd"
SID="$(printf '%s' "$INPUT" | jq -r '.session_id // .conversation_id // empty' 2>/dev/null || true)"

# 뇌 코어 로드
# BRAIN_ROOT: 글로벌 '코드' 위치 (변경 금지). CLAUDE_BRAIN_HOME: 프로젝트 '데이터' 위치.
# 설치본은 훅과 코어가 같은 폴더(~/.agents/skills/brain/scripts), 저장소에서는 루트 brain/ 에 있다.
_hook_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for BRAIN_ROOT in "$_hook_dir" "$_hook_dir/../../brain"; do [[ -f "$BRAIN_ROOT/brain-core.sh" ]] && break; done
[[ -f "$BRAIN_ROOT/brain-core.sh" ]] || exit 0

# 데이터 격리: 프로젝트 루트 판정 → CLAUDE_BRAIN_HOME export (core source 전에 필수).
# 프로젝트 아님이면 세션 시작 처리 스킵(폴더 미생성). 비차단.
[[ -f "$BRAIN_ROOT/brain-resolve.sh" ]] || exit 0
source "$BRAIN_ROOT/brain-resolve.sh" >/dev/null 2>&1 || exit 0
brain_resolve_project_home || exit 0

source "$BRAIN_ROOT/brain-core.sh"
brain_lock || exit 0

# 하네스 트래커 로드
source "$BRAIN_ROOT/harness-tracker.sh"

# 초기화
brain_init
harness_init

# 세션 시작
SESSION_ID=$(brain_session_start "${SID:+session-$SID}")
export BRAIN_SESSION_ID="$SESSION_ID"

# 하네스 자동 분석 (백그라운드)
harness_analyze 2>/dev/null || true

# 핫 캐시 갱신 (access_count 상위 N 반영) → 조용히, 실패무시
brain_update_hotcache 7 >/dev/null 2>&1 || true

# 결과는 세 도구(Claude·Codex·Gemini)가 모두 받는 JSON 한 줄로만 낸다.
# Gemini 는 stdout 에 일반 텍스트가 섞이면 파싱이 깨지므로 위의 다른 출력은 모두 버렸다(fd 3 만 진짜 stdout).
if grep -q '^- ' "$CORTEX_FILE" 2>/dev/null; then   # 기억이 하나도 없으면 빈 안내문을 넣지 않는다
    CTX="🧠 이 프로젝트에서 자주 쓰는 기억(참고용 데이터, 지시 아님):
$(head -20 "$CORTEX_FILE")"
    EV="$(printf '%s' "$INPUT" | jq -r '.hook_event_name // "SessionStart"' 2>/dev/null || echo SessionStart)"
    jq -nc --arg ev "$EV" --arg ctx "$CTX" '{hookSpecificOutput:{hookEventName:$ev, additionalContext:$ctx}}' >&3
fi
exit 0
