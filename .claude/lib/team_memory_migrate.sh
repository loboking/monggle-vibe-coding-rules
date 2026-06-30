#!/usr/bin/env bash
# team_memory_migrate — 팀원 누적 memory를 백업/복원한다.
# memory는 repo에 안 올라가므로(개인정보·타 프로젝트 기억 포함), 머신을 옮길 때
# 이 스크립트로 직접 가져간다. persona·skills·등록파일은 repo가 관리하므로 제외.
#
# 사용:
#   team_memory_migrate.sh backup [dest.tar.gz]   # 현재 머신의 팀 memory를 묶음
#   team_memory_migrate.sh restore <src.tar.gz>   # 다른 머신에서 풀어 복원(기존과 병합)
set -euo pipefail

TEAM_DIR="$HOME/.claude/agents-team"
ACTION="${1:-help}"

backup() {
    local dest="${1:-team-memory-$(date +%Y%m%d 2>/dev/null || echo backup).tar.gz}"
    # memory 디렉토리만 추출 (persona/skills 제외)
    if [ ! -d "$TEAM_DIR" ]; then
        echo "❌ $TEAM_DIR 없음 — 팀이 설치되지 않았다" >&2; exit 1
    fi
    local mems
    mems=$(cd "$TEAM_DIR" && find . -type d -name memory 2>/dev/null)
    if [ -z "$mems" ]; then
        echo "ℹ️ 백업할 memory 없음(아직 비어있음)"; exit 0
    fi
    tar -czf "$dest" -C "$TEAM_DIR" $(cd "$TEAM_DIR" && find . -path '*/memory/*' -type f 2>/dev/null)
    echo "✓ 팀 memory 백업: $dest"
    echo "  포함: $(echo "$mems" | wc -l | tr -d ' ')개 팀원의 memory"
}

restore() {
    local src="${1:?복원할 tar.gz 경로가 필요하다}"
    [ -f "$src" ] || { echo "❌ $src 없음" >&2; exit 1; }
    mkdir -p "$TEAM_DIR"
    # 기존 memory와 병합(덮어쓰기) — 같은 파일은 src 우선
    tar -xzf "$src" -C "$TEAM_DIR"
    echo "✓ 팀 memory 복원: $src → $TEAM_DIR"
    echo "  (기존 파일은 백업본으로 덮어씀. persona·skills는 건드리지 않음)"
}

case "$ACTION" in
    backup)  backup "${2:-}";;
    restore) restore "${2:-}";;
    *)
        cat <<EOF
team_memory_migrate — 팀원 누적 memory 백업/복원

  backup [dest.tar.gz]   현재 머신의 팀 memory를 묶는다
  restore <src.tar.gz>   다른 머신에서 복원(persona·skills는 repo가 관리하므로 제외)

memory는 개인정보·타 프로젝트 기억을 포함할 수 있어 repo에 올리지 않는다.
머신 이전 시 이 백업본을 직접 가져가서 restore 하면 기억이 이어진다.
EOF
        ;;
esac
