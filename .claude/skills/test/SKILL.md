---
name: test
description: QA 테스트 러너 — 전체/보고서만/빠른 스모크 테스트를 실행한다. "테스트 돌려", "test", "QA", "스모크 테스트" 등에서 동작한다.
allowed-tools: Bash, Read, Grep, Glob, Edit, Write
---

# test

QA 테스트 러너 — 전체/보고서만/빠른 스모크 테스트를 실행한다. "테스트 돌려", "test", "QA", "스모크 테스트" 등에서 동작한다.

## 실행

절차는 셸 스크립트에 있다. 프로젝트에 있으면 그걸, 없으면 전역에 설치된 것을 쓴다.

```bash
SCRIPT=.claude/commands/test.sh
[ -f "$SCRIPT" ] || SCRIPT="$HOME/.claude/commands/test.sh"
bash "$SCRIPT"   # 사용자가 준 인자를 그대로 덧붙인다
```

출력을 읽고 결과를 사용자에게 정리해 보고한다. 스크립트가 없으면 그 사실을 알리고 멈춘다.
