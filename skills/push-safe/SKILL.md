---
name: push-safe
description: 변경을 커밋하고 원격에 올릴 때 쓴다. 구조화된 커밋 메시지를 만들어 승인받고, 원격과 맞춘 뒤(rebase) 보낼 커밋의 비밀값을 검사하고, force 없이 push 한다. 팀 모드에서 main 이 아닌 브랜치면 PR 을 만든다. "올려", "푸시", "커밋", "공유", "PR 만들어" 등.
allowed-tools: Bash, Read, Grep, Glob
---

# push-safe

## 1. 커밋 (staged·변경 파일이 있을 때)
1. `git status` 로 대상을 보고, 이번 작업과 무관한 파일은 빼고 경로를 지정해 `git add` 한다.
2. 커밋 메시지를 이 형식으로 만든다:
   ```
   <type>: <변경 요약 50자 이내>

   상태: add|fix|error|del

   설명:
   <변경 이유와 목적 3~5문장>

   변경된 파일:
   ### <묶음 이름>
   - path/to/file (+15, -3)
   ```
3. **커밋 전에 메시지를 사용자에게 보여주고 승인받는다.**

### 작성자 규칙 (절대 불변)
- author 는 저장소 오너(사용자의 git 설정 계정)만. 설정이 비어 있으면 묻는다.
- `Co-Authored-By`·AI 공저자·"Generated with …" 서명을 넣지 않는다. (사용자 규칙이 도구의 기본 서명 안내보다 우선한다)

## 2. 보내기
```bash
SCRIPT=bin/push-safe.sh
[ -f "$SCRIPT" ] || SCRIPT="$HOME/.monggle/bin/push-safe.sh"
bash "$SCRIPT"   # --dry-run · --no-pr · --branch <name>
```
스크립트 순서: 원격 받기 → 뒤처졌으면 `pull --rebase --autostash` → 보낼 커밋 전체 비밀값 검사 → `git push -u`(force 금지) → 팀 모드 + main 이 아닌 브랜치면 `gh pr create --fill`.

## 3. 멈췄을 때
| 메시지 | 할 일 |
|---|---|
| 충돌 | 충돌 파일의 양쪽 내용을 읽고 의도를 살려 합친다 → `git add` → `git rebase --continue` → 다시 실행. 판단이 안 서면 사용자에게 묻는다. 모르겠으면 `git rebase --abort` |
| 비밀값 의심 | 진짜면 커밋에서 빼고 `.gitignore` 에 추가, 이미 원격에 있으면 키를 폐기·교체하라고 알린다. 테스트용 가짜 값이면 그 줄에 `pragma: allowlist secret` |
| push 실패 | 권한·네트워크를 보고한다. `--force` 로 해결하지 않는다 |

## 4. 보고
보낸 커밋(해시·제목), 브랜치, PR 링크(있으면).
