#!/bin/bash
#
# prd-gate.sh — PreToolUse(Write|Edit) 차단형 PRD 게이트.
#
# team 모드에서 "PRD is REQUIRED" 약속을 실제로 강제한다.
#   - solo 모드 → 항상 통과 (기존 동작 유지)
#   - team 모드 + 코드 파일 Write/Edit + 유효 PRD 없음 → exit 2 (차단)
#
# Claude Code PreToolUse 규약:
#   - stdin: {"tool_name","tool_input":{"file_path",...},...}
#   - exit 0 → 허용 / exit 2 → 차단(메시지는 stderr)
#
# 안전장치 (잘못 막는 것 방지):
#   - 우회: BRAIN_PRD_GATE=off, 또는 /quick 핫픽스 트리거 파일 존재 시 통과
#   - 예외 경로: prd/·docs·.md 문서·.claude/(설정/훅/스킬)·README·CHANGELOG 등은 통과
#   - config·PRD 판정 실패 시 통과(fail-open) — 게이트가 작업을 깨선 안 된다.

set -uo pipefail

# --- 입력 ---
INPUT="$(cat 2>/dev/null || echo '{}')"

# 우회 스위치
[[ "${BRAIN_PRD_GATE:-on}" == "off" ]] && exit 0

# --- 프로젝트 루트 찾기 (cwd 기준 상위로 monggle.config.yaml 탐색) ---
find_root() {
    local d="${CLAUDE_PROJECT_DIR:-$PWD}"
    while [[ "$d" != "/" ]]; do
        [[ -f "$d/monggle.config.yaml" ]] && { echo "$d"; return 0; }
        d="$(dirname "$d")"
    done
    return 1
}
ROOT="$(find_root)" || exit 0          # config 없으면 이 프로젝트 관할 아님 → 통과
CONFIG="$ROOT/monggle.config.yaml"

# --- 모드 확인 ---
MODE="$(grep "^mode:" "$CONFIG" 2>/dev/null | awk '{print $2}' | tr -d '"')"
[[ "$MODE" != "team" ]] && exit 0      # solo/미설정 → 통과

# --- /quick 핫픽스 우회 ---
[[ -f "$ROOT/.claude/.quick-hotfix" ]] && exit 0

# --- 대상 파일 경로 추출 (jq 있으면 정확, 없으면 grep) ---
if command -v jq &>/dev/null; then
    FP="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null)"
else
    FP="$(printf '%s' "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"//;s/"$//')"
fi
[[ -z "$FP" ]] && exit 0               # 경로 모르면 통과

# --- 예외 경로 (PRD 없이도 허용되는 파일) ---
case "$FP" in
    */prd/*|*/docs/*|*/.claude/*|*.md|*/README*|*/CHANGELOG*|*/LICENSE*|*.txt|*.json|*.yaml|*.yml|*.conf)
        exit 0 ;;
esac

# --- 유효 PRD 존재 확인 ---
PRD_DIR="$ROOT/prd"
HAS_PRD=0
if [[ -d "$PRD_DIR" ]]; then
    # 최소 1개의 .md PRD가 있고, 'Requirements' 또는 '요구사항' 섹션을 포함하면 유효로 본다.
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        if grep -qiE "requirement|요구사항|acceptance|수용 ?기준|## .*목표|## goal" "$f" 2>/dev/null; then
            HAS_PRD=1; break
        fi
    done < <(find "$PRD_DIR" -maxdepth 1 -name "*.md" -type f 2>/dev/null)
fi
[[ "$HAS_PRD" == "1" ]] && exit 0       # 유효 PRD 있음 → 통과

# --- 여기 오면: team 모드 + 코드파일 + 유효 PRD 없음 → 차단 ---
cat >&2 <<MSG
🚫 [PRD Gate] team 모드에서는 PRD 없이 코드 작업을 진행할 수 없습니다.

  대상 파일: $FP
  현재 모드: team (PRD 필수)

  ▸ 해결: /prd 로 요구사항을 먼저 작성하세요.
  ▸ 긴급 핫픽스: /quick (게이트 우회) 또는 touch .claude/.quick-hotfix
  ▸ 이번만 끄기: BRAIN_PRD_GATE=off 환경변수
  ▸ solo로 전환: /mode solo
MSG
exit 2
