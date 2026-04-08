# /review - AI Code Review

AI 기반 코드 리뷰를 실행합니다. 품질, 보안, 성능을 종합적으로 검토합니다.

## Usage

```bash
/review [options]
```

## Options

| Option | Description |
|--------|-------------|
| `--files <paths>` | 특정 파일만 리뷰 |
| `--since <ref>` | 특정 커밋 이후 변경사항 리뷰 |
| `--security` | 보안만 집중 검토 |
| `--performance` | 성능만 집중 검토 |
| `--strict` | 엄격 모드 |

## Review Categories

| 카테고리 | 체크 항목 |
|----------|-----------|
| **Security** | SQL Injection, XSS, 인증/권한, Secrets |
| **Performance** | N+1 쿼리, 메모리 누수, 비효율 루프 |
| **Code Quality** | SOLID,命名, 중복, 복잡도 |
| **Best Practices** | 에러 처리, 로깅, 테스트 |

## Examples

```bash
/review                   # 전체 리뷰
/review --since main      # main 이후 변경사항
/review --security        # 보안만 검토
/review --files src/auth.ts  # 특정 파일
```

## Output Format

```
🔍 Code Review Report

Files: 15 | Issues: 5 | Score: 85/100

🔴 Critical (1):
  src/auth.ts:45 - Potential SQL injection

⚠️ Warning (2):
  src/api.ts:123 - Missing error handling
  src/utils.ts:67 - High cyclomatic complexity

💡 Suggestions (2):
  Consider using async/await for readability
  Add JSDoc comments for public functions
```

## Related Commands

- `/pipeline` - PRD 기반 구현 후 자동 리뷰
- `/audit` - 보안 취약점 스캔
