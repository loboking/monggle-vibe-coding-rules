#!/bin/bash
#
# wrapper.sh - Monggle 스킬 오타 자동 교정 래퍼
#
# Levenshtein 거리 기반 퍼지 매칭으로 오타 자동 교정
# 1-2글자 오차 허용, 자동 실행 후 알림
#
# Usage:
#   source ~/.claude/commands/wrapper.sh
#   # 이후 모든 명령어가 자동 교정됨
#

# 이 파일은 source로 로드되는 것이 기본 사용법이므로,
# source 된 경우에는 set -e/pipefail/exec 가 사용자 셸을 망가뜨린다.
# 직접 실행(standalone)일 때만 strict mode 와 exec 를 사용한다.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    _WRAPPER_SOURCED=0
    set -eo pipefail
else
    _WRAPPER_SOURCED=1
fi

# 스킬 실행 헬퍼: standalone 이면 exec, sourced 면 일반 호출
run_script() {
    if [[ "$_WRAPPER_SOURCED" -eq 0 ]]; then
        exec "$@"
    else
        "$@"
        return $?
    fi
}

# 스킬 목록 (skill|script_name)
SKILL_LIST="
debug|debug
debug-perf|bottleneck
debug-web|front-bugfix
debug-css|css-bugfix
debug-m|mem-check
qa|qa
qa-only|qa-only
review|review
review-code|code-reviewer
review-arch|arch-review
prd|prd
gate|gate
pipeline|pipeline
trace|trace
stats|stats
audit|audit
complexity|complexity
impact|impact
bottleneck|bottleneck
api-docs|api-docs
changelog|changelog
readme-sync|readme-sync
bump|bump
push-safe|push-safe
quick|quick
format-check|format-check
lint-smart|lint-smart
bench|bench
profile|profile
save-point|save-point
brainstorm|brainstorm
init|init
mode|mode
monggle-upgrade|monggle-upgrade
duo|duo
run|run
super|super
gemini|gemini
product-manager|product-manager
tech-doc-writer|tech-doc-writer
help|help
"

# 오타 교정 맵 (typo|correct)
TYPO_MAP="
qaa|qa
qaaa|qa
testt|qa
test|qa
debugg|debug
debuger|debug
debuggr|debug
log|changelog
logs|changelog
ver|bump
version|bump
versions|bump
gitpush|push-safe
push|push-safe
lint|lint-smart
idea|brainstorm
ideas|brainstorm
save|save-point
checkpoint|save-point
hotfix|quick
fix|quick
hlp|help
hel|help
"

# 스크립트 경로 가져오기
get_script_path() {
    local skill="$1"
    # monggle- 접두사 제거
    skill="${skill#monggle-}"

    # 스킬 목록에서 찾기
    while IFS='|' read -r s script; do
        [[ -z "$s" ]] && continue
        if [[ "$s" == "$skill" ]]; then
            # 먼저 monggle- 접두사 확인
            if [[ -f "$HOME/.claude/commands/monggle-$script.sh" ]]; then
                echo "$HOME/.claude/commands/monggle-$script.sh"
                return 0
            fi
            # 없으면 직접 이름 확인
            if [[ -f "$HOME/.claude/commands/$script.sh" ]]; then
                echo "$HOME/.claude/commands/$script.sh"
                return 0
            fi
        fi
    done <<< "$SKILL_LIST"

    return 1
}

# 오타 교정
correct_typo() {
    local input="$1"

    while IFS='|' read -r typo correct; do
        [[ -z "$typo" ]] && continue
        if [[ "$input" == "$typo" ]]; then
            echo "$correct"
            return 0
        fi
    done <<< "$TYPO_MAP"

    echo "$input"
}

