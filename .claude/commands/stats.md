# /stats - Pipeline Statistics

파이프라인 실행 통계와 기록을 확인합니다.

## Usage

```bash
/stats [options]
```

## Options

| Option | Description |
|--------|-------------|
| `--verbose` | 상세 통계 + 시각화 |
| `--web` | 웹 대시보드 생성 |
| `--json` | JSON 출력 |
| `--filter-verdict` | Verdict 필터 (PASS/FIX/FAIL) |
| `--filter-type` | PRD 타입 필터 |
| `--since <date>` | 날짜 이후 기록만 |

## Examples

```bash
/stats                   # 기본 통계
/stats --verbose         # 상세 통계 + 시각화
/stats --web             # 웹 대시보드
/stats --json            # JSON 출력
/stats --filter-verdict PASS
/stats --since 2024-01-01
```

## Output Examples

### Basic Stats

```
📊 Pipeline Statistics

Total Runs: 42
Success Rate: 85.7%
Average Duration: 3m 24s

Verdict Distribution:
  PASS:  36 (85.7%)
  FIX:   5 (11.9%)
  FAIL:  1 (2.4%)
```

### Verbose Stats

```
📊 Pipeline Statistics (Verbose)

Total Runs: 42
Success Rate: 85.7%
Average Duration: 3m 24s

Verdict Distribution:
  PASS  ████████████████████ 36 (85.7%)
  FIX   ████                 5 (11.9%)
  FAIL  ▌                    1 (2.4%)

Recent History:
  [2026-04-08 14:30] PASS - feature-auth
  [2026-04-08 13:15] PASS - bug-login-fix
  [2026-04-08 11:00] FIX  - refactor-api
```

## Related Commands

- `/pipeline` - 파이프라인 실행
- `/trace` - 파이프라인 기록 확인
