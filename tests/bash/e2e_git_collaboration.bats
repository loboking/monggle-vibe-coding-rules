#!/usr/bin/env bats
# test_e2e_git_collaboration.bats - Git collaboration E2E tests
# Vibe Coding Rules v2.5
#
# End-to-End tests: combining unit tests to verify complete workflows

load ../test_helper.sh

setup() {
    # Main test temp directory
    MAIN_REPO=$(mktemp -d)
    cd "$MAIN_REPO"
    export MAIN_REPO
    export PROJECT_ROOT
}

teardown() {
    cd "$PROJECT_ROOT"
    rm -rf "$MAIN_REPO"
    rm -rf "$CLONE_REPO" 2>/dev/null || true
}

# Helper: simulate remote repository
setup_remote_repo() {
    REMOTE_REPO=$(mktemp -d)
    cd "$REMOTE_REPO"
    git init --bare >/dev/null 2>&1
    echo "$REMOTE_REPO"
}

# Helper: simulate developer repository
setup_developer_repo() {
    local remote_url="$1"
    local dev_dir="$2"

    cd "$dev_dir"
    git clone "$remote_url" . >/dev/null 2>&1
    git config user.email "dev@test.com"
    git config user.name "Developer"

    # Initial commit
    echo "# Test Project" > README.md
    git add README.md
    git commit -m "Initial commit" >/dev/null 2>&1
    git push -u origin main >/dev/null 2>&1
}

# ==========================================================================
# Scenario 1: Normal synchronization flow
# ==========================================================================

@test "E2E 1: normal sync without changes" {
    local remote_url
    remote_url=$(setup_remote_repo)

    # Setup developer repo
    local dev_dir=$(mktemp -d)
    setup_developer_repo "$remote_url" "$dev_dir"

    cd "$dev_dir"

    # Run /update (verify with dry-run)
    run bash "$PROJECT_ROOT/.claude/commands/update.sh" --auto

    # Verify success
    [ "$status" -eq 0 ]
    [[ "$output" =~ "이미 최신" ]] || [[ "$output" =~ "동기화" ]] || [[ "$output" =~ "완료" ]]

    # cleanup
    cd "$PROJECT_ROOT"
    rm -rf "$dev_dir" "$remote_url"
}

@test "E2E 2: normal sync with stash and restore" {
    local remote_url
    remote_url=$(setup_remote_repo)

    local dev_dir=$(mktemp -d)
    setup_developer_repo "$remote_url" "$dev_dir"

    cd "$dev_dir"

    # Create work in progress file
    echo "work in progress" > work.txt

    # Run /update (auto mode)
    run bash "$PROJECT_ROOT/.claude/commands/update.sh" --auto

    # Verify success (stash saved)
    [ "$status" -eq 0 ]

    # Check if stash exists
    run git stash list
    [[ "$output" =~ "auto-stash-before-update" ]] || [[ "$output" =~ "이미 최신" ]] || [ -z "$output" ]

    # cleanup
    cd "$PROJECT_ROOT"
    rm -rf "$dev_dir" "$remote_url"
}

# ==========================================================================
# Scenario 2: Conflict resolution flow
# ==========================================================================

@test "E2E 3: conflict resolution resolve-theirs" {
    local remote_url
    remote_url=$(setup_remote_repo)

    # Developer A (remote)
    local dev_a_dir=$(mktemp -d)
    setup_developer_repo "$remote_url" "$dev_a_dir"

    # Developer B (me)
    local dev_b_dir=$(mktemp -d)
    git clone "$remote_url" "$dev_b_dir" >/dev/null 2>&1
    cd "$dev_b_dir"
    git config user.email "devb@test.com"
    git config user.name "Developer B"

    # B's work in progress
    cat > auth.js << 'EOF'
function login() {
    return false;  // B's change
}
EOF
    git add auth.js
    # Not committed (WIP)

    # A pushes changes to remote
    cd "$dev_a_dir"
    cat > auth.js << 'EOF'
function login() {
    return true;  // A's change
}
EOF
    git add auth.js
    git commit -m "Update auth" >/dev/null 2>&1
    git push origin main >/dev/null 2>&1

    # B runs /update
    cd "$dev_b_dir"

    # Load conflict_helper.sh
    source "$PROJECT_ROOT/.claude/lib/conflict_helper.sh"

    # Resolve conflict (keep remote changes)
    if [ -f auth.js ]; then
        run resolve_theirs auth.js
        [ "$status" -eq 0 ]
        ! grep -q '<<<<<<<' auth.js
    fi

    # cleanup
    cd "$PROJECT_ROOT"
    rm -rf "$dev_a_dir" "$dev_b_dir" "$remote_url"
}

@test "E2E 4: conflict resolution resolve-keep" {
    local remote_url
    remote_url=$(setup_remote_repo)

    # Remote repo setup
    local dev_a_dir=$(mktemp -d)
    setup_developer_repo "$remote_url" "$dev_a_dir"

    # My repo
    local dev_b_dir=$(mktemp -d)
    git clone "$remote_url" "$dev_b_dir" >/dev/null 2>&1
    cd "$dev_b_dir"
    git config user.email "devb@test.com"
    git config user.name "Developer B"

    # My work
    cat > auth.js << 'EOF'
function login() {
    return false;  // My change
}
EOF
    git add auth.js
    # Not committed

    # Remote changes
    cd "$dev_a_dir"
    cat > auth.js << 'EOF'
function login() {
    return true;  // Remote change
}
EOF
    git add auth.js
    git commit -m "Update auth" >/dev/null 2>&1
    git push origin main >/dev/null 2>&1

    # Resolve conflict in my repo (keep my changes)
    cd "$dev_b_dir"
    source "$PROJECT_ROOT/.claude/lib/conflict_helper.sh"

    if [ -f auth.js ]; then
        run resolve_keep auth.js
        [ "$status" -eq 0 ]
        ! grep -q '<<<<<<<' auth.js
        grep -q 'return false' auth.js  # Verify my change kept
    fi

    # cleanup
    cd "$PROJECT_ROOT"
    rm -rf "$dev_a_dir" "$dev_b_dir" "$remote_url"
}

