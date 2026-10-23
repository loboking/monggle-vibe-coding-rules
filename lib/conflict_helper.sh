#!/bin/bash
# conflict_helper.sh - 충돌 해결 가이드 라이브러리
# Vibe Coding Rules v2.4 - Team Collaboration

# 색상 출력
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# 로그 함수
log_info() { echo -e "${BLUE}ℹ${NC} $*"; }
log_success() { echo -e "${GREEN}✅${NC} $*"; }
log_warn() { echo -e "${YELLOW}⚠️${NC} $*"; }
log_error() { echo -e "${RED}❌${NC} $*"; }

# 충돌 분석
analyze_conflict() {
    local file="$1"

    if [ ! -f "$file" ]; then
        log_error "파일을 찾을 수 없습니다: $file"
        return 1
    fi

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}🔍 충돌 분석: $file${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo

    # 충돌 마커 위치 확인
    local markers
    markers=$(get_conflict_markers "$file")

    if [ -z "$markers" ]; then
        log_info "충돌 마커가 없습니다."
        return 0
    fi

    # 충돌 라인 분석
    local line_count
    line_count=$(echo "$markers" | wc -l | tr -d ' ')

    echo -e "${BOLD}충돌 구간:${NC} $((line_count / 3))개"
    echo
    echo "$markers"
    echo

    # 원본 변경자 확인
    echo -e "${BOLD}원본 변경자:${NC}"
    if command -v git >/dev/null 2>&1; then
        git log --oneline -5 HEAD 2>/dev/null | sed 's/^/  /' || echo "  (확인 불가)"
    fi
    echo

    # 내 변경사항
    echo -e "${BOLD}내 변경사항:${NC}"
    git diff HEAD "$file" 2>/dev/null | head -20 | sed 's/^/  /' || echo "  (확인 불가)"
    echo

    # 충돌 유형 분류
    classify_conflict "$file"
}

# 충돌 유형 분류
classify_conflict() {
    local file="$1"

    echo -e "${BOLD}충돌 유형:${NC}"

    # 같은 줄 충돌
    if grep -q '^<<<<<<< ' "$file" && grep -q '^=======' "$file"; then
        local has_same_line=false

        # <<<<<<< 와 ======= 사이의 라인 수 확인
        local temp_file
        temp_file=$(mktemp) || return 1

        # trap으로 cleanup 보장
        trap "rm -f '$temp_file'" RETURN

        awk '/^<<<<<<</ {flag=1; next} /^=======/ {flag=0; next} flag {print}' "$file" > "$temp_file"
        local our_lines
        our_lines=$(wc -l < "$temp_file")

        # ======= 와 >>>>>>> 사이의 라인 수
        awk '/^=======/ {flag=1; next} /^>>>>>>>/ {flag=0; next} flag {print}' "$file" > "$temp_file"
        local their_lines
        their_lines=$(wc -l < "$temp_file")

        # trap 해제 (정상적으로 여기서 도달하면 cleanup됨)
        trap - RETURN

        if [ "$our_lines" -eq 1 ] && [ "$their_lines" -eq 1 ]; then
            echo -e "  ${RED}같은 줄 충돌${NC} - 같은 라인을 수정함"
            echo -e "  💡 해결: 비즈니스 로직 확인 후 하나 선택"
        elif [ "$our_lines" -lt 5 ] && [ "$their_lines" -lt 5 ]; then
            echo -e "  ${YELLOW}인접 줄 충돌${NC} - 근처 라인을 수정함"
            echo -e "  💡 해결: 둘 다 합치기 가능"
        else
            echo -e "  ${CYAN}함수/블록 충돌${NC} - 여러 라인 수정"
            echo -e "  💡 해결: 전체 로직 확인 필요"
        fi
    fi

    echo
}

# 충돌 파일 목록 표시
show_conflict_files() {
    local conflicts
    conflicts=$(get_conflict_files)

    if [ -z "$conflicts" ]; then
        log_info "충돌 파일이 없습니다."
        return 0
    fi

    echo -e "${BOLD}🔴 충돌 파일 목록:${NC}"
    echo

    local count=1
    while IFS= read -r file; do
        local markers
        markers=$(get_conflict_markers "$file" | wc -l | tr -d ' ')
        local sections=$((markers / 3))
        echo "  $count. $file ($sections구간)"
        ((count++))
    done <<< "$conflicts"
    echo
}

# 충돌 해결 가이드 표시
show_conflict_guide() {
    echo
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     💡 충돌 해결 가이드              ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    echo

    show_conflict_files

    echo -e "${BOLD}해결 방법:${NC}"
    echo
    echo "  1. ${CYAN}내 변경 유지${NC}"
    echo "     → git checkout --ours <file>"
    echo "     → git add <file>"
    echo "     → git rebase --continue"
    echo
    echo "  2. ${CYAN}원본 변경 유지${NC}"
    echo "     → git checkout --theirs <file>"
    echo "     → git add <file>"
    echo "     → git rebase --continue"
    echo
    echo "  3. ${CYAN}수동 병합${NC}"
    echo "     → 에디터로 <file> 열어서 <<<<<<< >>>>>>> 마커 제거"
    echo "     → git add <file>"
    echo "     → git rebase --continue"
    echo
    echo "  4. ${CYAN}중단${NC}"
    echo "     → git rebase --abort"
    echo

    echo -e "${BOLD}📖 관련 문서:${NC}"
    echo "  → .claude/docs/git-collaboration.md"
    echo
}

