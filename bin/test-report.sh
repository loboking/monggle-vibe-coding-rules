#!/bin/bash
# test-report.sh - 테스트를 돌리고 사람이 한눈에 볼 보고서(.monggle/reports/*.md)를 남긴다.
# 관련 테스트 찾기·실행·지난 결과와 비교를 스크립트로 고정한다(AI 가 빼먹지 않게).
set -euo pipefail

show_usage() {
    cat <<'EOF'
Usage: test-report [options] [-- <테스트 명령>]

  --kind qa|fix    보고서 종류 (기본 qa)
  --note <file>    AI 가 쓴 메모(고친 내용·원인·영향)를 보고서에 넣는다
  --open           만든 뒤 바로 연다
  --open-last      테스트 없이 가장 최근 보고서를 연다 (--kind 로 종류 지정)
  -h, --help       도움말

테스트 명령을 주지 않으면 프로젝트에서 찾는다:
  tests/run_tests.sh, npm test, pytest, go test, cargo test, gradlew test, make test, bats
EOF
}

KIND=qa NOTE="" OPEN=false OPEN_LAST=false CMD=""
while [ $# -gt 0 ]; do
    case "$1" in
        --kind) KIND="${2:?--kind 에 qa|fix 가 필요합니다}"; shift ;;
        --note) NOTE="${2:?--note 에 파일이 필요합니다}"; shift ;;
        --open) OPEN=true ;;
        --open-last) OPEN_LAST=true ;;
        -h|--help) show_usage; exit 0 ;;
        --) shift; CMD="$*"; break ;;
        *) show_usage >&2; echo "알 수 없는 옵션: $1" >&2; exit 2 ;;
    esac
    shift
done

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
OUT="$ROOT/.monggle/reports"

open_file() {
    if command -v open >/dev/null 2>&1; then open "$1"
    elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$1" >/dev/null 2>&1 &
    else echo "열 프로그램이 없습니다: $1"; fi
}

latest() { ls -1 "$OUT"/*-"$KIND".md 2>/dev/null | sort | tail -1 || true; }

if [ "$OPEN_LAST" = true ]; then
    LAST="$(latest)"
    [ -n "$LAST" ] || { echo "보고서가 없습니다: $OUT"; exit 1; }
    H="${LAST%.md}.html"; [ -f "$H" ] && LAST="$H"
    echo "$LAST"; open_file "$LAST"; exit 0
fi

cd "$ROOT"
detect_cmd() {
    if [ -f tests/run_tests.sh ]; then echo "bash tests/run_tests.sh"
    elif [ -f package.json ] && grep -q '"test"[[:space:]]*:' package.json && ! grep -q 'no test specified' package.json; then echo "npm test --silent"
    elif [ -f pytest.ini ] || [ -f conftest.py ] || grep -qs '\[tool.pytest' pyproject.toml || ls tests/test_*.py >/dev/null 2>&1; then echo "python3 -m pytest -q"
    elif [ -f go.mod ]; then echo "go test ./..."
    elif [ -f Cargo.toml ]; then echo "cargo test"
    elif [ -x gradlew ]; then echo "./gradlew test"
    elif [ -f Makefile ] && grep -q '^test:' Makefile; then echo "make test"
    elif ls tests/*.bats tests/*/*.bats >/dev/null 2>&1; then echo "bats -r tests"
    fi
}
[ -n "$CMD" ] || CMD="$(detect_cmd)"

