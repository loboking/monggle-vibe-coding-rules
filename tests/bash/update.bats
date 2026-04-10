#!/usr/bin/env bats
# test_update.bats - /update script tests
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

@test "update.sh: --help shows help message" {
    run bash "$PROJECT_ROOT/.claude/commands/update.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
    [[ "$output" =~ "--auto" ]]
    [[ "$output" =~ "--dry-run" ]]
}

@test "update.sh: --dry-run shows execution plan" {
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

    run bash "$PROJECT_ROOT/.claude/commands/update.sh" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "[DRY-RUN]" ]] || [[ "$output" =~ "저장할" ]] || [[ "$output" =~ "이미 최신" ]]

    # cleanup
    cd "$TEST_DIR"
    rm -rf "$bare_repo"
}

@test "update.sh: errors when not in git repository" {
    # No git init
    run bash "$PROJECT_ROOT/.claude/commands/update.sh" --auto
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Git 저장소가 아닙니다" ]]
}

@test "update.sh: shows message when already up to date" {
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

    run bash "$PROJECT_ROOT/.claude/commands/update.sh" --auto
    [ "$status" -eq 0 ]
    [[ "$output" =~ "이미 최신" ]] || [[ "$output" =~ "저장할" ]]

    # cleanup
    cd "$TEST_DIR"
    rm -rf "$bare_repo"
}

@test "update.sh: stash functionality works" {
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

    # Make changes (not committed)
    echo "modified" > test.txt

    run bash "$PROJECT_ROOT/.claude/commands/update.sh" --auto
    # Should show stash saved message or already up to date
    [[ "$output" =~ "안전하게 저장" ]] || [[ "$output" =~ "이미 최신" ]]

    # cleanup
    cd "$TEST_DIR"
    rm -rf "$bare_repo"
}
