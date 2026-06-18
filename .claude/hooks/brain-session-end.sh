#!/bin/bash
#
# brain-session-end.sh - 세션 종료 시 뇌 시스템 정리 + 하네스 정리
#
# SessionEnd 훅으로 실행됨
#

set -euo pipefail

# 뇌 코어 로드
# BRAIN_ROOT: 글로벌 '코드' 위치 (변경 금지). CLAUDE_BRAIN_HOME: 프로젝트 '데이터' 위치.
BRAIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../brain" 2>/dev/null && pwd)" || exit 0
[[ -f "$BRAIN_ROOT/brain-core.sh" ]] || exit 0

# 데이터 격리: 프로젝트 루트 판정 → CLAUDE_BRAIN_HOME export (core source 전에 필수).
# 프로젝트 아님이면 세션 종료 처리 스킵(폴더 미생성). 비차단.
[[ -f "$BRAIN_ROOT/brain-resolve.sh" ]] || exit 0
source "$BRAIN_ROOT/brain-resolve.sh" >/dev/null 2>&1 || exit 0
brain_resolve_project_home || exit 0

source "$BRAIN_ROOT/brain-core.sh"

# 하네스 트래커 로드
source "$BRAIN_ROOT/harness-tracker.sh"

SESSION_ID="${BRAIN_SESSION_ID:-session-$$}"

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
        brain_cleanup_forgotten
        echo "$NOW" > "$LAST_CLEANUP"
    fi
else
    echo "$NOW" > "$LAST_CLEANUP"
fi

# 하네스 주기 정리
if [[ -f "$HARNESS_DIR/.last_harness_cleanup" ]]; then
    LAST_HARNESS=$(cat "$HARNESS_DIR/.last_harness_cleanup")
    DIFF_HARNESS=$((NOW - LAST_HARNESS))

    # 7일 = 604800초
    if [[ $DIFF_HARNESS -gt 604800 ]]; then
        log_info "하네스 주기 정리 실행..."

        # 오래된 루프 기록 정리 (30일 이상)
        # 개선 로그 정리 (90일 이상)
        echo "$NOW" > "$HARNESS_DIR/.last_harness_cleanup"
    fi
else
    echo "$NOW" > "$HARNESS_DIR/.last_harness_cleanup" 2>/dev/null || true
fi

log_info "뇌 시스템 정리 완료"
