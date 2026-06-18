#!/bin/bash
#
# brain-resolve.sh - 프로젝트 루트 판정 & 데이터 홈 해석 (순수 bash, 의존성 없음)
#
# '코드는 글로벌, 데이터는 프로젝트별 격리' 설계의 핵심.
# 4개 brain 훅(prompt-recall / turn-save / session-start / session-end)이
# brain-core.sh 를 source 하기 '전에' 이 파일을 source 하여
#   brain_resolve_project_home
# 를 호출, 프로젝트 루트를 판정하고 CLAUDE_BRAIN_HOME 을 export 한다.
# 그러면 brain-core.sh 의 BRAIN_HOME 이 프로젝트별 .claude/brain 으로 잡힌다.
#
# 주의:
#   - 이 파일은 brain-core 보다 먼저 source 되므로 brain-core 의 함수에 의존하지 않는다.
#   - 글로벌 코드 위치(BRAIN_ROOT=dirname/../brain)는 절대 건드리지 않는다.
#     이 파일이 export 하는 것은 '데이터' 홈(CLAUDE_BRAIN_HOME)뿐이다.
#   - macOS/BSD bash 3.2 호환 (배열/연관배열/유사 미사용).

# 프로젝트 루트를 판정한다.
#   우선순위:
#     1) git rev-parse --show-toplevel (git 작업트리 루트)
#     2) cwd 부터 상위로 올라가며 .claude 디렉토리가 있는 첫 조상
#     3) 둘 다 없으면 빈 문자열 출력 (= 프로젝트 아님)
# 성공: 절대경로 stdout + 0 / 프로젝트 아님: 빈 출력 + 1
brain_find_project_root() {
    local root=""

    # 1) git 루트
    if command -v git >/dev/null 2>&1; then
        root="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
        if [[ -n "$root" && -d "$root" ]]; then
            printf '%s' "$root"
            return 0
        fi
    fi

    # 2) cwd 부터 상위로 .claude 탐색
    local dir
    dir="$(pwd 2>/dev/null || echo "")"
    [[ -z "$dir" ]] && return 1
    while [[ -n "$dir" && "$dir" != "/" ]]; do
        if [[ -d "$dir/.claude" ]]; then
            printf '%s' "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    # 루트('/')에 .claude 가 있는 극단 케이스도 확인
    if [[ -d "/.claude" ]]; then
        printf '%s' "/"
        return 0
    fi

    # 3) 프로젝트 아님
    return 1
}

# 프로젝트 데이터 홈을 해석하여 CLAUDE_BRAIN_HOME 으로 export.
#   - 프로젝트 루트 확정 시: CLAUDE_BRAIN_HOME="<root>/.claude/brain" export 후 0 반환.
#   - 프로젝트 아님: 아무것도 export 하지 않고 1 반환
#     (호출 훅은 1 을 받으면 조용히 exit 0 → 저장/회상 스킵, brain 폴더 미생성).
# 사용:
#   source "<brain-resolve.sh>"
#   brain_resolve_project_home || exit 0
#   source "<brain-core.sh>"
brain_resolve_project_home() {
    local root
    root="$(brain_find_project_root)" || return 1
    [[ -z "$root" ]] && return 1
    export CLAUDE_BRAIN_HOME="$root/.claude/brain"
    return 0
}
