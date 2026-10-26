#!/usr/bin/env bats
# test-report.sh — 테스트 실행 결과를 결론이 먼저 보이는 보고서로 남기는지 검사한다.

load ../test_helper.sh

TR() { bash "$PROJECT_ROOT/bin/test-report.sh" "$@"; }
last() { ls "$TEST_DIR/.monggle/reports/"*-"${1:-qa}".md | sort | tail -1; }

setup() {
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"
    git init -q
    mkdir -p src tests
    echo 'def foo(): return 1' > src/foo.py
    echo 'from src.foo import foo' > tests/test_foo.py
    echo 'x' > src/other.py
    git add -A; git -c user.name=t -c user.email=t@t commit -qm init
}

teardown() { cd /; rm -rf "$TEST_DIR"; }

@test "pass: report says go ahead and is git-ignored" {
    run TR -- true
    [ "$status" -eq 0 ]
    grep -q '^# ✅ 점검 결과: 진행해도 됩니다' "$(last)"
    [ -f "${TEST_DIR}/.monggle/reports/.gitignore" ]
    [ -f "$(last | sed 's/\.md$/.html/')" ]
    [ -z "$(git status --porcelain)" ]
}

@test "fail: report says hold and lists failing tests" {
    run TR -- 'printf "ok 1 a\nnot ok 2 b\n"; exit 1'
    [ "$status" -eq 1 ]
    grep -q '❌ 점검 결과: 보류 — 실패 1건' "$(last)"
    grep -q '^not ok 2 b$' "$(last)"
    grep -q '1 통과 / 1 실패' "$(last)"
}

@test "compares with previous report: new vs fixed vs pre-existing" {
    TR -- 'printf "not ok 1 old\nnot ok 2 gone\n"; exit 1' || true
    sleep 1
    run TR -- 'printf "not ok 1 old\nnot ok 3 new\n"; exit 1'
    grep -q '새로 깨짐 / 고쳐짐 (지난번 대비) | 1건 / 1건' "$(last)"
    sleep 1
    run TR -- 'printf "not ok 1 old\n"; exit 1'
    grep -q '⚠️ 점검 결과: 판단 필요 — 실패 1건은 원래 있던 것' "$(last)"
}

@test "fix: changed file finds its related test and embeds the note" {
    echo 'def foo(): return 2' > src/foo.py
    printf -- '- 문제: foo 값 오류\n' > "$TEST_DIR/note.md"
    run TR --kind fix --note "$TEST_DIR/note.md" -- true
    [ "$status" -eq 0 ]
    grep -q '`tests/test_foo.py`' "$(last fix)"
    grep -q '## 무엇을 했나' "$(last fix)"
    grep -q 'foo 값 오류' "$(last fix)"
}

@test "fix without related test: passes but warns unverified" {
    echo 'y' > src/other.py
    run TR --kind fix -- true
    grep -q '⚠️ 수정 결과: 통과했지만 이번 수정은 검증되지 않았습니다' "$(last fix)"
}

@test "crash without test lines: hold and show log tail" {
    run TR -- 'echo "build error: missing dep"; exit 2'
    [ "$status" -eq 2 ]
    grep -q '보류 — 테스트 실행이 실패했습니다' "$(last)"
    grep -q 'build error: missing dep' "$(last)"
}

@test "no test command: asks for a decision" {
    rm -rf tests; git add -A; git -c user.name=t -c user.email=t@t commit -qm rm
    run TR
    grep -q '판단 필요 — 테스트가 없어' "$(last)"
}

@test "detects project test command" {
    printf '#!/bin/bash\necho "ok 1 runner"\n' > tests/run_tests.sh
    run TR
    [ "$status" -eq 0 ]
    grep -q '`bash tests/run_tests.sh`' "$(last)"
}

@test "html escapes note content" {
    printf -- '- <script>x</script>\n' > "$TEST_DIR/note.md"
    TR --note "$TEST_DIR/note.md" -- true
    ! grep -q '<script>x' "$(last | sed 's/\.md$/.html/')"
}

@test "open-last without reports fails cleanly" {
    run TR --open-last
    [ "$status" -eq 1 ]
    [[ "$output" == *"보고서가 없습니다"* ]]
}
