#!/bin/bash
#
# fix-skills.sh - 스킬 메타데이터 생성 및 복구
#

set -eo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

COMMANDS_DIR="$HOME/.claude/commands"
SKILLS_DIR="$HOME/.claude/skills"

echo -e "${CYAN}${BOLD}═════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}${BOLD}  Vibe Coding Skills - Metadata Fix${NC}"
echo -e "${CYAN}${BOLD}═════════════════════════════════════════════════════${NC}"
echo ""

# 스킬 정의 배열
SKILLS=(
    "debug|체계적 버그 분석"
    "debug-perf|성능 병목 찾기"
    "debug-web|프론트엔드 디버깅"
    "debug-css|CSS 디버깅"
    "debug-m|메모리 누수 탐지"
    "qa|Smart QA testing"
    "qa-only|QA 보고서만"
    "investigate|시스템적 디버깅"
    "bottleneck|성능 병목 탐지"
    "front-bugfix|프론트엔드 버그 수정"
    "css-bugfix|CSS 버그 수정"
    "mem-check|메모리 체크"
    "review|코드 리뷰"
    "review-code|코드 품질 리뷰"
    "review-arch|아키텍처 리뷰"
    "code-reviewer|코드 리뷰어"
    "arch-review|아키텍처 리뷰어"
    "prd|PRD 작성기"
    "brainstorm|브레인스토밍"
    "idea|아이디어 수집기"
    "gate|PRD 게이트"
    "pipeline|에이전트 파이프라인"
    "stats|통계"
    "trace|파이프라인 추적"
    "mode|작업 모드"
    "changelog|Changelog 생성"
    "bump|버전 업"
    "push-safe|안전한 푸시"
    "format-check|포맷 체크"
    "lint-smart|스마트 린터"
    "complexity|복잡도 분석"
    "bench|벤치마크"
    "api-docs|API 문서"
    "profile|프로파일링"
    "audit|보안 감사"
    "save-point|저장 포인트"
    "quick|빠른 핫픽스"
    "init|초기화"
    "weekly-recap|주간 회고"
    "compact|컨텍스트 컴팩트"
    "pattern|패턴 계약"
    "monggle|Monggle 툴킷"
)

# 스킬 디렉토리 생성 및 skill.json 생성
create_skill_metadata() {
    local skill_name="$1"
    local description="$2"
    local skill_dir="$SKILLS_DIR/$skill_name"
    
    mkdir -p "$skill_dir"
    
    # skill.json 생성
    cat > "$skill_dir/skill.json" << SKILL_EOF
{
  "name": "$skill_name",
  "description": "$description",
  "version": "1.0.0"
}
SKILL_EOF
    
    # skill.md도 생성
    cat > "$skill_dir/skill.md" << SKILL_MD_EOF
# $skill_name

$description
SKILL_MD_EOF
    
    echo -e "${GREEN}[✓]${NC} Created metadata for ${CYAN}$skill_name${NC}"
}

# 메인 스킬들 처리
echo -e "${BLUE}[→]${NC} Creating metadata for core skills..."
echo ""

for skill_info in "${SKILLS[@]}"; do
    IFS='|' read -r skill_name description <<< "$skill_info"
    create_skill_metadata "$skill_name" "$description"
done

echo ""
echo -e "${BLUE}[→]${NC} Scanning for additional skills from .sh files..."

# .sh 파일이 있는데 메타데이터가 없는 스킬도 처리
for script in "$COMMANDS_DIR"/*.sh; do
    if [ -f "$script" ]; then
        skill_name=$(basename "$script" .sh)
        # 이미 처리됐으면 건너뜀
        if [ ! -f "$SKILLS_DIR/$skill_name/skill.json" ]; then
            # monggle- 접두사 제거
            clean_name="${skill_name#monggle-}"
            create_skill_metadata "$clean_name" "Monggle $clean_name skill"
        fi
    fi
done

echo ""
echo -e "${GREEN}${BOLD}═════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  Skill metadata creation complete!${NC}"
echo -e "${GREEN}${BOLD}═════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${CYAN}Total skills processed:$(ls -d "$SKILLS_DIR"/*/ 2>/dev/null | wc -l | tr -d ' ')${NC}"
echo ""
echo -e "${CYAN}Next steps:${NC}"
echo "  1. ${YELLOW}Restart Claude Code${NC}"
echo "  2. Check available skills with /help or in the skills panel"
