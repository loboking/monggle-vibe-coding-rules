---
name: new
description: 한 줄 설명으로 빠르게 PRD를 생성한다. /new <설명>. "새 기획", "빠른 PRD", "이 기능 기획서 만들어" 등에서 동작한다.
allowed-tools: Bash, Read, Grep, Glob, Edit, Write
---

# new

한 줄 설명으로 빠르게 PRD를 생성한다. /new <설명>. "새 기획", "빠른 PRD", "이 기능 기획서 만들어" 등에서 동작한다.

## 실행

절차는 셸 스크립트에 있다. 프로젝트에 있으면 그걸, 없으면 전역에 설치된 것을 쓴다.

```bash
SCRIPT=.claude/commands/new.sh
[ -f "$SCRIPT" ] || SCRIPT="$HOME/.claude/commands/new.sh"
bash "$SCRIPT"   # 사용자가 준 인자를 그대로 덧붙인다
```

출력을 읽고 결과를 사용자에게 정리해 보고한다. 스크립트가 없으면 그 사실을 알리고 멈춘다.
