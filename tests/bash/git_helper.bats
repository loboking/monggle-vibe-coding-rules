#!/usr/bin/env bats
# test_git_helper.bats - Git helper library tests
# Vibe Coding Rules v2.5

load ../test_helper.sh

setup() {
    # Test temp directory
    TEST_DIR=$(mktemp -d)
    export TEST_DIR
    cd "$TEST_DIR"
}

teardown() {
    cd "$PROJECT_ROOT"
    rm -rf "$TEST_DIR"
}

# Load git_helper.sh
load_git_helper() {
    source "$PROJECT_ROOT/.claude/lib/git_helper.sh"
}

@test "is_git_repo: returns true for git repository" {
    git init >/dev/null 2>&1
    load_git_helper

    run is_git_repo
    [ "$status" -eq 0 ]
}

@test "is_git_repo: correctly identifies repository after init" {
    # Verify that git init creates a detectable repository
    rm -rf .git 2>/dev/null || true
    git init >/dev/null 2>&1
    load_git_helper

    run is_git_repo
    [ "$status" -eq 0 ]
}

@test "has_uncommitted_changes: returns false when no changes" {
    git init >/dev/null 2>&1
    git config user.email "test@test.com"
    git config user.name "Test User"
    echo "test" > test.txt
    git add test.txt
    git commit -m "Initial commit" >/dev/null 2>&1
    load_git_helper

    run has_uncommitted_changes
    [ "$status" -eq 1 ]
}

@test "has_uncommitted_changes: returns true when changes exist" {
    git init >/dev/null 2>&1
    git config user.email "test@test.com"
    git config user.name "Test User"
    echo "test" > test.txt
    git add test.txt
    git commit -m "Initial commit" >/dev/null 2>&1
    echo "changed" > test.txt
    load_git_helper

    run has_uncommitted_changes
    [ "$status" -eq 0 ]
}

@test "get_current_branch: returns branch name" {
    git init >/dev/null 2>&1
    git config user.email "test@test.com"
    git config user.name "Test User"
    echo "test" > test.txt
    git add test.txt
    git commit -m "Initial commit" >/dev/null 2>&1
    load_git_helper

    run get_current_branch
    [ "$output" = "main" ] || [ "$output" = "master" ]
}

@test "detect_git_host: detects GitHub URL" {
    git init >/dev/null 2>&1
    git remote add origin https://github.com/user/repo.git
    load_git_helper

    run detect_git_host
    [ "$output" = "github" ]
}

@test "detect_git_host: detects GitLab URL" {
    git init >/dev/null 2>&1
    git remote add origin https://gitlab.com/user/repo.git
    load_git_helper

    run detect_git_host
    [ "$output" = "gitlab" ]
}

@test "detect_git_host: detects Bitbucket URL" {
    git init >/dev/null 2>&1
    git remote add origin https://bitbucket.org/user/repo.git
    load_git_helper

    run detect_git_host
    [ "$output" = "bitbucket" ]
}

@test "detect_git_host: returns unknown for unrecognized URL" {
    git init >/dev/null 2>&1
    git remote add origin https://unknown.com/user/repo.git
    load_git_helper

    run detect_git_host
    [ "$output" = "unknown" ]
}

@test "get_remote_url: returns remote repository URL" {
    git init >/dev/null 2>&1
    git remote add origin https://github.com/user/repo.git
    load_git_helper

    run get_remote_url
    [ "$output" = "https://github.com/user/repo.git" ]
}

@test "get_remote_url: returns empty when no remote configured" {
    git init >/dev/null 2>&1
    load_git_helper

    run get_remote_url
    [ -z "$output" ]
}
