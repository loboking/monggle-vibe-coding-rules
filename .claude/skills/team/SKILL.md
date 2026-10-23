---
name: team
description: /team 디스패처 — 인자에 따라 상태 보기·팀 기동 등 하위 명령으로 위임한다. "팀", "team", "팀 명령" 등에서 동작한다.
allowed-tools: Bash, Read, Grep, Glob, Edit, Write
---

# team

/team 디스패처 — 인자에 따라 상태 보기·팀 기동 등 하위 명령으로 위임한다. "팀", "team", "팀 명령" 등에서 동작한다.

## 실행

절차는 셸 스크립트에 있다. 프로젝트에 있으면 그걸, 없으면 전역에 설치된 것을 쓴다.

```bash
SCRIPT=.claude/commands/team.sh
[ -f "$SCRIPT" ] || SCRIPT="$HOME/.claude/commands/team.sh"
bash "$SCRIPT"   # 사용자가 준 인자를 그대로 덧붙인다
```

출력을 읽고 결과를 사용자에게 정리해 보고한다. 스크립트가 없으면 그 사실을 알리고 멈춘다.
