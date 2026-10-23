---
name: docs
description: 로컬 문서를 색인·검색하는 통합 문서 명령. index/search/status 하위 명령으로 문서를 찾는다. "문서 검색", "docs 인덱싱", "이 내용 어느 문서에 있어" 등에서 동작한다.
allowed-tools: Bash, Read, Grep, Glob, Edit, Write
---

# docs

로컬 문서를 색인·검색하는 통합 문서 명령. index/search/status 하위 명령으로 문서를 찾는다. "문서 검색", "docs 인덱싱", "이 내용 어느 문서에 있어" 등에서 동작한다.

## 실행

절차는 셸 스크립트에 있다. 프로젝트에 있으면 그걸, 없으면 전역에 설치된 것을 쓴다.

```bash
SCRIPT=.claude/commands/docs.sh
[ -f "$SCRIPT" ] || SCRIPT="$HOME/.claude/commands/docs.sh"
bash "$SCRIPT"   # 사용자가 준 인자를 그대로 덧붙인다
```

출력을 읽고 결과를 사용자에게 정리해 보고한다. 스크립트가 없으면 그 사실을 알리고 멈춘다.
