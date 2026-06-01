#!/bin/bash
#
# fix.sh - monggle: Impact-aware Code Fix
#
# 영향도 분석을 동반한 안전한 수정 스킬.
# review(읽기 전용)와 분리된, 실제 코드를 수정하는 스킬이다.
#
# 3단계 흐름:
#   ① 영향분석  - impact.sh 호출로 엮인 코드(호출처/의존성) + 위험도 파악
#   ② 수정      - 영향 범위를 인지한 상태에서 변경 수행
#   ③ 회귀점검  - 수정 후 영향 받는 곳의 회귀 위험 검증
#
# Usage:
#   /fix <file>            # 특정 파일 수정 (영향분석 포함)
#   /fix <pattern>         # 패턴 매칭 파일
#   /fix                   # 현재 변경 중인 파일 대상
#

set -euo pipefail

# 자기 디렉토리를 전용 변수에 저장 (wrapper가 SCRIPT_DIR을 덮어쓰므로 분리)
FIX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 하네스 래퍼 로드 (자동 추적) — 주의: 이 source가 SCRIPT_DIR을 재정의함
source "${FIX_DIR}/../brain/skill-harness-wrapper.sh" 2>/dev/null || true

# 스킬 종료 시 자동 기록 (trap)
trap 'harness_skill_end $?' EXIT

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

IMPACT_SH="${FIX_DIR}/impact.sh"

# ============================================================================
# STEP 1: Impact Analysis (영향분석)
# ============================================================================
run_impact() {
    local target="$1"

    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}${BOLD}🔧 /fix — STEP 1/3: Impact Analysis (수정 전 영향분석)${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    if [[ -x "$IMPACT_SH" ]]; then
        # impact.sh 실제 호출: 엮인 코드(의존성) + 위험도 산출
        bash "$IMPACT_SH" $target || true
    elif [[ -f "$IMPACT_SH" ]]; then
        bash "$IMPACT_SH" $target || true
    else
        echo -e "${YELLOW}⚠️ impact.sh 없음 — 영향분석을 Claude가 직접 수행해야 함${NC}"
    fi
}

# ============================================================================
# Main
# ============================================================================
main() {
    harness_skill_start "$@"

    local target="${1:-}"

    # STEP 1: 영향분석 (impact.sh 실제 실행)
    run_impact "$target"

    # STEP 2 & 3: Claude에게 수정 + 회귀점검 지시
    cat <<'EOF'

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔧 /fix — Modification Request (영향도 인지 수정)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

위 STEP 1 Impact Analysis 결과(엮인 코드 / 위험도)를 반드시 반영하여
아래 3단계 원칙대로 수정을 진행하라:

### STEP 2 — 수정 (Modify with awareness)
- Impact Analysis에 나온 **dependent files(엮인 코드)를 먼저 확인**한 뒤 수정한다.
- 변경은 최소한으로(diff-only). 요청 범위를 벗어난 수정 금지.
- HIGH-risk로 분류된 파일은 시그니처/인터페이스/계약(contract) 변경에 특히 주의.

### STEP 3 — 회귀 점검 (Regression check, 수정 후)
수정을 마친 뒤 반드시 아래를 점검하고 보고하라:
1. **영향 받는 호출처 점검**: STEP 1의 dependent 파일들이 이번 변경으로 깨지지 않는가?
   - 변경된 함수/타입/시그니처를 사용하는 곳을 직접 확인.
2. **회귀 위험 목록화**: 이번 수정으로 새로 발생 가능한 이슈를 [HIGH/MEDIUM/LOW]로 나열.
3. **검증 방법 제시**: 어떤 테스트/실행으로 회귀가 없음을 확인할 수 있는지 명시.
   - 가능하면 관련 테스트를 실제로 돌리거나, 없으면 추가를 제안.

### 출력 형식
1. **수정 요약** - 무엇을 왜 바꿨는지 (변경 파일:라인)
2. **엮인 코드 확인 결과** - dependent 중 영향받는 것 / 안전한 것
3. **회귀 위험** - [HIGH/MEDIUM/LOW] 목록 (없으면 "없음"으로 명시)
4. **검증 방법** - 테스트 실행 결과 또는 권장 검증 절차

⚠️ 영향분석/회귀점검을 생략한 '단순 수정'은 금지. 반드시 전후 영향을 함께 보고하라.

EOF
}

main "$@"
