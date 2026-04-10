#!/usr/bin/env bats
# test_push_safe.bats - /push-safe script tests
# Vibe Coding Rules v2.5

load ../test_helper.sh

setup() {
    # Test temp directory
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"
    export PROJECT_ROOT
}

teardown() {
    cd "$PROJECT_ROOT"
    rm -rf "$TEST_DIR"
}

# Helper to create a bare remote repository
setup_bare_remote() {
    local bare_repo="$1"
    git init --bare "$bare_repo" >/dev/null 2>&1
}

@test "push-safe.sh: --help shows help message" {
    run bash "$PROJECT_ROOT/.claude/commands/push-safe.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
    [[ "$output" =~ "--no-pr" ]]
    [[ "$output" =~ "--dry-run" ]]
}

@test "push-safe.sh: --dry-run shows execution plan" {
    # Create bare remote repository
    local bare_repo
    bare_repo=$(mktemp -d)
    setup_bare_remote "$bare_repo"

    # Create git repository with remote
    git init >/dev/null 2>&1
    git config user.email "test@test.com"
    git config user.name "Test User"
    echo "test" > test.txt
    git add test.txt
    git commit -m "Initial" >/dev/null 2>&1
    git remote add origin "$bare_repo"
    git push -u origin main >/dev/null 2>&1

    run bash "$PROJECT_ROOT/.claude/commands/push-safe.sh" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "[DRY-RUN]" ]] || [[ "$output" =~ "전송할" ]] || [[ "$output" =~ "없습니다" ]]

    # cleanup
    cd "$TEST_DIR"
    rm -rf "$bare_repo"
}

@test "push-safe.sh: errors when not in git repository" {
    # No git init
    run bash "$PROJECT_ROOT/.claude/commands/push-safe.sh"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Git 저장소가 아닙니다" ]]
}

@test "push-safe.sh: shows message when no commits to push" {
    # Create bare remote repository
    local bare_repo
    bare_repo=$(mktemp -d)
    setup_bare_remote "$bare_repo"

    # Create git repository with remote
    git init >/dev/null 2>&1
    git config user.email "test@test.com"
    git config user.name "Test User"
    echo "test" > test.txt
    git add test.txt
    git commit -m "Initial" >/dev/null 2>&1
    git remote add origin "$bare_repo"
    git push -u origin main >/dev/null 2>&1

    # Make remote up to date (no commits to push)
    run bash "$PROJECT_ROOT/.claude/commands/push-safe.sh" --no-pr
    [[ "$output" =~ "전송할" ]] || [[ "$output" =~ "없습니다" ]]

    # cleanup
    cd "$TEST_DIR"
    rm -rf "$bare_repo"
}

@test "push-safe.sh: --no-pr option works" {
    # Create bare remote repository
    local bare_repo
    bare_repo=$(mktemp -d)
    setup_bare_remote "$bare_repo"

    # Create git repository with remote
    git init >/dev/null 2>&1
    git config user.email "test@test.com"
    git config user.name "Test User"
    echo "test" > test.txt
    git add test.txt
    git commit -m "Initial" >/dev/null 2>&1
    git remote add origin "$bare_repo"
    git push -u origin main >/dev/null 2>&1

    echo "changed" > test.txt
    git add test.txt
    git commit -m "Second" >/dev/null 2>&1

    # --dry-run should work
    run bash "$PROJECT_ROOT/.claude/commands/push-safe.sh" --no-pr --dry-run
    [[ "$output" =~ "DRY-RUN" ]] || [[ "$output" =~ "커밋이 있습니다" ]]

    # cleanup
    cd "$TEST_DIR"
    rm -rf "$bare_repo"
}

@test "push-safe.sh: detects GitHub host" {
    git init >/dev/null 2>&1
    git remote add origin https://github.com/user/repo.git

    source "$PROJECT_ROOT/.claude/lib/git_helper.sh"
    run detect_git_host
    [ "$output" = "github" ]
}

@test "push-safe.sh: detects GitLab host" {
    git init >/dev/null 2>&1
    git remote add origin https://gitlab.com/user/repo.git

    source "$PROJECT_ROOT/.claude/lib/git_helper.sh"
    run detect_git_host
    [ "$output" = "gitlab" ]
}

@test "push-safe.sh: detects Bitbucket host" {
    git init >/dev/null 2>&1
    git remote add origin https://bitbucket.org/user/repo.git

    source "$PROJECT_ROOT/.claude/lib/git_helper.sh"
    run detect_git_host
    [ "$output" = "bitbucket" ]
}
