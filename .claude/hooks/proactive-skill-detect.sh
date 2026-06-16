#!/bin/bash
# Proactive Skill Detection Hook
# 사용자 입력에서 스킬 트리거를 자동 감지
#
# NOTE: macOS 기본 bash 3.2 는 associative array(declare -A)를 지원하지 않으므로
# case 기반 부분 일치로 구현한다. 위에서 아래로 첫 매칭이 우선.

USER_INPUT="$1"

detect_skill() {
    case "$USER_INPUT" in
        # QA/Testing
        *작동해*|*테스트*|*QA*|*검사*)            echo "qa" ;;
        # Bug/Debug
        *버그*|*오류*|*안돼*|*고장*|*"안 작동"*)   echo "debug-master" ;;
        # Git/Deploy
        *배포*|*커밋*|*푸시*|*올려*)               echo "git-guardian" ;;
        # Documentation
        *README*|*문서*|*작성해줘*)                echo "tech-doc-writer" ;;
        # Review
        *리뷰*|*검토*)                             echo "code-reviewer" ;;
        # Architecture
        *아키텍처*|*설계*)                         echo "architecture-designer" ;;
        # Planning
        *기획서*|*PRD*)                            echo "product-manager" ;;
        # Performance
        *느려*|*최적화*|*병목*|*성능*)             echo "bottleneck" ;;
        *)                                          echo "" ;;
    esac
}

detected_skill="$(detect_skill)"

if [ -n "$detected_skill" ]; then
    echo "AUTO_SKILL:$detected_skill"
else
    echo "NONE"
fi