# 바뀐 파일 → 관련 테스트 파일 (이름이나 내용에 바뀐 파일 이름이 들어간 테스트)
CHANGED=""; RELATED=""
if git rev-parse --git-dir >/dev/null 2>&1; then
    CHANGED="$( { git diff --name-only HEAD 2>/dev/null; git ls-files --others --exclude-standard; } | grep -v '^\.monggle/' | sort -u || true)"
    TEST_RE='(^|/)(tests?|__tests__|spec)/|[._-](test|spec)\.[a-z]+$|(^|/)test_[^/]*$'
    TESTS="$(git ls-files --cached --others --exclude-standard | grep -E "$TEST_RE" || true)"
    for f in $CHANGED; do
        if echo "$f" | grep -qE "$TEST_RE"; then RELATED="$RELATED"$'\n'"$f"; continue; fi
        stem="$(basename "$f")"; stem="${stem%.*}"
        [ ${#stem} -ge 3 ] && [ -n "$TESTS" ] || continue
        RELATED="$RELATED"$'\n'"$(echo "$TESTS" | grep -F "$stem" || true)"
        RELATED="$RELATED"$'\n'"$(echo "$TESTS" | xargs grep -lwF "$stem" 2>/dev/null || true)"
    done
    RELATED="$(echo "$RELATED" | grep -v '^$' | sort -u | head -30 || true)"
fi

mkdir -p "$OUT"
[ -f "$OUT/.gitignore" ] || echo '*' > "$OUT/.gitignore"
STAMP="$(date +%Y%m%d-%H%M%S)"
while [ -e "$OUT/$STAMP-$KIND.md" ]; do sleep 1; STAMP="$(date +%Y%m%d-%H%M%S)"; done
PREV="$(latest)"
REPORT="$OUT/$STAMP-$KIND.md"
LOG="$OUT/$STAMP-$KIND.log"

# 실행
STATUS=0 START=$SECONDS
if [ -n "$CMD" ]; then
    echo "[test-report] 실행: $CMD"
    bash -c "$CMD" >"$LOG" 2>&1 || STATUS=$?
else
    echo "테스트 명령을 찾지 못했습니다." >"$LOG"; STATUS=3
fi
DUR=$((SECONDS - START))
CLEAN="$(sed $'s/\x1b\\[[0-9;]*[A-Za-z]//g' "$LOG")"

FAILS="$(echo "$CLEAN" | grep -E '^not ok|FAILED|^FAIL|^--- FAIL|✗|✕' | sed 's/[[:space:]]*$//' | sort -u | head -40 || true)"
SUMMARY="$(echo "$CLEAN" | grep -Ei '[0-9]+ (passed|failed|passing|failing|tests?)|^Tests?:' | tail -3 || true)"
OKS="$(echo "$CLEAN" | grep -c '^ok ' || true)"; NOKS="$(echo "$CLEAN" | grep -c '^not ok ' || true)"
[ $((OKS + NOKS)) -gt 0 ] && SUMMARY="$OKS 통과 / $NOKS 실패"

# 지난 보고서와 비교
NEW_FAILS="" FIXED=""
if [ -n "$PREV" ]; then
    prev_fails() { sed -n '/^<!-- failures -->$/,/^<!-- \/failures -->$/p' "$PREV" | grep -v '^<!--\|^```' || true; }
    NEW_FAILS="$(comm -13 <(prev_fails | sort -u) <(echo "$FAILS" | grep -v '^$' | sort -u) || true)"
    FIXED="$(comm -23 <(prev_fails | sort -u) <(echo "$FAILS" | grep -v '^$' | sort -u) || true)"
fi

# 판단: 사람이 바로 결정할 수 있게 한 줄 결론 + 이유 + 다음 할 일
NFAIL="$(echo "$FAILS" | grep -c . || true)"
NNEW="$(echo "$NEW_FAILS" | grep -c . || true)"
NFIXED="$(echo "$FIXED" | grep -c . || true)"
WHAT="$([ "$KIND" = fix ] && echo 수정 || echo 점검)"
if [ -z "$CMD" ]; then
    ICON="⚠️"; DECISION="판단 필요 — 테스트가 없어 동작을 확인하지 못했습니다"
    WHY="이 프로젝트에서 테스트 명령을 찾지 못했습니다."
    NEXT="직접 실행해 확인하거나, 이번 변경을 검사하는 테스트를 하나 추가한다."
elif [ "$STATUS" -eq 0 ]; then
    ICON="✅"; DECISION="진행해도 됩니다"
    WHY="테스트가 모두 통과했습니다."
    [ "$NFIXED" -gt 0 ] && WHY="$WHY 지난번 실패 ${NFIXED}건이 고쳐졌습니다."
    NEXT="커밋·푸시해도 된다."
    if [ "$KIND" = fix ] && [ -z "$RELATED" ]; then
        ICON="⚠️"; DECISION="통과했지만 이번 수정은 검증되지 않았습니다"
        WHY="$WHY 그러나 바뀐 코드를 직접 검사하는 테스트가 없습니다."
        NEXT="고친 동작을 재현하는 테스트를 하나 추가하거나, 직접 실행해 확인한 뒤 진행한다."
    fi
elif [ "$NFAIL" -eq 0 ]; then
    ICON="❌"; DECISION="보류 — 테스트 실행이 실패했습니다"
    WHY="어떤 테스트가 깨졌는지 줄을 찾지 못했습니다(빌드·설정 오류일 수 있음)."
    NEXT="아래 '로그 마지막 줄'을 보고 원인을 고친 뒤 다시 실행한다."
elif [ -n "$PREV" ] && [ "$NNEW" -eq 0 ]; then
    ICON="⚠️"; DECISION="판단 필요 — 실패 ${NFAIL}건은 원래 있던 것입니다"
    WHY="지난 보고서에도 같은 실패가 있었습니다. 이번 변경 때문에 새로 깨진 것은 없습니다."
    NEXT="기존 실패를 감수하고 진행할지, 먼저 고칠지 정한다."
else
    ICON="❌"; DECISION="보류 — 실패 ${NFAIL}건, 먼저 고쳐야 합니다"
    WHY="테스트 ${NFAIL}건이 실패했습니다."
    [ -n "$PREV" ] && WHY="$WHY 그중 ${NNEW}건은 이번에 새로 깨졌습니다."
    NEXT="'실패한 테스트'부터 고친다(fix). 고친 뒤 다시 실행한다."
fi

block() { if [ -n "$1" ]; then echo '```'; echo "$1"; echo '```'; else echo "${2:-없음}"; fi; }
{
    echo "# $ICON $WHAT 결과: $DECISION"
    echo
    echo "## 결론"
    echo "- **판단**: $DECISION"
    echo "- **이유**: $WHY"
    echo "- **다음 할 일**: $NEXT"
    echo
    if [ -n "$NOTE" ] && [ -f "$NOTE" ]; then
        echo "## 무엇을 했나"
        cat "$NOTE"; echo
    fi
    echo "## 숫자로 보기"
    echo "| 항목 | 값 |"
    echo "|---|---|"
    echo "| 실패 | ${NFAIL}건 |"
    [ -n "$PREV" ] && echo "| 새로 깨짐 / 고쳐짐 (지난번 대비) | ${NNEW}건 / ${NFIXED}건 |"
    echo "| 결과 요약 | $(echo "${SUMMARY:-—}" | tr '\n' ' ' | sed 's/|/\\|/g') |"
    echo "| 걸린 시간 | ${DUR}초 |"
    echo "| 실행 명령 | \`${CMD:-없음}\` |"
    echo "| 시각 · 위치 | $(date '+%Y-%m-%d %H:%M') · \`$(basename "$ROOT")\` $(git rev-parse --abbrev-ref HEAD 2>/dev/null || true) |"
    echo
    echo "## 실패한 테스트"
    echo "<!-- failures -->"
    [ -n "$FAILS" ] && { echo '```'; echo "$FAILS"; echo '```'; }
    echo "<!-- /failures -->"
    [ -z "$FAILS" ] && echo "없음"
    [ "$NNEW" -gt 0 ] && { echo; echo "이번에 새로 깨진 것:"; block "$NEW_FAILS"; }
    [ "$NFIXED" -gt 0 ] && { echo; echo "지난번 실패 중 고쳐진 것:"; block "$FIXED"; }
    echo
    echo "## 세부 내용"
    echo "### 관련 테스트 (바뀐 파일과 이어진 것)"
    if [ -n "$RELATED" ]; then echo "$RELATED" | sed 's/^/- `/; s/$/`/'; else echo "찾지 못했습니다."; fi
    echo
    echo "### 바뀐 파일"
    block "$(git diff --stat HEAD 2>/dev/null | tail -30 || true)" "없음 (커밋된 상태)"
    if [ "$STATUS" -ne 0 ]; then echo; echo "### 로그 마지막 줄"; block "$(echo "$CLEAN" | tail -20)"; fi
    echo
    echo "전체 로그: \`$(basename "$LOG")\`"
} >"$REPORT"

# 열어 볼 때는 같은 내용을 보기 좋은 HTML 로 (보고서 형식이 정해져 있어 작은 변환기로 충분)
md2html() {
    local title; title="$(head -1 "$1" | sed 's/^# //')"
    cat <<HTML
<!doctype html><html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>$title</title><style>
:root{--bg:#fff;--fg:#1d1d1f;--mut:#6e6e73;--line:#e5e5ea;--code:#f5f5f7}
@media (prefers-color-scheme:dark){:root{--bg:#1c1c1e;--fg:#f2f2f7;--mut:#a1a1a6;--line:#3a3a3c;--code:#2c2c2e}}
body{background:var(--bg);color:var(--fg);font:16px/1.6 -apple-system,"Apple SD Gothic Neo",sans-serif;max-width:860px;margin:0 auto;padding:24px 16px}
h1{font-size:1.5em;padding:16px;border-radius:10px;background:var(--code)}h2{margin-top:1.6em;border-bottom:1px solid var(--line)}h3{color:var(--mut)}
table{border-collapse:collapse;width:100%}td{border-bottom:1px solid var(--line);padding:6px 8px;vertical-align:top}td:first-child{color:var(--mut);width:40%}
pre{background:var(--code);padding:12px;border-radius:8px;overflow-x:auto;font-size:13px}code{background:var(--code);padding:1px 4px;border-radius:4px}
</style></head><body>
HTML
    awk '
    function esc(s){gsub(/&/,"\\&amp;",s);gsub(/</,"\\&lt;",s);gsub(/>/,"\\&gt;",s);return s}
    function inl(s){s=esc(s);while(match(s,/`[^`]+`/)){s=substr(s,1,RSTART-1)"<code>"substr(s,RSTART+1,RLENGTH-2)"</code>"substr(s,RSTART+RLENGTH)};while(match(s,/\*\*[^*]+\*\*/)){s=substr(s,1,RSTART-1)"<b>"substr(s,RSTART+2,RLENGTH-4)"</b>"substr(s,RSTART+RLENGTH)};return s}
    function close_all(){if(ul){print "</ul>";ul=0}if(tb){print "</table>";tb=0}}
    /^```/{close_all(); if(pre){print "</pre>";pre=0}else{printf "<pre>";pre=1}; next}
    pre{print esc($0); next}
    /^<!--/{next}
    /^### /{close_all(); print "<h3>" inl(substr($0,5)) "</h3>"; next}
    /^## /{close_all(); print "<h2>" inl(substr($0,4)) "</h2>"; next}
    /^# /{close_all(); print "<h1>" inl(substr($0,3)) "</h1>"; next}
    /^\|---/{next}
    /^\|/{if(!tb){print "<table>";tb=1}; n=split($0,c,"|"); r="<tr>"; for(i=2;i<n;i++)r=r "<td>" inl(c[i]) "</td>"; print r "</tr>"; next}
    /^[-*] /{if(!ul){print "<ul>";ul=1}; print "<li>" inl(substr($0,3)) "</li>"; next}
    /^[0-9]+\. /{if(!ul){print "<ul>";ul=1}; print "<li>" inl($0) "</li>"; next}
    /^$/{close_all(); next}
    {close_all(); print "<p>" inl($0) "</p>"}
    END{close_all(); if(pre)print "</pre>"}' "$1"
    echo "</body></html>"
}
md2html "$REPORT" >"${REPORT%.md}.html"

echo "[test-report] $ICON $DECISION"
echo "[test-report] 보고서: $REPORT"
[ "$OPEN" = true ] && open_file "${REPORT%.md}.html"
exit "$STATUS"
