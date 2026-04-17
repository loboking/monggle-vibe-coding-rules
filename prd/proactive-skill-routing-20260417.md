# PRD: Proactive Skill Routing System

## 메타데이터
- **타입**: feature
- **생성일**: 2026-04-17
- **우선순위**: P1
- **언어**: 한국어

---

## 1. 개요

### 1.1 배경
gstack의 proactive 기능과 skill routing 규칙을 참고하여, monggle-vibe-coding-rules 프로젝트에도 자동으로 적절한 스킬을 제안하고 실행하는 시스템을 구축합니다.

### 1.2 목표
- 사용자의 요청을 분석하여 자동으로 적절한 스킬을 제안/실행
- CLAUDE.md에 skill routing 규칙 추가
- 모든 워크플로우 속도 향상

---

## 2. 요구사항

### 2.1 Proactive Skill Detection

**Trigger 패턴:**
| 키워드/패턴 | 제안 스킬 | 예시 |
|-----------|---------|------|
| "작동하나요?", "테스트", "QA" | `/qa` | "이게 작동하나요?" |
| "버그", "오류", "고장", "왜 안돼" | `/debug-master` 또는 `/investigate` | "버그 있어" |
| "배포", "푸시", "커밋" | `/git-guardian` | "배포 해줘" |
| "문서", "README", "API 문서" | `/doc-writer` | "README 만들어줘" |
| "리뷰", "코드 리뷰" | `/code-reviewer` | "코드 리뷰 해줘" |
| "아키텍처", "설계" | `/architecture-designer` | "어떤 아키텍처가 좋을까?" |
| "기획서", "PRD" | `/monggle-planner` | "기획서 작성해줘" |
| "성능", "느려", "최적화" | `/bottleneck` 또는 `/profile` | "성능이 느려" |

### 2.2 CLAUDE.md Skill Routing Rules

```markdown
## Skill Routing

사용자의 요청이 아래 패턴과 일치하면, **반드시** Skill tool을 사용하여 해당 스킬을 먼저 실행합니다. 직접 답변하거나 다른 도구를 먼저 사용하지 마세요.

### Core Rules
- **QA/Testing**: "테스트", "QA", "작동하나요" → `/qa` 또는 `/qa-only`
- **Debugging**: "버그", "오류", "고장", "안돼" → `/debug-master` 또는 `/precision-debugger`
- **Git**: "커밋", "배포", "푸시" → `/git-guardian`
- **Documentation**: "문서", "README", "API 문서" → `/doc-writer` 또는 `/tech-doc-writer`
- **Review**: "리뷰", "코드 검토" → `/code-reviewer`, `/front-reviewer`, `/css-reviewer`
- **Architecture**: "아키텍처", "설계", "구조" → `/architecture-designer`
- **Planning**: "기획서", "PRD", "요구사항" → `/monggle-planner`
- **Performance**: "성능", "느려", "병목" → `/bottleneck`, `/profile`, `/bench`

### Proactive Behavior
사용자의 요청이 위 패턴과 부분적으로 일치하면:
1. "이 요청은 /{skill}로 처리할 수 있습니다. 실행할까요?"라고 제안
2. 사용자가 동의하면 해당 스킬 실행
3. 스킬이 완료된 후 결과를 사용자에게 보고
```

### 2.3 스킬 자동 추천 로직

```bash
# .claude/hooks/agent-pre-check (새로운 훅)
#!/bin/bash

# 사용자 메시지에서 키워드 추출
USER_MESSAGE="$1"

# 스킬 매핑
declare -A SKILL_MAP=(
  ["테스트"]="/qa"
  ["QA"]="/qa"
  ["버그"]="/debug-master"
  ["오류"]="/debug-master"
  ["배포"]="/git-guardian"
  ["커밋"]="/git-guardian"
  ["문서"]="/doc-writer"
  ["README"]="/doc-writer"
  ["리뷰"]="/code-reviewer"
  ["아키텍처"]="/architecture-designer"
  ["기획서"]="/monggle-planner"
  ["성능"]="/bottleneck"
)

# 키워드 매칭
for keyword in "${!SKILL_MAP[@]}"; do
  if [[ "$USER_MESSAGE" =~ "$keyword" ]]; then
    echo "RECOMMEND:${SKILL_MAP[$keyword]}"
    exit 0
  fi
done

echo "NONE"
```

---

## 3. 구현 방법

### 3.1 Phase 1: CLAUDE.md 업데이트
- [ ] Skill Routing 섹션 추가
- [ ] Proactive Behavior 가이드라인 추가
- [ ] 스킬 매핑 테이블 추가

### 3.2 Phase 2: Hook 스크립트 구현
- [ ] `.claude/hooks/agent-pre-check` 생성
- [ ] 키워드 매칭 로직 구현
- [ ] 스킬 추천 메시지 포맷

### 3.3 Phase 3: 통합 테스트
- [ ] 각 키워드 패턴 테스트
- [ ] 스킬 실행 자동화 확인
- [ ] Edge case 처리

---

## 4. 사용자 경험

### Before (현재)
```
사용자: "이거 테스트 필요할 것 같은데?"
Claude: "직접 테스트 코드를 작성하거나 /qa를 실행하세요."
```

### After (구현 후)
```
사용자: "이거 테스트 필요할 것 같은데?"
Claude: "이 요청은 /qa로 처리할 수 있습니다. 실행할까요?"
사용자: "응"
Claude: [/qa 실행 중...] → 테스트 완료
```

---

## 5. 성공 기준

- [ ] 사용자 요청의 80% 이상이 자동으로 스킬에 매핑
- [ ] 스킬 제안 응답 시간 < 2초
- [ ] False positive rate < 10%
- [ ] CLAUDE.md에 routing 규칙 문서화

---

## 6. Rollout Plan

1. **Week 1**: CLAUDE.md에 skill routing 규칙 추가
2. **Week 2**: Hook 스크립트 구현 및 테스트
3. **Week 3**: Beta 테스트 및 피드백 수집
4. **Week 4**: 공식 릴리스

---

## 7. 참고 자료

- gstack proactive 설정: `~/.claude/skills/gstack/bin/gstack-config set proactive true`
- gstack skill routing 예시: gstack SKILL.md "Skill Routing" 섹션
