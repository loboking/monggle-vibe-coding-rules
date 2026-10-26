---
name: team-status
description: 모든 팀의 현재 상태를 표 형태로 보여준다. "팀 상태", "팀 현황", "team status", "누가 뭐 하고 있어" 등에서 동작한다.
allowed-tools: Bash, Read, Grep, Glob, Edit, Write
---

# team-status

모든 팀의 현재 상태를 표 형태로 보여준다. "팀 상태", "팀 현황", "team status", "누가 뭐 하고 있어" 등에서 동작한다.

## 실행

절차는 셸 스크립트에 있다. 저장소 안에 있으면 그걸, 없으면 설치된 것을 쓴다.

```bash
SCRIPT=bin/team-status.sh
[ -f "$SCRIPT" ] || SCRIPT="$HOME/.monggle/bin/team-status.sh"
bash "$SCRIPT"   # 사용자가 준 인자를 그대로 덧붙인다
```

출력을 읽고 결과를 사용자에게 정리해 보고한다. 스크립트가 없으면 그 사실을 알리고 멈춘다.