# 충돌 해결: 내 변경 유지
resolve_keep() {
    local file="$1"

    if [ ! -f "$file" ]; then
        log_error "파일을 찾을 수 없습니다: $file"
        return 1
    fi

    log_info "내 변경 유지: $file"

    # 백업
    cp "$file" "${file}.backup"

    # our 채택 (<<<<<<< 다음부터 ======= 전까지)
    local temp_file
    temp_file=$(mktemp)

    awk '
    /^<<<<<<</ { skip=1; next }
    /^=======/ { skip=0; next }
    /^>>>>>>>/ { next }
    !skip { print }
    ' "$file" > "$temp_file"

    mv "$temp_file" "$file"
    log_success "완료: 내 변경이 적용되었습니다"

    # git add 제안
    echo -e "${CYAN}→ 다음 명령어로 완료하세요:${NC}"
    echo "  git add $file"
    echo "  git rebase --continue"
}

# 충돌 해결: 원본 변경 유지
resolve_theirs() {
    local file="$1"

    if [ ! -f "$file" ]; then
        log_error "파일을 찾을 수 없습니다: $file"
        return 1
    fi

    log_info "원본 변경 유지: $file"

    # 백업
    cp "$file" "${file}.backup"

    # theirs 채택 (======= 다음부터 >>>>>>> 전까지)
    local temp_file
    temp_file=$(mktemp)

    awk '
    /^<<<<<<</ { skip=1; next }
    /^=======/ { skip=0; next }
    skip { next }
    /^>>>>>>>/ { next }
    { print }
    ' "$file" > "$temp_file"

    mv "$temp_file" "$file"
    log_success "완료: 원본 변경이 적용되었습니다"

    # git add 제안
    echo -e "${CYAN}→ 다음 명령어로 완료하세요:${NC}"
    echo "  git add $file"
    echo "  git rebase --continue"
}

# 충돌 해결: 병합 가이드
resolve_merge_guide() {
    local file="$1"

    if [ ! -f "$file" ]; then
        log_error "파일을 찾을 수 없습니다: $file"
        return 1
    fi

    echo
    echo -e "${BOLD}📝 수동 병합 가이드: $file${NC}"
    echo

    # 백업
    cp "$file" "${file}.backup"
    log_info "백업 생성: ${file}.backup"

    # 충돌 내용 표시
    echo -e "${BOLD}충돌 내용:${NC}"
    echo

    awk -v red="$RED" -v yellow="$YELLOW" -v green="$GREEN" -v nc="$NC" '
    /^<<<<<<</ {
        print "\n" red "━━─ 내 변경 (ours) ━━━" nc
        flag=1
        next
    }
    /^=======/ {
        print "\n" yellow "━━─ 원본 변경 (theirs) ━━━" nc
        flag=2
        next
    }
    /^>>>>>>>/ {
        print green "━━─ 끝 ━━━" nc "\n"
        flag=0
        next
    }
    flag==1 { print "  " $0 }
    flag==2 { print "  " $0 }
    ' "$file"

    echo
    echo -e "${BOLD}수동 병합 단계:${NC}"
    echo "  1. 에디터로 $file 열기"
    echo "  2. <<<<<<<, =======, >>>>>>> 마커 제거"
    echo "  3. 원하는 내용으로 병합"
    echo "  4. 저장 후 다음 명령어 실행:"
    echo
    echo -e "${CYAN}     git add $file${NC}"
    echo -e "${CYAN}     git rebase --continue${NC}"
    echo
}

# 모든 충돌 해결 (내 것 우선)
resolve_all_keep() {
    local conflicts
    conflicts=$(get_conflict_files)

    if [ -z "$conflicts" ]; then
        log_info "해결할 충돌이 없습니다."
        return 0
    fi

    log_warn "모든 충돌을 내 변경으로 해결합니다..."

    while IFS= read -r file; do
        resolve_keep "$file"
        git add "$file"
    done <<< "$conflicts"

    log_success "완료: git rebase --continue를 실행하세요"
}

# 모든 충돌 해결 (원본 우선)
resolve_all_theirs() {
    local conflicts
    conflicts=$(get_conflict_files)

    if [ -z "$conflicts" ]; then
        log_info "해결할 충돌이 없습니다."
        return 0
    fi

    log_warn "모든 충돌을 원본 변경으로 해결합니다..."

    while IFS= read -r file; do
        resolve_theirs "$file"
        git add "$file"
    done <<< "$conflicts"

    log_success "완료: git rebase --continue를 실행하세요"
}

# 내보내기 함수 목록
export -f analyze_conflict
export -f classify_conflict
export -f show_conflict_files
export -f show_conflict_guide
export -f resolve_keep
export -f resolve_theirs
export -f resolve_merge_guide
export -f resolve_all_keep
export -f resolve_all_theirs
export -f log_info
export -f log_success
export -f log_warn
export -f log_error
