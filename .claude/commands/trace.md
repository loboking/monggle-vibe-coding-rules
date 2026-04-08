# /trace - Pipeline Trace

파이프라인 실행 로그와 기록을 확인합니다.

## Usage

```bash
/trace [session_id]
```

## Examples

```bash
/trace                    # 최근 세션 로그
/trace abc123             # 특정 세션 로그
/trace --list             # 모든 세션 목록
```

## Log Location

```
logs/pipeline/
├── 2026-04-08/
│   ├── 143022_feature-auth.log
│   ├── 131500_bug-login-fix.log
│   └── 110000_refactor-api.log
```

## Log Format

```
[2026-04-08 14:30:22] START pipeline
[2026-04-08 14:30:23]   Gate: PASS
[2026-04-08 14:30:45]   Scan: 127 files analyzed
[2026-04-08 14:31:02]   Fold: 23 requirements mapped
[2026-04-08 14:31:15]   Verdict: PASS (0.95)
[2026-04-08 14:32:30]   Patch: 15 files modified
[2026-04-08 14:32:31]   Trace: log saved
[2026-04-08 14:32:31] END pipeline (2m 9s)
```

## Related Commands

- `/pipeline` - 파이프라인 실행
- `/stats` - 통계 확인
