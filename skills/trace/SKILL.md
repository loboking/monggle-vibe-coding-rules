---
name: trace
description: Pipeline trace - Trace execution and debug agent workflow. "/trace" 등에서 동작한다.
allowed-tools: Bash, Read, Grep, Glob, Edit, Write
---

# trace

Pipeline trace - Trace execution and debug agent workflow

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

## 실행

절차는 셸 스크립트에 있다. 저장소 안에 있으면 그걸, 없으면 설치된 것을 쓴다.

```bash
SCRIPT=bin/trace.sh
[ -f "$SCRIPT" ] || SCRIPT="$HOME/.monggle/bin/trace.sh"
bash "$SCRIPT"   # 사용자가 준 인자를 그대로 덧붙인다
```

출력을 읽고 결과를 사용자에게 정리해 보고한다. 스크립트가 없으면 그 사실을 알리고 멈춘다.
