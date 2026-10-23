---
name: auto-compact
description: 컨텍스트 사용량이 80% 이상 차면 자동으로 compact를 제안·관리한다. on/off/status로 토글. "자동 컴팩트", "컨텍스트 꽉 참", "대화 정리" 등에서 동작한다.
allowed-tools: Bash, Read, Grep, Glob, Edit, Write
---

# auto-compact

컨텍스트 사용량이 80% 이상 차면 자동으로 compact를 제안·관리한다. on/off/status로 토글. "자동 컴팩트", "컨텍스트 꽉 참", "대화 정리" 등에서 동작한다.

## 실행

절차는 셸 스크립트에 있다. 프로젝트에 있으면 그걸, 없으면 전역에 설치된 것을 쓴다.

```bash
SCRIPT=.claude/commands/auto-compact.sh
[ -f "$SCRIPT" ] || SCRIPT="$HOME/.claude/commands/auto-compact.sh"
bash "$SCRIPT"   # 사용자가 준 인자를 그대로 덧붙인다
```

출력을 읽고 결과를 사용자에게 정리해 보고한다. 스크립트가 없으면 그 사실을 알리고 멈춘다.
