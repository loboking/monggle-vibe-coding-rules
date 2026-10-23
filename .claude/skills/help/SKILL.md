---
name: help
description: 카테고리별 스킬을 검색·안내하는 대화형 도움말. /help [카테고리] 또는 --search 키워드. "도움말", "무슨 스킬 있어", "명령어 목록", "help" 등에서 동작한다.
allowed-tools: Bash, Read, Grep, Glob, Edit, Write
---

# help

카테고리별 스킬을 검색·안내하는 대화형 도움말. /help [카테고리] 또는 --search 키워드. "도움말", "무슨 스킬 있어", "명령어 목록", "help" 등에서 동작한다.

## 실행

절차는 셸 스크립트에 있다. 프로젝트에 있으면 그걸, 없으면 전역에 설치된 것을 쓴다.

```bash
SCRIPT=.claude/commands/help.sh
[ -f "$SCRIPT" ] || SCRIPT="$HOME/.claude/commands/help.sh"
bash "$SCRIPT"   # 사용자가 준 인자를 그대로 덧붙인다
```

출력을 읽고 결과를 사용자에게 정리해 보고한다. 스크립트가 없으면 그 사실을 알리고 멈춘다.
