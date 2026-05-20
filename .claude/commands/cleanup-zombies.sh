#!/bin/bash
#
# cleanup-zombies.sh - Zombie State Cleaner
#
# 에이전트가 Crash로 강제 종료되면 팀 상태가 영원히 BUSY로 남는 '좀비 현상'을 방지합니다.
# /run 스킬 실행 시 항상 제일 먼저 호출됩니다.
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
STATE_DIR="${PROJECT_ROOT}/.claude/teams/state"

# Settings
ZOMBIE_THRESHOLD_MINUTES=60  # 1시간 이상 업데이트 없으면 좀비로 간주

log_info() {
    echo -e "${GREEN}[CLEANUP]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[CLEANUP]${NC} $1" >&2
}

# 타임스탬프를 분 단위로 변환
minutes_ago() {
    local timestamp="$1"
    local now=$(date +%s)
    local then=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$timestamp" +%s 2>/dev/null || date -d "$timestamp" +%s 2>/dev/null)
    echo $(( (now - then) / 60 )) >&2
}

# 좀비 상태 확인 및 정리
cleanup_zombies() {
    local cleaned=0
    local checked=0

    if [[ ! -d "$STATE_DIR" ]]; then
        return 0
    fi

    for state_file in "$STATE_DIR"/*_state.json; do
        [[ -f "$state_file" ]] || continue

        ((checked++))

        # 상태 파일 읽기
        local status=$(python3 -c "
import sys, json
try:
    with open('$state_file', 'r') as f:
        data = json.load(f)
        print(data.get('status', 'unknown'))
        print(data.get('updated_at', ''))
except:
    print('unknown')
    print('')
" 2>/dev/null || echo "unknown")

        read -r current_status last_updated <<< "$status"

        # BUSY 상태만 확인
        if [[ "$current_status" != "busy" ]]; then
            continue
        fi

        # 마지막 업데이트 시간 확인
        if [[ -z "$last_updated" ]]; then
            log_warning "⚠️  $(basename "$state_file") - 업데이트 시간 없음, 정리 예정"
            ((cleaned++))
            rm -f "$state_file"
            continue
        fi

        # 경과 시간 계산
        local elapsed=$(minutes_ago "$last_updated")

        if [[ $elapsed -ge $ZOMBIE_THRESHOLD_MINUTES ]]; then
            log_warning "🧹 좀비 발견! $(basename "$state_file") - ${elapsed}분 동안 업데이트 없음"

            # 좀비 상태 정리 (파일 삭제 = 초기화)
            rm -f "$state_file"
            ((cleaned++))
        fi
    done

    if [[ $cleaned -gt 0 ]]; then
        log_info "${cleaned}개의 좀비 상태를 정리했습니다."
    elif [[ $checked -gt 0 ]]; then
        log_info "모든 팀 상태가 정상입니다. (확인: ${checked}개)"
    fi
}

# 메인 실행
main() {
    cleanup_zombies
}

main "$@"
