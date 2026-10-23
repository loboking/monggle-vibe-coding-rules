---
name: cleanup-zombies
description: 에이전트가 크래시로 강제 종료돼 팀 상태가 영원히 BUSY로 남는 '좀비 현상'을 청소한다. /run·team 실행 전 자동 호출. "좀비 정리", "팀 상태 멈춤", "BUSY 안 풀림" 등에서 동작한다.
allowed-tools: Bash, Read, Grep, Glob, Edit, Write
---

# cleanup-zombies

에이전트가 크래시로 강제 종료돼 팀 상태가 영원히 BUSY로 남는 '좀비 현상'을 청소한다. /run·team 실행 전 자동 호출. "좀비 정리", "팀 상태 멈춤", "BUSY 안 풀림" 등에서 동작한다.

## 실행

절차는 셸 스크립트에 있다. 저장소 안에 있으면 그걸, 없으면 설치된 것을 쓴다.

```bash
SCRIPT=bin/cleanup-zombies.sh
[ -f "$SCRIPT" ] || SCRIPT="$HOME/.monggle/bin/cleanup-zombies.sh"
bash "$SCRIPT"   # 사용자가 준 인자를 그대로 덧붙인다
```

출력을 읽고 결과를 사용자에게 정리해 보고한다. 스크립트가 없으면 그 사실을 알리고 멈춘다.
