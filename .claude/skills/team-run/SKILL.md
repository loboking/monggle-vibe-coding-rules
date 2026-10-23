---
name: team-run
description: LangGraph 기반 가상 개발팀(멀티 에이전트)을 기동해 PRD를 협업 실행한다. "팀 실행", "팀 기동", "가상 개발팀 돌려", "team run" 등에서 동작한다.
allowed-tools: Bash, Read, Grep, Glob, Edit, Write
---

# team-run

LangGraph 기반 가상 개발팀(멀티 에이전트)을 기동해 PRD를 협업 실행한다. "팀 실행", "팀 기동", "가상 개발팀 돌려", "team run" 등에서 동작한다.

## 실행

절차는 셸 스크립트에 있다. 프로젝트에 있으면 그걸, 없으면 전역에 설치된 것을 쓴다.

```bash
SCRIPT=.claude/commands/team-run.sh
[ -f "$SCRIPT" ] || SCRIPT="$HOME/.claude/commands/team-run.sh"
bash "$SCRIPT"   # 사용자가 준 인자를 그대로 덧붙인다
```

출력을 읽고 결과를 사용자에게 정리해 보고한다. 스크립트가 없으면 그 사실을 알리고 멈춘다.
