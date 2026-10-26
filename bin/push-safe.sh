#!/bin/bash
# push-safe.sh - 받기 → (뒤처지면) rebase → 보낼 커밋 비밀값 검사 → push → (팀 모드) PR
# force push 는 하지 않는다. 테스트용 가짜 값은 그 줄에 "pragma: allowlist secret" 을 붙인다.
set -euo pipefail

show_usage() {
    cat <<'EOF'
Usage: push-safe [options]

  --no-pr          PR 생성 건너뛰기 (팀 모드에서도)
  --branch <name>  보낼 브랜치 (기본: 현재 브랜치)
  --dry-run        계획만 표시, 아무것도 바꾸지 않음
  -h, --help       도움말
EOF
}

info() { echo "[push-safe] $*"; }
die()  { echo "[push-safe] STOP: $*" >&2; exit 1; }

NO_PR=false DRY_RUN=false BRANCH=""
while [ $# -gt 0 ]; do
    case "$1" in
        --no-pr) NO_PR=true ;;
        --dry-run) DRY_RUN=true ;;
        --branch) BRANCH="${2:?--branch 에 브랜치 이름이 필요합니다}"; shift ;;
        -h|--help) show_usage; exit 0 ;;
        *) show_usage >&2; die "알 수 없는 옵션: $1" ;;
    esac
    shift
done

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "Git 저장소가 아닙니다."
ROOT="$(git rev-parse --show-toplevel)"
CURRENT="$(git symbolic-ref --short -q HEAD)" || die "브랜치가 아닌 상태(detached HEAD)입니다."
BRANCH="${BRANCH:-$CURRENT}"
MODE="$(sed -n 's/^mode:[[:space:]]*["'\'']\{0,1\}\([a-z]*\).*/\1/p' "$ROOT/monggle.config.yaml" 2>/dev/null | head -1 || true)"
info "브랜치: $BRANCH (모드: ${MODE:-solo})"

# 1. 받기 + 뒤처짐 처리
UPSTREAM="origin/$BRANCH"
if git fetch -q origin 2>/dev/null && git rev-parse -q --verify "$UPSTREAM" >/dev/null; then
    BEHIND="$(git rev-list --count "HEAD..$UPSTREAM")"
    if [ "$BEHIND" -gt 0 ]; then
        info "원격보다 ${BEHIND}개 뒤처짐 → rebase 로 맞춘다"
        if [ "$DRY_RUN" = true ]; then
            info "[DRY-RUN] git pull --rebase --autostash origin $BRANCH"
        elif ! git pull -q --rebase --autostash origin "$BRANCH"; then
            die "충돌. 'git status' 로 충돌 파일을 보고 해결한 뒤 'git rebase --continue' (취소: 'git rebase --abort'). push 하지 않았습니다."
        fi
    fi
    RANGE="$UPSTREAM..HEAD"
else
    git remote get-url origin >/dev/null 2>&1 || die "origin 원격이 없습니다."
    info "원격에 $BRANCH 가 아직 없음 → 새 브랜치로 보낸다"
    RANGE="HEAD"
    git rev-parse -q --verify "origin/HEAD" >/dev/null && RANGE="origin/HEAD..HEAD"
fi

COUNT="$(git rev-list --count $RANGE)"
[ "$COUNT" -gt 0 ] || { info "보낼 커밋이 없습니다."; exit 0; }
info "보낼 커밋 ${COUNT}개:"
git log --oneline $RANGE | head -10 | sed 's/^/  /'

# 2. 비밀값 검사 (보낼 커밋 전체)
SECRET_FILES='\.(env|pem|key|p12|keystore)$'
SECRET_LINES='(API[_-]?KEY|SECRET[_-]?KEY|password|passwd|token)["'\'']?[[:space:]]*[:=][[:space:]]*["'\'']?[^[:space:]"'\'']{6,}|sk_live_[A-Za-z0-9]+|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|GOCSPX-[A-Za-z0-9_-]+|-----BEGIN [A-Z ]*PRIVATE KEY-----'
BAD_FILES="$(git diff --name-only --diff-filter=AM $RANGE -- | grep -E "$SECRET_FILES" || true)"
BAD_LINES="$(git diff $RANGE -- | grep -E '^\+[^+]' | grep -vi 'pragma: allowlist secret' | grep -E "$SECRET_LINES" | cut -c1-160 || true)"
if [ -n "$BAD_FILES$BAD_LINES" ]; then
    [ -n "$BAD_FILES" ] && echo "비밀 파일:" >&2 && echo "$BAD_FILES" | sed 's/^/  /' >&2
    [ -n "$BAD_LINES" ] && echo "의심 줄:" >&2 && echo "$BAD_LINES" | sed 's/^/  /' >&2
    die "비밀값 의심. 커밋에서 빼고(git reset/rebase) .gitignore 에 추가하세요. 테스트용 가짜 값이면 그 줄에 'pragma: allowlist secret'."
fi
info "비밀값 검사 통과"

# 3. push (force 금지)
if [ "$DRY_RUN" = true ]; then
    info "[DRY-RUN] git push -u origin HEAD:$BRANCH"
else
    git push -q -u origin "HEAD:$BRANCH" || die "push 실패"
    info "push 완료"
fi

# 4. 팀 모드 + main 이 아닌 브랜치 → PR
if [ "$MODE" = team ] && [ "$NO_PR" = false ] && [ "$BRANCH" != main ] && [ "$BRANCH" != master ]; then
    if [ "$DRY_RUN" = true ]; then
        info "[DRY-RUN] gh pr create --fill --head $BRANCH"
    elif command -v gh >/dev/null 2>&1; then
        gh pr view "$BRANCH" >/dev/null 2>&1 && info "PR 이 이미 있습니다." \
            || gh pr create --fill --head "$BRANCH" || info "PR 생성 실패. 코드는 이미 보냈습니다. 직접 만드세요."
    else
        info "gh 가 없어 PR 은 직접 만드세요 (브랜치: $BRANCH)."
    fi
fi
