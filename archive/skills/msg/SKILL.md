---
name: msg
description: 코드 수정 없이 대화하듯 자연스럽게 작업을 진행하는 메시지 전용 모드. "메시지만", "수정하지 말고 얘기", "대화 모드" 등에서 동작한다.
allowed-tools: Bash, Read, Grep, Glob, Edit, Write
---

# msg

코드 수정 없이 대화하듯 자연스럽게 작업을 진행하는 메시지 전용 모드. "메시지만", "수정하지 말고 얘기", "대화 모드" 등에서 동작한다.

## 실행

절차는 셸 스크립트에 있다. 저장소 안에 있으면 그걸, 없으면 설치된 것을 쓴다.

```bash
SCRIPT=bin/msg.sh
[ -f "$SCRIPT" ] || SCRIPT="$HOME/.monggle/bin/msg.sh"
bash "$SCRIPT"   # 사용자가 준 인자를 그대로 덧붙인다
```

출력을 읽고 결과를 사용자에게 정리해 보고한다. 스크립트가 없으면 그 사실을 알리고 멈춘다.
