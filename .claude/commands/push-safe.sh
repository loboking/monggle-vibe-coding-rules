#!/bin/bash
# .claude/commands/push-safe.sh
# push-safe.sh - monggle: Safe push with safety checks

set -e

# 라이브러리 로드
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"

source "$LIB_DIR/git_helper.sh"
source "$LIB_DIR/pr_helper.sh"

# 설정 로드
CONFIG_DIR="$(dirname "$SCRIPT_DIR")/config"
PROJECT_ROOT="$(cd "$(dirname "$SCRIPT_DIR")/.." && pwd)"
if [ -f "$CONFIG_DIR/git.conf" ]; then
    source "$CONFIG_DIR/git.conf"
fi

# YAML 값 읽기 헬퍼: yq 있으면 yq, 없으면 들여쓰기 무시 grep 폴백
# 사용법: yaml_get <file> <key> <yq_path>
yaml_get() {
    local file="$1" key="$2" yq_path="$3"
    [ -f "$file" ] || return 0
    if command -v yq >/dev/null 2>&1; then
        local v
        v=$(yq -r "$yq_path" "$file" 2>/dev/null)
        [ "$v" = "null" ] && v=""
        printf '%s' "$v"
    else
        # 들여쓰기 포함 가능: 선행 공백 허용, 첫 매칭만, 따옴표 제거
        grep -E "^[[:space:]]*${key}:" "$file" 2>/dev/null \
            | head -1 \
            | sed -E "s/^[[:space:]]*${key}:[[:space:]]*//; s/^[\"']//; s/[\"']$//; s/[[:space:]]*#.*$//"
    fi
}

# 팀 작업 모드(solo/team)는 mode.sh가 monggle.config.yaml(col0 mode:)에 기록함
# create_pr 키는 선택 사항 (없으면 기본: PR 생성 허용)
MONGGLE_CONFIG="$PROJECT_ROOT/monggle.config.yaml"
TEAM_MODE=$(yaml_get "$MONGGLE_CONFIG" "mode" ".mode")
CREATE_PR=$(yaml_get "$MONGGLE_CONFIG" "create_pr" ".create_pr")

# 사용법
show_usage() {
    cat << EOF
Usage: push-safe [options]

원격 저장소에 안전하게 코드를 전송합니다.

Options:
  --no-pr      PR 생성 건너뛰기
  --branch     특정 브랜치에 전송
  --dry-run    실행 계획만 표시
  -h, --help   이 도움말 표시

Examples:
  push-safe           # 안전하게 push (Team 모드 시 PR 생성)
  push-safe --no-pr   # PR 생성 없이 push
  push-safe --dry-run # 계획만 확인
EOF
}

# 변수
NO_PR=false
DRY_RUN=false
TARGET_BRANCH=""

# 인자 파싱
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-pr)
            NO_PR=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --branch)
            TARGET_BRANCH="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            log_error "알 수 없는 옵션: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Git 저장소 확인
if ! is_git_repo; then
    log_error "Git 저장소가 아닙니다."
    exit 1
fi

# 현재 브랜치
CURRENT_BRANCH=$(get_current_branch)
if [ -z "$CURRENT_BRANCH" ]; then
    log_error "현재 브랜치를 확인할 수 없습니다."
    exit 1
fi

# 전송할 브랜치 결정
PUSH_BRANCH="${TARGET_BRANCH:-$CURRENT_BRANCH}"

log_info "현재 브랜치: $CURRENT_BRANCH"
log_info "전송 대상: $PUSH_BRANCH"

# 1. 원본 상태 확인
log_info "원본 상태 확인 중..."
# dry-run 에서는 원격 접근 실패가 계획 확인을 막지 않도록 가드
if [ "$DRY_RUN" = true ]; then
    git fetch origin 2>/dev/null || log_warn "[DRY-RUN] git fetch 실패(원격 미설정 가능) - 계획만 계속"
else
    git fetch origin
fi

# 2. 뒤처짐 감지
if is_behind_origin; then
    log_warn "로컬이 원본보다 뒤처져 있습니다."
    log_info "먼저 /update를 실행하세요."

    # 자동 update 시도
    if [ "$DRY_RUN" = false ]; then
        read -p "지금 /update를 실행하시겠습니까? (Y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]] || [ -z $REPLY ]; then
            log_info "/update 실행 중..."
            "$SCRIPT_DIR/update.sh" --auto || {
                log_error "/update 실패. push를 중단합니다."
                exit 1
            }
            # 다시 확인
            git fetch origin
            if is_behind_origin; then
                log_error "여전히 뒤처져 있습니다. 수동으로 해결하세요."
                exit 1
            fi
        else
            log_info "취소되었습니다."
            exit 0
        fi
    else
        log_info "[DRY-RUN] /update 필요"
        exit 0
    fi
fi

# 3. 앞서간 커밋 확인
AHEAD_COUNT=$(is_ahead_origin)
if [ -z "$AHEAD_COUNT" ]; then
    log_info "전송할 커밋이 없습니다."
    exit 0
fi

log_success "로컬에 ${AHEAD_COUNT}개의 커밋이 있습니다."

# 커밋 메시지 표시
log_info "전송할 커밋:"
git log --oneline "@{u}.." | head -5 | sed 's/^/  /'

# 4. Team 모드 확인
if [ "$TEAM_MODE" = "team" ] && [ "$NO_PR" = false ] && [ "$CREATE_PR" != "false" ]; then
    # main/master 브랜치가 아니면 PR 생성
    if [ "$CURRENT_BRANCH" != "main" ] && [ "$CURRENT_BRANCH" != "master" ]; then
        log_info "Team 모드: PR 생성을 진행합니다."

        if [ "$DRY_RUN" = true ]; then
            log_info "[DRY-RUN] PR 생성 예정"
            exit 0
        fi

        # 먼저 push
        log_info "먼저 브랜치를 전송합니다..."
        git push -u origin "$PUSH_BRANCH" || {
            log_error "Push 실패"
            exit 1
        }

        # PR 생성
        log_info "PR 생성 중..."
        if create_pr "Update from $CURRENT_BRANCH" "" "$CURRENT_BRANCH" "main"; then
            log_success "완료!"
        else
            log_warn "PR 생성 실패. 코드는 이미 전송되었습니다."
            log_info "수동으로 PR을 생성하세요."
        fi
        exit 0
    fi
fi

# 5. 일반 push
if [ "$DRY_RUN" = true ]; then
    log_info "[DRY-RUN] git push origin $PUSH_BRANCH 실행 예정"
    exit 0
fi

log_info "전송 시작..."
if git push origin "$PUSH_BRANCH"; then
    log_success "전송 완료!"
else
    log_error "전송 실패"
    exit 1
fi
