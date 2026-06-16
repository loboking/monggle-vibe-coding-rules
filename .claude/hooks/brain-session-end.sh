#!/bin/bash
#
# brain-session-end.sh - 세션 종료 시 뇌 시스템 정리 + 하네스 정리
#
# SessionEnd 훅으로 실행됨
#

set -euo pipefail

# 뇌 코어 로드
BRAIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../brain" && pwd)"
source "$BRAIN_ROOT/brain-core.sh"

# 하네스 트래커 로드
source "$BRAIN_ROOT/harness-tracker.sh"

SESSION_ID="${BRAIN_SESSION_ID:-session-$$}"

# 세션 종료
brain_session_end "$SESSION_ID"

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
