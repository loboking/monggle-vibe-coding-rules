---
name: stats
description: Statistics - Show pipeline stats and project metrics. "/stats" 등에서 동작한다.
allowed-tools: Bash, Read, Grep, Glob, Edit, Write
---

# stats

Statistics - Show pipeline stats and project metrics

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

## 실행

절차는 셸 스크립트에 있다. 저장소 안에 있으면 그걸, 없으면 설치된 것을 쓴다.

```bash
SCRIPT=bin/stats.sh
[ -f "$SCRIPT" ] || SCRIPT="$HOME/.monggle/bin/stats.sh"
bash "$SCRIPT"   # 사용자가 준 인자를 그대로 덧붙인다
```

출력을 읽고 결과를 사용자에게 정리해 보고한다. 스크립트가 없으면 그 사실을 알리고 멈춘다.