# Levenshtein 거리 계산
levenshtein() {
    local s1="$1"
    local s2="$2"

    if [[ ${#s1} -lt ${#s2} ]]; then
        local tmp="$s1"
        s1="$s2"
        s2="$tmp"
    fi

    local len1=${#s1}
    local len2=${#s2}

    if [[ $len2 -eq 0 ]]; then
        echo $len1
        return
    fi

    # 최적화: bash 배열 없이 계산
    local prev
    local curr
    prev=()
    curr=()

    for ((i=0; i<=len2; i++)); do
        prev[$i]=$i
    done

    for ((i=1; i<=len1; i++)); do
        curr[0]=$i
        for ((j=1; j<=len2; j++)); do
            local cost=1
            if [[ "${s1:$((i-1)):1}" == "${s2:$((j-1)):1}" ]]; then
                cost=0
            fi

            local delete=$((curr[$((j-1))] + 1))
            local insert=$((prev[$j] + 1))
            local substitute=$((prev[$((j-1))] + cost))

            local min=$delete
            [[ $insert -lt $min ]] && min=$insert
            [[ $substitute -lt $min ]] && min=$substitute

            curr[$j]=$min
        done

        for ((j=0; j<=len2; j++)); do
            prev[$j]=${curr[$j]:-0}
        done
    done

    echo ${prev[$len2]:-0}
}

# 가장 비슷한 스킬 찾기
find_closest_skill() {
    local input="$1"
    local min_distance=999
    local closest=""
    local threshold=3

    # 스킬 목록 탐색
    while IFS='|' read -r skill script; do
        [[ -z "$skill" ]] && continue

        local distance
        distance=$(levenshtein "$input" "$skill")

        if [[ $distance -lt $min_distance ]]; then
            min_distance=$distance
            closest="$skill"
        fi

        # monggle- 접두사도 확인
        distance=$(levenshtein "$input" "monggle-$skill")
        if [[ $distance -lt $min_distance ]]; then
            min_distance=$distance
            closest="$skill"
        fi
    done <<< "$SKILL_LIST"

    if [[ $min_distance -le $threshold ]]; then
        echo "$closest"
    fi
}

# 명령어 래핑
wrap_command() {
    local input="$1"
    shift
    local args=("$@")

    # monggle- 접두사 제거
    local clean_input="${input#monggle-}"

    # 오타 교정 맵 확인
    local corrected
    corrected=$(correct_typo "$clean_input")
    if [[ "$corrected" != "$clean_input" ]]; then
        echo -e "\033[1;33m[오타 교정]\033[0m '$clean_input' → '$corrected'"
        clean_input="$corrected"
    fi

    # 스크립트 경로 확인
    local script_path
    script_path=$(get_script_path "$clean_input")

    if [[ -n "$script_path" ]] && [[ -f "$script_path" ]]; then
        run_script "$script_path" "${args[@]}"
        return $?
    fi

    # 퍼지 매칭
    local closest
    closest=$(find_closest_skill "$clean_input")

    if [[ -n "$closest" ]]; then
        echo -e "\033[1;33m[오타 교정]\033[0m '$clean_input' → '$closest'"
        script_path=$(get_script_path "$closest")
        if [[ -f "$script_path" ]]; then
            run_script "$script_path" "${args[@]}"
            return $?
        fi
    fi

    # 못 찾음
    echo -e "\033[1;31m[오류]\033[0m '$input' 스킬을 찾을 수 없습니다"
    echo ""
    echo "비슷한 스킬:"
    while IFS='|' read -r skill script; do
        [[ -z "$skill" ]] && continue
        local distance
        distance=$(levenshtein "$clean_input" "$skill")
        if [[ $distance -le 2 ]]; then
            echo "  - /$skill"
        fi
    done <<< "$SKILL_LIST"
    echo ""
    echo "전체 목록: /help"
    return 1
}

# 메인
main() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: $0 <command> [args...]"
        echo "  이 스크립트는 source로 로드해야 합니다"
        return 1
    fi

    wrap_command "$@"
}

# 직접 실행 시
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
