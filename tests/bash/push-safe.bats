#!/usr/bin/env bats
# push-safe.sh — 받기·rebase·비밀값 검사·push·PR 을 임시 원격(bare)으로 검사한다.

load ../test_helper.sh

PS() { bash "$PROJECT_ROOT/bin/push-safe.sh" "$@"; }

setup() {
    TEST_DIR="$(mktemp -d)"
    export GIT_CONFIG_GLOBAL="$TEST_DIR/gitconfig"
    git config --global user.email t@t.t; git config --global user.name t
    git config --global init.defaultBranch main
    git init -q --bare "$TEST_DIR/remote.git"
    git clone -q "$TEST_DIR/remote.git" "$TEST_DIR/a" 2>/dev/null
    cd "$TEST_DIR/a"
    echo base > f.txt; git add f.txt; git commit -qm base; git push -q -u origin main
}

teardown() { cd /; rm -rf "$TEST_DIR"; }

remote_head() { git --git-dir="$TEST_DIR/remote.git" rev-parse "${1:-main}"; }

# 다른 사람(b)이 원격에 커밋을 올린다
other_pushes() {
    git clone -q "$TEST_DIR/remote.git" "$TEST_DIR/b"
    (cd "$TEST_DIR/b" && echo "$1" > "${2:-g.txt}" && git add -A && git commit -qm other && git push -q)
}

@test "help lists options" {
    run PS --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--no-pr"* && "$output" == *"--dry-run"* ]]
}

@test "errors outside a git repository" {
    cd "$TEST_DIR"
    run PS
    [ "$status" -ne 0 ]
    [[ "$output" == *"Git 저장소가 아닙니다"* ]]
}

@test "nothing to push" {
    run PS
    [ "$status" -eq 0 ]
    [[ "$output" == *"보낼 커밋이 없습니다"* ]]
}

@test "normal push reaches the remote" {
    echo x >> f.txt; git commit -qam change
    run PS
    [ "$status" -eq 0 ]
    [ "$(remote_head)" = "$(git rev-parse HEAD)" ]
}

@test "behind: rebases with autostash then pushes" {
    other_pushes theirs
    echo mine >> f.txt; git commit -qam mine
    echo dirty > untracked-but-staged.txt; git add untracked-but-staged.txt
    run PS
    [ "$status" -eq 0 ]
    [ "$(remote_head)" = "$(git rev-parse HEAD)" ]
    [ -f g.txt ]                                   # 남의 커밋을 받았고
    git diff --cached --name-only | grep -q untracked-but-staged.txt   # 내 작업은 그대로
}

@test "conflict: stops and does not push" {
    other_pushes theirs f.txt
    echo mine > f.txt; git commit -qam mine
    before="$(remote_head)"
    run PS
    [ "$status" -ne 0 ]
    [[ "$output" == *"충돌"* ]]
    [ "$(remote_head)" = "$before" ]
    git rebase --abort
}

@test "secret in outgoing commit blocks push" {
    echo 'API_KEY = "abcd1234efgh5678"' > conf.py; git add conf.py; git commit -qm secret  # pragma: allowlist secret
    before="$(remote_head)"
    run PS
    [ "$status" -ne 0 ]
    [[ "$output" == *"비밀값 의심"* ]]
    [ "$(remote_head)" = "$before" ]
}

@test "secret file (.env) blocks push" {
    echo X=1 > .env; git add .env; git commit -qm env
    run PS
    [ "$status" -ne 0 ]
    [[ "$output" == *".env"* ]]
}

@test "allowlisted fake value passes" {
    echo 'password = "hunter2hunter2"  # pragma: allowlist secret' > t.sh; git add t.sh; git commit -qm fake
    run PS
    [ "$status" -eq 0 ]
    [ "$(remote_head)" = "$(git rev-parse HEAD)" ]
}

@test "dry-run changes nothing" {
    other_pushes theirs
    echo mine >> f.txt; git commit -qam mine
    head_before="$(git rev-parse HEAD)"; remote_before="$(remote_head)"
    run PS --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"[DRY-RUN]"* ]]
    [ "$(git rev-parse HEAD)" = "$head_before" ]
    [ "$(remote_head)" = "$remote_before" ]
}

@test "new branch is pushed with upstream" {
    git checkout -qb feat; echo n > n.txt; git add n.txt; git commit -qm n
    run PS --no-pr
    [ "$status" -eq 0 ]
    [ "$(remote_head feat)" = "$(git rev-parse HEAD)" ]
}

@test "team mode on a feature branch plans a PR" {
    echo 'mode: team' > monggle.config.yaml; git add monggle.config.yaml; git commit -qm mode; git push -q
    git checkout -qb feat; echo n > n.txt; git add n.txt; git commit -qm n
    run PS --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"gh pr create"* ]]
}

@test "script never force-pushes" {
    ! grep -nE 'push.*(--force|-f( |$)|\+HEAD)' "$PROJECT_ROOT/bin/push-safe.sh"
}
