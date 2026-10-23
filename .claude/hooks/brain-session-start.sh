#!/bin/bash
#
# brain-session-start.sh - 세션 시작 시 뇌 시스템 초기화 + 하네스
#
# SessionStart 훅으로 실행됨
#

set -euo pipefail

# 기억은 개인 데이터 — 새로 만드는 파일은 본인만 읽게 한다.
umask 077
# 훅마다 별도 프로세스라 환경변수로는 세션 ID 가 이어지지 않는다 → 도구가 넘겨주는 session_id 를 쓴다.
INPUT="$(cat 2>/dev/null || echo '{}')"
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

# 컨텍스트 로드 (프로젝트 관련 뉴런)
log_info "프로젝트 컨텍스트 로드 중..."

PROJECT_CONTEXT=$(brain_query_by_tags "project,$(basename "$(pwd)")" 5 2>/dev/null || echo "")

if [[ -n "$PROJECT_CONTEXT" ]]; then
    log_info "관련 기억 발견:"
    echo "$PROJECT_CONTEXT" | head -5
fi

# 핫 캐시 갱신 (access_count 상위 N 반영) → 조용히, 실패무시
brain_update_hotcache 7 >/dev/null 2>&1 || true

# 핫 캐시 표시
if [[ -s "$CORTEX_FILE" ]]; then
    echo ""
    echo "🧠 최근 활성 기억:"
    head -20 "$CORTEX_FILE"
fi

echo ""
echo "세션 ID: $SESSION_ID"
