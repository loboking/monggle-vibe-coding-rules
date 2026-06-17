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
if [[ -f "$HOME/.claude/lib/common.sh" ]]; then
    source "$HOME/.claude/lib/common.sh" 2>/dev/null || true
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

# ============================================================================
# Brain 자동 부트스트랩 (스킬 첫 실행 시 brain 상시 기억 훅 자동 등록)
# ============================================================================
# Vibe Coding 스킬을 쓰는 프로젝트면, 별도 install 없이도 스킬 실행 순간
# 그 프로젝트의 .claude/settings.json 에 brain 훅(회상/저장/세션)을 조용히
# 자동 등록한다. 이후 모든 메시지에서 Brain 이 상시 작동.
# 안전: 어떤 실패도 스킬 작동을 막지 않는다. 멱등(중복 등록 안 함).
_brain_bootstrap() {
    # 비활성화 스위치
    [[ "${BRAIN_AUTOREGISTER:-true}" == "false" ]] && return 0
    command -v jq &>/dev/null || return 0

    # --- 프로젝트 루트 판정: git 루트 우선, 없으면 cwd ---
    local proj
    proj="$(git rev-parse --show-toplevel 2>/dev/null)" || proj=""
    [[ -z "$proj" ]] && proj="$(pwd)"
    [[ -d "$proj" ]] || return 0

    # 프로젝트에 brain 훅 파일이 실제로 있어야 등록(없으면 이 프로젝트는 brain 미설치)
    local hooks_dir="$proj/.claude/hooks"
    [[ -f "$hooks_dir/brain-prompt-recall.sh" ]] || return 0

    local sf="$proj/.claude/settings.json"
    # settings.json 없으면 최소 골격 생성
    if [[ ! -f "$sf" ]]; then
        mkdir -p "$proj/.claude" 2>/dev/null || return 0
        echo '{}' > "$sf" 2>/dev/null || return 0
    fi

    # 이미 회상 훅 등록됐으면 종료 (멱등)
    jq -e '.hooks.UserPromptSubmit[]?.hooks[]?.command | select(test("brain-prompt-recall"))' "$sf" &>/dev/null && return 0

    # 조용히 4개 brain 훅 주입 (각 이벤트에 이미 있으면 건너뜀)
    local tmp; tmp="$(mktemp 2>/dev/null)" || return 0
    if jq '
        .hooks = (.hooks // {})
        | (((.hooks.SessionStart // []) | map(.hooks[]?.command) | any(test("brain-session-start"))) as $h
           | if $h then . else .hooks.SessionStart = ((.hooks.SessionStart // []) + [{"matcher":"*","hooks":[{"type":"command","command":"$CLAUDE_PROJECT_DIR/.claude/hooks/brain-session-start.sh","timeout":10}]}]) end)
        | (((.hooks.UserPromptSubmit // []) | map(.hooks[]?.command) | any(test("brain-prompt-recall"))) as $h
           | if $h then . else .hooks.UserPromptSubmit = ((.hooks.UserPromptSubmit // []) + [{"matcher":"*","hooks":[{"type":"command","command":"$CLAUDE_PROJECT_DIR/.claude/hooks/brain-prompt-recall.sh","timeout":15}]}]) end)
        | (((.hooks.Stop // []) | map(.hooks[]?.command) | any(test("brain-turn-save"))) as $h
           | if $h then . else .hooks.Stop = ((.hooks.Stop // []) + [{"matcher":"*","hooks":[{"type":"command","command":"$CLAUDE_PROJECT_DIR/.claude/hooks/brain-turn-save.sh","timeout":15}]}]) end)
        | (((.hooks.SessionEnd // []) | map(.hooks[]?.command) | any(test("brain-session-end"))) as $h
           | if $h then . else .hooks.SessionEnd = ((.hooks.SessionEnd // []) + [{"matcher":"*","hooks":[{"type":"command","command":"$CLAUDE_PROJECT_DIR/.claude/hooks/brain-session-end.sh","timeout":30}]}]) end)
    ' "$sf" > "$tmp" 2>/dev/null; then
        mv "$tmp" "$sf" 2>/dev/null || rm -f "$tmp"
    else
        rm -f "$tmp"
    fi
    return 0
}
_brain_bootstrap 2>/dev/null || true

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
