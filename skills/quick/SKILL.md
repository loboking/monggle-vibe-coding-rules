---
name: quick
description: Quick hotfix - Fast bug fix workflow for simple issues. "/quick" 등에서 동작한다.
allowed-tools: Bash, Read, Grep, Glob, Edit, Write
---

# quick

Quick hotfix - Fast bug fix workflow for simple issues

긴급 핫픽스를 위한 빠른 실행 모드입니다. Gate와 Fold 단계를 건너뜁니다.

## Usage

```bash
/quick [prd_file]
```

## Pipeline Difference

**Full Pipeline:**
```
Gate → Scan → Fold → Verdict → Patch → Trace
```

**Quick Mode:**
```
Scan → Patch → Trace
```

## When to Use

- ✅ 긴급 버그 수정 (Production issue)
- ✅ 간단한 수정 (1-2 파일)
- ✅ 명확한 원인 (디버깅 완료)

## When NOT to Use

- ❌ 새로운 기능 개발
- ❌ 복잡한 리팩토링
- ❌ 요구사항이 불명확할 때

## Examples

```bash
/quick                    # 빠른 수정 (대화형)
/quick prd/hotfix.md      # PRD 파일 지정
```

## Related Commands

- `/prd hotfix` - 핫픽스 PRD 생성
- `/pipeline` - 전체 파이프라인 실행

## 실행

절차는 셸 스크립트에 있다. 저장소 안에 있으면 그걸, 없으면 설치된 것을 쓴다.

```bash
SCRIPT=bin/quick.sh
[ -f "$SCRIPT" ] || SCRIPT="$HOME/.monggle/bin/quick.sh"
bash "$SCRIPT"   # 사용자가 준 인자를 그대로 덧붙인다
```

출력을 읽고 결과를 사용자에게 정리해 보고한다. 스크립트가 없으면 그 사실을 알리고 멈춘다.
