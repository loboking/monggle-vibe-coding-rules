# /gate - PRD Gate

PRD의 품질과 완결성을 검증합니다.

## Usage

```bash
/gate [prd_file]
```

## Checks

| 항목 | 설명 |
|------|------|
| **필수 섹션** | 모든 필수 항목이 포함되어 있는지 확인 |
| **명확성** | 요구사항이 명확하고 모호하지 않은지 확인 |
| **검증 가능성** | 테스트 가능한 형태로 작성되었는지 확인 |
| **완결성** | 구현에 필요한 모든 정보가 있는지 확인 |

## Output

```
✅ PASS - PRD가 충분히 상세합니다
⚠️ FIX - 일부 항목 개선 필요
❌ FAIL - PRD를 처음부터 다시 작성해야 함
```

## Auto-Fix Suggestions

검증 실패 시 구체적인 수정 제안을 제공합니다:

```markdown
❌ 누락된 섹션:
- acceptance_criteria: 수락 기준 정의 필요

📝 수정 제안:
acceptance_criteria:
  - Given 사용자가 로그인 페이지에 접근
  - When 유효한 자격증명을 입력
  - Then 대시보드로 리다이렉트
```

## Related Commands

- `/prd` - PRD 생성
- `/pipeline` - 전체 파이프라인 실행 (Gate 포함)
