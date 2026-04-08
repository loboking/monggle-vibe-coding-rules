# /quick - Quick Hotfix

긴급 핫픽스를 위한 빠른 실행 모드입니다. Gate와 Fold 단계를 건너뜁니다.

## Usage

```bash
/quick [prd_file]
```

## Pipeline Difference

**Full Pipeline:**
```
Gate → Scan → Fold → Verdict → Patch → Trace
```

**Quick Mode:**
```
Scan → Patch → Trace
```

## When to Use

- ✅ 긴급 버그 수정 (Production issue)
- ✅ 간단한 수정 (1-2 파일)
- ✅ 명확한 원인 (디버깅 완료)

## When NOT to Use

- ❌ 새로운 기능 개발
- ❌ 복잡한 리팩토링
- ❌ 요구사항이 불명확할 때

## Examples

```bash
/quick                    # 빠른 수정 (대화형)
/quick prd/hotfix.md      # PRD 파일 지정
```

## Related Commands

- `/prd hotfix` - 핫픽스 PRD 생성
- `/pipeline` - 전체 파이프라인 실행
