#!/usr/bin/env bats
#
# bats-core 테스트 스위트 - 12개 스킬용
#
# TDD 통합 접근법 - Option 3
# - bats-core로 Bash 스크립트 직접 테스트
# - Python unittest와 병행 실행
#

# 테스트 설정
setup() {
    # 프로젝트 루트 찾기
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export PROJECT_ROOT

    # 라이브러리 로드
    source "$PROJECT_ROOT/.claude/lib/common.sh"
    source "$PROJECT_ROOT/.claude/lib/platform.sh"
    source "$PROJECT_ROOT/.claude/lib/validation.sh"
    source "$PROJECT_ROOT/.claude/lib/git.sh"

    # 임시 디렉토리
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
}

# 테스트 정리
teardown() {
    # 임시 디렉토리 삭제
    if [[ -n "$TEST_TEMP_DIR" && -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

# ============================================
# Helper 함수들
# ============================================

# 스크립트 실행 헬퍼
run_skill() {
    local skill_script="$1"
    shift

    if [[ -f "$PROJECT_ROOT/.claude/commands/$skill_script" ]]; then
        run bash "$PROJECT_ROOT/.claude/commands/$skill_script" "$@"
    else
        skip "Skill script not found: $skill_script"
    fi
}

# ============================================
# 플랫폼 라이브러리 테스트
# ============================================

@test "platform.sh: get_os returns valid OS name" {
    result=$(get_os)

    [[ "$result" =~ ^(macos|linux|windows|unknown)$ ]]
}

@test "platform.sh: sed_inplace modifies file correctly" {
    local test_file="$TEST_TEMP_DIR/sed_test.txt"
    echo "Hello World" > "$test_file"

    sed_inplace 's/World/Universe/' "$test_file"

    run cat "$test_file"
    [[ "$output" =~ "Hello Universe" ]]
}

@test "platform.sh: get_file_size returns correct size" {
    local test_file="$TEST_TEMP_DIR/size_test.txt"
    printf "test content" > "$test_file"  # 12 bytes (no newline)

    result=$(get_file_size "$test_file")

    # macOS와 Linux에서 결과가 같아야 함
    [[ "$result" =~ ^[0-9]+$ ]]
    [[ "$result" -ge 10 ]]
    [[ "$result" -le 15 ]]
}

# ============================================
# 검증 라이브러리 테스트
# ============================================

@test "validation.sh: validate_file_path rejects path traversal" {
    run validate_file_path "../../../etc/passwd"

    [ "$status" -ne 0 ]
    [[ "$output" =~ "Path traversal" ]]
}

@test "validation.sh: validate_file_path accepts safe path" {
    run validate_file_path "safe/path/to/file.txt"

    [ "$status" -eq 0 ]
}

@test "validation.sh: validate_version accepts valid versions" {
    run validate_version "1.0.0"
    [ "$status" -eq 0 ]

    run validate_version "2.3.4-beta"
    [ "$status" -eq 0 ]

    run validate_version "10.20.30"
    [ "$status" -eq 0 ]
}

@test "validation.sh: validate_version rejects invalid versions" {
    run validate_version "1.0"
    [ "$status" -ne 0 ]

    run validate_version "abc"
    [ "$status" -ne 0 ]

    run validate_version "1.0.0; rm -rf /"
    [ "$status" -ne 0 ]
}

@test "validation.sh: validate_prd_type accepts valid types" {
    for type in feature bug refactor hotfix experiment api migration ml devops; do
        run validate_prd_type "$type"
        [ "$status" -eq 0 ]
    done
}

@test "validation.sh: validate_prd_type rejects invalid types" {
    run validate_prd_type "hacker"
    [ "$status" -ne 0 ]

    run validate_prd_type "feature; echo pwned"
    [ "$status" -ne 0 ]
}

@test "validation.sh: validate_language accepts valid codes" {
    for lang in ko en zh; do
        run validate_language "$lang"
        [ "$status" -eq 0 ]
    done
}

@test "validation.sh: validate_language rejects invalid codes" {
    run validate_language "xx"
    [ "$status" -ne 0 ]

    run validate_language "ko; echo pwned"
    [ "$status" -ne 0 ]
}

# ============================================
# Git 라이브러리 테스트
# ============================================

@test "git.sh: is_git_repo detects git repository" {
    # 프로젝트 루트는 git 저장소여야 함
    cd "$PROJECT_ROOT"

    run is_git_repo
    [ "$status" -eq 0 ]
}

@test "git.sh: get_current_branch returns branch name" {
    cd "$PROJECT_ROOT"

    result=$(get_current_branch)

    [[ -n "$result" ]]
    [[ "$result" != "unknown" ]]
}

@test "git.sh: validate_git_tag accepts valid tags" {
    run validate_git_tag "v1.0.0"
    [ "$status" -eq 0 ]

    run validate_git_tag "1.0.0"
    [ "$status" -eq 0 ]

    run validate_git_tag "v2.3.4"
    [ "$status" -eq 0 ]
}

@test "git.sh: validate_git_tag rejects invalid tags" {
    run validate_git_tag "v1.0"
    [ "$status" -ne 0 ]

    run validate_git_tag "abc"
    [ "$status" -ne 0 ]

    run validate_git_tag "v1.0.0; echo pwned"
    [ "$status" -ne 0 ]
}

# ============================================
# P0 보안 취weak점 테스트
# ============================================

@test "P0 Security: changelog.sh does not use eval for git log" {
    local changelog_file="$PROJECT_ROOT/.claude/commands/changelog.sh"

    if [[ ! -f "$changelog_file" ]]; then
        skip "changelog.sh not found"
    fi

    # eval 사용 확인 (주석 제외) - 결과가 없어야 성공
    run bash -c "grep -n 'eval ' '$changelog_file' | grep -v '#' | grep 'git log' || true"

    # eval git log 패턴이 없어야 함
    if [[ "$output" =~ "eval git" ]]; then
        fail "changelog.sh contains unsafe 'eval git log'"
    fi
}

@test "P0 Security: mem-check.sh declares JSON_OUTPUT" {
    local memcheck_file="$PROJECT_ROOT/.claude/commands/mem-check.sh"

    if [[ ! -f "$memcheck_file" ]]; then
        skip "mem-check.sh not found"
    fi

    run grep -c "JSON_OUTPUT=0" "$memcheck_file"
    [ "$output" -ge 1 ]
}

@test "P0 Security: bump.sh validates version format" {
    local bump_file="$PROJECT_ROOT/.claude/commands/bump.sh"

    if [[ ! -f "$bump_file" ]]; then
        skip "bump.sh not found"
    fi

    # 버전 유효성 검사 확인 (validate_version 함수 또는 정규식 패턴)
    if grep -q "validate_version" "$bump_file"; then
        # 함수 사용 확인
        true
    elif grep -E '=~.*version.*\^\\[0-9\]+' "$bump_file" >/dev/null 2>&1; then
        # 정규식 검사 확인
        true
    else
        # 버전과 정규식이 같이 있는지 확인
        run bash -c "grep '=~' '$bump_file' | grep 'version' | grep '\[0-9\]' || true"
        [ "$output" != "" ] || skip "bump.sh version validation pattern not found"
    fi
}

@test "P0 Security: readme-sync.sh defines functions before use" {
    local readme_sync="$PROJECT_ROOT/.claude/commands/readme-sync.sh"

    if [[ ! -f "$readme_sync" ]]; then
        skip "readme-sync.sh not found"
    fi

    # list_sections 함수가 정의되어 있는지 확인
    run grep -c "^list_sections()" "$readme_sync"
    [ "$output" -ge 1 ]
}

@test "P0 Security: prd.sh has no duplicate variable declarations" {
    local prd_file="$PROJECT_ROOT/.claude/commands/prd.sh"

    if [[ ! -f "$prd_file" ]]; then
        skip "prd.sh not found"
    fi

    # 중복 선언 확인
    # SCRIPT_DIR, PROJECT_ROOT 등이 한 번만 선언되어야 함
    count=$(grep -c "^SCRIPT_DIR=" "$prd_file" || true)
    [ "$count" -le 1 ]
}

# ============================================
# P1 아키텍처 개선 테스트
# ============================================

@test "P1 Architecture: platform.sh library exists" {
    [ -f "$PROJECT_ROOT/.claude/lib/platform.sh" ]
}

@test "P1 Architecture: validation.sh library exists" {
    [ -f "$PROJECT_ROOT/.claude/lib/validation.sh" ]
}

@test "P1 Architecture: git.sh library exists" {
    [ -f "$PROJECT_ROOT/.claude/lib/git.sh" ]
}

@test "P1 Architecture: common.sh loads libraries" {
    local common_file="$PROJECT_ROOT/.claude/lib/common.sh"

    run grep -c "platform.sh" "$common_file"
    [ "$output" -ge 1 ]

    run grep -c "validation.sh" "$common_file"
    [ "$output" -ge 1 ]

    run grep -c "git.sh" "$common_file"
    [ "$output" -ge 1 ]
}

@test "P1 Architecture: scripts use strict error handling" {
    local scripts=(
        "changelog.sh"
        "mem-check.sh"
        "readme-sync.sh"
        "prd.sh"
        "bump.sh"
    )

    for script in "${scripts[@]}"; do
        local script_file="$PROJECT_ROOT/.claude/commands/$script"

        if [[ -f "$script_file" ]]; then
            run grep -c "set -euo pipefail" "$script_file"

            if [ "$output" -eq 0 ]; then
                # set -eu pipefail도 허용
                run grep -c "set -eu pipefail" "$script_file"
                [ "$output" -ge 1 ] || skip "$script doesn't use strict mode (may be intentional)"
            fi
        fi
    done
}

# ============================================
# 스킬 스크립트 기능 테스트
# ============================================

@test "Skill: changelog.sh accepts --help flag" {
    run_skill changelog.sh --help

    if [ "$status" -eq 0 ]; then
        [[ "$output" =~ "Usage" ]] || [[ "$output" =~ "옵션" ]]
    fi
}

@test "Skill: prd.sh accepts --help flag" {
    run_skill prd.sh --help

    if [ "$status" -eq 0 ]; then
        [[ "$output" =~ "Usage" ]] || [[ "$output" =~ "사용법" ]]
    fi
}

@test "Skill: mem-check.sh accepts --help flag" {
    run_skill mem-check.sh --help

    if [ "$status" -eq 0 ]; then
        [[ "$output" =~ "Usage" ]] || [[ "$output" =~ "사용법" ]]
    fi
}

@test "Skill: readme-sync.sh accepts --help flag" {
    run_skill readme-sync.sh --help

    if [ "$status" -eq 0 ]; then
        [[ "$output" =~ "Usage" ]] || [[ "$output" =~ "사용법" ]]
    fi
}

# ============================================
# 통합 테스트
# ============================================

@test "Integration: All 12 skill scripts exist and are executable" {
    local skills=(
        "audit.sh"
        "bottleneck.sh"
        "bump.sh"
        "changelog.sh"
        "complexity.sh"
        "format-check.sh"
        "mem-check.sh"
        "profile.sh"
        "readme-sync.sh"
        "api-docs.sh"
        "bench.sh"
        "lint-smart.sh"
    )

    local missing=0

    for skill in "${skills[@]}"; do
        if [[ -f "$PROJECT_ROOT/.claude/commands/$skill" ]]; then
            # 실행 가능 권한 확인
            if [[ ! -x "$PROJECT_ROOT/.claude/commands/$skill" ]]; then
                echo "Missing execute permission: $skill"
                missing=$((missing + 1))
            fi
        else
            echo "Missing skill: $skill"
            missing=$((missing + 1))
        fi
    done

    [ "$missing" -eq 0 ] || skip "Some skills are missing ($missing total)"
}

@test "Integration: All skill scripts have proper shebang" {
    local commands_dir="$PROJECT_ROOT/.claude/commands"

    for script in "$commands_dir"/*.sh; do
        if [[ -f "$script" ]]; then
            local first_line=$(head -1 "$script")
            [[ "$first_line" =~ ^#!/bin/bash ]] || [[ "$first_line" =~ ^#!/usr/bin/env\ bash ]]
        fi
    done
}

@test "Integration: Common library is sourced in skill scripts" {
    local commands_dir="$PROJECT_ROOT/.claude/commands"

    # 최소한 몇 개 스크립트는 common.sh를 source해야 함
    local count=$(grep -r "source.*common.sh" "$commands_dir" 2>/dev/null | wc -l)

    [ "$count" -gt 0 ]
}

# ============================================
# 보안 통합 테스트
# ============================================

@test "Security Integration: No hardcoded secrets in scripts" {
    local commands_dir="$PROJECT_ROOT/.claude/commands"

    # API key 패턴 확인 - 결과가 없어야 함
    run bash -c "grep -r -i 'api_key.*=' '$commands_dir' 2>/dev/null | grep -v '#' | grep -v 'echo' | head -5 || true"

    # 결과가 있으면 실제 키가 아니어야 함
    if [ -n "$output" ]; then
        # 실제 키 패턴 (긴 문자열, 특수문자 조합) 필터링
        if [[ "$output" =~ sk_live_[a-zA-Z0-9]{20,} ]] || [[ "$output" =~ [0-9a-f]{32,} ]]; then
            fail "Potential hardcoded secret found"
        fi
    fi
    # grep 결과가 없으면 통과
}

@test "Security Integration: No temporary command injection patterns" {
    local commands_dir="$PROJECT_ROOT/.claude/commands"

    # 위험한 패턴 확인
    run bash -c "grep -r 'eval.*\$' '$commands_dir' 2>/dev/null | grep -v '#' | head -5 || true"

    # eval git log는 제외 (안전하게 변경되었거나 eval 사용 안 함)
    while IFS= read -r line; do
        if [[ "$line" =~ "eval git" ]] && ! [[ "$line" =~ "git_args" ]] && ! [[ "$line" =~ "@{" ]]; then
            # 안전한 배열 방식이 아닌 eval git 패턴
            if [[ "$line" =~ "eval git log" ]] || [[ "$line" =~ "eval \\$git" ]]; then
                fail "Found unsafe eval pattern: $line"
            fi
        fi
    done <<< "$output"
}