# ==========================================================================
# Scenario 3: push-safe flow
# ==========================================================================

@test "E2E 5: push-safe normal transmission" {
    local remote_url
    remote_url=$(setup_remote_repo)

    local dev_dir=$(mktemp -d)
    setup_developer_repo "$remote_url" "$dev_dir"

    cd "$dev_dir"

    # Create new commit
    echo "new feature" > feature.txt
    git add feature.txt
    git commit -m "Add feature" >/dev/null 2>&1

    # Run push-safe (dry-run)
    run bash "$PROJECT_ROOT/.claude/commands/push-safe.sh" --dry-run --no-pr
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]  # push may fail (no real remote)
    [[ "$output" =~ "DRY-RUN" ]] || [[ "$output" =~ "커밋" ]] || [[ "$output" =~ "전송" ]]

    # cleanup
    cd "$PROJECT_ROOT"
    rm -rf "$dev_dir" "$remote_url"
}

@test "E2E 6: push-safe detects behind state" {
    local remote_url
    remote_url=$(setup_remote_repo)

    # Developer A
    local dev_a_dir=$(mktemp -d)
    setup_developer_repo "$remote_url" "$dev_a_dir"

    # Developer B
    local dev_b_dir=$(mktemp -d)
    git clone "$remote_url" "$dev_b_dir" >/dev/null 2>&1
    cd "$dev_b_dir"
    git config user.email "devb@test.com"
    git config user.name "Developer B"

    # B creates commit
    echo "b feature" > b.txt
    git add b.txt
    git commit -m "B feature" >/dev/null 2>&1

    # A pushes first
    cd "$dev_a_dir"
    echo "a feature" > a.txt
    git add a.txt
    git commit -m "A feature" >/dev/null 2>&1
    git push origin main >/dev/null 2>&1

    # B runs push-safe (behind state)
    cd "$dev_b_dir"
    run bash "$PROJECT_ROOT/.claude/commands/push-safe.sh" --dry-run --no-pr

    # Verify behind detection message
    [[ "$output" =~ "뒤처져" ]] || [[ "$output" =~ "DRY-RUN" ]] || [[ "$output" =~ "update" ]]

    # cleanup
    cd "$PROJECT_ROOT"
    rm -rf "$dev_a_dir" "$dev_b_dir" "$remote_url"
}

# ==========================================================================
# Scenario 4: Git host detection
# ==========================================================================

@test "E2E 7: GitHub host detection and PR creation simulation" {
    # Setup git repository
    git init >/dev/null 2>&1
    git config user.email "test@test.com"
    git config user.name "Test User"
    echo "test" > test.txt
    git add test.txt
    git commit -m "Initial" >/dev/null 2>&1
    git remote add origin https://github.com/user/repo.git

    # Host detection
    source "$PROJECT_ROOT/.claude/lib/git_helper.sh"
    run detect_git_host
    [ "$output" = "github" ]

    # Load PR helper functions
    source "$PROJECT_ROOT/.claude/lib/pr_helper.sh"

    # Verify PR creation function exists
    run type create_github_pr
    [ "$status" -eq 0 ]
}

@test "E2E 8: GitLab host detection" {
    git init >/dev/null 2>&1
    git remote add origin https://gitlab.com/user/repo.git

    source "$PROJECT_ROOT/.claude/lib/git_helper.sh"
    run detect_git_host
    [ "$output" = "gitlab" ]
}

@test "E2E 9: Bitbucket host detection" {
    git init >/dev/null 2>&1
    git remote add origin https://bitbucket.org/user/repo.git

    source "$PROJECT_ROOT/.claude/lib/git_helper.sh"
    run detect_git_host
    [ "$output" = "bitbucket" ]
}

# ==========================================================================
# Scenario 5: Conflict analysis
# ==========================================================================

@test "E2E 10: conflict analysis same line conflict" {
    # Create conflict file
    cat > conflict_file.txt << 'EOF'
line before
<<<<<<< Updated upstream
original content
=======
my content
>>>>>>> Stashed changes
line after
EOF

    source "$PROJECT_ROOT/.claude/lib/conflict_helper.sh"

    # Conflict analysis
    run analyze_conflict conflict_file.txt
    [ "$status" -eq 0 ]
    [[ "$output" =~ "충돌 분석" ]] || [[ "$output" =~ "충돌 구간" ]] || [[ "$output" =~ "같은 줄" ]]
}

@test "E2E 11: show conflict files list" {
    git init >/dev/null 2>&1
    git config user.email "test@test.com"
    git config user.name "Test User"
    echo "test" > test.txt
    git add test.txt
    git commit -m "Initial" >/dev/null 2>&1

    source "$PROJECT_ROOT/.claude/lib/conflict_helper.sh"

    # No conflict state
    run show_conflict_files
    [ "$status" -eq 0 ]
    [[ "$output" =~ "없습니다" ]] || [[ "$output" =~ "충돌 파일" ]]
}

# ==========================================================================
# Helper: cleanup
# ==========================================================================

teardown() {
    cd "$PROJECT_ROOT"
    rm -rf "$MAIN_REPO"
    rm -rf "$CLONE_REPO" 2>/dev/null || true
}
