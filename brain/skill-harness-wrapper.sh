#!/bin/bash
#
# skill-harness-wrapper.sh - 스킬 하네스 래퍼
#
# 각 스크립트 시작 부분에 추가하면 하네스 자동 추적
#
# Usage:
#   # 스크립트 시작 부분에 추가:
#   source "${0%/*}/../brain/skill-harness-wrapper.sh" || true
#   harness_skill_start "$@"
#
#   # 스크립트 종료 전 (trap 사용):
#   trap 'harness_skill_end $?' EXIT
#

set -euo pipefail

# 하네스 트래커 로드
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$HARNESS_ROOT/brain/harness-tracker.sh" 2>/dev/null || true

# 업그레이드 체크 로드 (전역/프로젝트 라이브러리)
if [[ -f "$HOME/lib/common.sh" ]]; then
    source "$HOME/lib/common.sh" 2>/dev/null || true
elif [[ -f "${HARNESS_ROOT}/lib/common.sh" ]]; then
    source "${HARNESS_ROOT}/lib/common.sh" 2>/dev/null || true
fi

# 자동 업그레이드 체크 (스킬 최초 실행 시)
# UPGRADE_CHECK=false 환경변수로 비활성화 가능
if [[ "${UPGRADE_CHECK:-true}" != "false" ]] && type auto_check_upgrade &>/dev/null; then
    auto_check_upgrade 2>/dev/null || true
fi

# 프로젝트 루트 설정
if [[ -f "${HARNESS_ROOT}/../../package.json" ]]; then
    PROJECT_ROOT="$(cd "${HARNESS_ROOT}/../.." && pwd)"
elif [[ -f "${HARNESS_ROOT}/../../go.mod" ]]; then
    PROJECT_ROOT="$(cd "${HARNESS_ROOT}/../.." && pwd)"
elif [[ -f "${HARNESS_ROOT}/../../build.gradle" ]] || \
     [[ -f "${HARNESS_ROOT}/../../build.gradle.kts" ]] || \
     [[ -f "${HARNESS_ROOT}/../../settings.gradle" ]]; then
    # Android/Gradle 프로젝트
    PROJECT_ROOT="$(cd "${HARNESS_ROOT}/../.." && pwd)"
elif [[ -f "${HARNESS_ROOT}/../../CLAUDE.md" ]]; then
    # CLAUDE.md가 있으면 프로젝트 루트로 간주
    PROJECT_ROOT="$(cd "${HARNESS_ROOT}/../.." && pwd)"
else
    PROJECT_ROOT="${HARNESS_ROOT}"
fi

export PROJECT_ROOT

# brain 훅은 install.sh 가 도구별 전역 설정에 한 번 등록한다(프로젝트마다 등록하면 중복 실행).

# 스킬 이름 자동 감지
HARNESS_SKILL_NAME="$(basename "$0" .sh)"

# ============================================================================
# Public Functions
# ============================================================================

# 스킬 시작 (각 스크립트의 main() 시작 부분에서 호출)
harness_skill_start() {
    # 하네스 초기화
    harness_init 2>/dev/null || true

    # 최소 수정 원칙 검증 (스킬 실행 전)
    harness_verify_minimal_change "$HARNESS_SKILL_NAME" 2>/dev/null || true

    # 루프 탐지 체크 (수정할 파일 목록이 있으면)
    local files_to_check
    files_to_check=()
    if [[ $# -gt 0 ]]; then
        # 인자에서 파일 경로 추출
        for arg in "$@"; do
            if [[ -f "$arg" ]]; then
                files_to_check+=("$arg")
            fi
        done
    fi

    if [[ ${#files_to_check[@]} -gt 0 ]]; then
        harness_check_loops "$HARNESS_SKILL_NAME" "${files_to_check[@]}" 2>/dev/null || true
    fi

    # 추적 시작
    harness_track_start "$HARNESS_SKILL_NAME" "$*" 2>/dev/null || true
}

# 스킬 종료 (trap에서 호출)
harness_skill_end() {
    local exit_code="${1:-0}"

    # 추적 종료
    harness_track_end "$HARNESS_SKILL_NAME" "$exit_code" 2>/dev/null || true

    # 수정된 파일 기록
    # git diff로 수정된 파일 목록 가져오기
    if command -v git &>/dev/null && git rev-parse --git-dir &>/dev/null; then
        local modified_files
        modified_files=()
        while IFS= read -r file; do
            modified_files+=("$file")
        done < <(git diff --name-only HEAD 2>/dev/null || true)

        if [[ ${#modified_files[@]} -gt 0 ]]; then
            harness_record_modification "$HARNESS_SKILL_NAME" "${modified_files[@]}" 2>/dev/null || true
        fi

        # 과도한 수정 경고 (최소 수정 원칙)
        harness_warn_excessive_changes "$HARNESS_SKILL_NAME" 2>/dev/null || true
    fi
}

# ============================================================================
# Export
# ============================================================================

export -f harness_skill_start
export -f harness_skill_end
export HARNESS_SKILL_NAME
export HARNESS_ROOT
