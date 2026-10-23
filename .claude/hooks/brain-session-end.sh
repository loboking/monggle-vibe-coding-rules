#!/bin/bash
#
# brain-session-end.sh - 세션 종료 시 뇌 시스템 정리 + 하네스 정리
#
# SessionEnd 훅으로 실행됨
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
# 프로젝트 아님이면 세션 종료 처리 스킵(폴더 미생성). 비차단.
[[ -f "$BRAIN_ROOT/brain-resolve.sh" ]] || exit 0
source "$BRAIN_ROOT/brain-resolve.sh" >/dev/null 2>&1 || exit 0
brain_resolve_project_home || exit 0

source "$BRAIN_ROOT/brain-core.sh"
brain_lock || exit 0

# 하네스 트래커 로드
source "$BRAIN_ROOT/harness-tracker.sh"

SESSION_ID="${SID:+session-$SID}"
SESSION_ID="${SESSION_ID:-${BRAIN_SESSION_ID:-session-$$}}"

# 세션 종료
brain_session_end "$SESSION_ID"

# 핫 캐시 갱신 (신규/접근 반영) → 조용히, 실패무시
brain_update_hotcache 7 >/dev/null 2>&1 || true

# 주기 청소 (마지막 접근으로부터 24시간 이상 된 것)
LAST_CLEANUP="$BRAIN_HOME/.last_cleanup"
NOW=$(date +%s)

if [[ -f "$LAST_CLEANUP" ]]; then
    LAST=$(cat "$LAST_CLEANUP")
    DIFF=$((NOW - LAST))

    # 24시간 = 86400초
    if [[ $DIFF -gt 86400 ]]; then
        log_info "주기 청소 실행..."
        # 청소 전에 시각을 남긴다 — 청소가 30초 제한에 걸려 끊겨도 다음 세션마다 재시도하지 않게.
        echo "$NOW" > "$LAST_CLEANUP"
        brain_cleanup_forgotten
        # 세션 기록은 고착화가 끝나면 쓸모가 없다. 30일 지난 것은 지운다(무한 증가 방지).
        find "$HIPPOCAMPUS_DIR/sessions" -name 'session-*.md' -mtime +30 -delete 2>/dev/null || true
    fi
else
    echo "$NOW" > "$LAST_CLEANUP"
fi

log_info "뇌 시스템 정리 완료"
