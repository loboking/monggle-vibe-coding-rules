# Vibe Coding Rules

> 이 프로젝트는 Vibe Coding 방법론을 따릅니다.

## 핵심 원칙

1. **PRD 먼저** - 코딩 전에 반드시 PRD 확인/작성
2. **AI가 검증** - 리뷰/검증/판단은 AI가 담당
3. **개발자는 집중** - 구현과 창의성에만 집중
4. **자유로운 실험** - 개인 브랜치에서 마음껏

## 코딩 규칙

### 커밋 메시지
```
type(scope): description

Types: feat, fix, refactor, test, docs, chore
```

### 브랜치 규칙
- 개인 작업: `dev/{user}/{feature}`
- main 직접 Push 금지
- 모든 변경은 PR 통해서만

### PR 규칙
- PRD 링크 필수
- PR당 하나의 기능/수정
- CI 통과 후 머지

### PR 템플릿
```markdown
## 설명
PR의 목적과 변경 사항 요약

## PRD 링크
#PRD_ISSUE

## 변경 사항
- 주요 변경점 1
- 주요 변경점 2

## 테스트
- [ ] 단위 테스트 통과
- [ ] 통합 테스트 통과
- [ ] 수동 테스트 완료

## 체크리스트
- [ ] PRD와 일치
- [ ] 테스트 추가됨
- [ ] 문서 업데이트됨
```

## 테스트 요구사항

| 단계 | 테스트 | 차단 여부 |
|------|--------|----------|
| 개인 브랜치 | TDD, Lint | No |
| PR | Feature, Scenario | Yes |
| Main Merge | Full, Integration | Yes |

## 금지 사항

- ❌ main 직접 Push
- ❌ PRD 없이 기능 개발
- ❌ 테스트 없이 PR 생성
- ❌ CI 실패 상태로 머지

## 코드 스타일

### Python
- PEP 8 준수
- 타입 힌트 사용 권장
- Docstring 포함 (Google Style)

### JavaScript/TypeScript
- ESLint + Prettier 사용
- TypeScript strict mode
- JSDoc 주석 포함

## 최종 선언

> "버그 없는 시스템이 아닌, 실패를 통제하고 반복하지 않는 시스템을 만든다."
