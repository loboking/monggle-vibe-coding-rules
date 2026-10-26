---
name: fix
description: 버그를 고치거나 기존 코드를 바꿀 때 쓴다. 먼저 영향 범위(엮인 코드)를 확인하고, 증상에 맞는 절차(원인 추적·느림·메모리·복잡도)로 최소 수정한 뒤, 관련 테스트를 실제로 돌려 회귀를 점검한다. "고쳐줘", "버그", "안 돼", "느려", "메모리", "리팩토링", "수정하면 어디 영향 가?" 등.
allowed-tools: Bash, Read, Grep, Glob, Edit, Write
---

# fix

참고 파일 위치: 저장소 안이면 `skills/fix/references/`, 아니면 `~/.monggle/skills/fix/references/`.

## 1. 영향 범위 (항상)
`references/impact.md` 절차로 바꿀 대상의 호출처·공유 상태·계약을 찾고 위험도(高/中/低)를 매긴다.
`/fix --dry` 또는 "영향만 봐줘"면 여기서 보고하고 멈춘다.

## 2. 증상별 절차 (해당할 때만 읽는다)
| 증상 | 참고 파일 |
|---|---|
| 원인을 모름, 오류·크래시 | `references/debug.md` |
| 느림, 병목 | `references/bottleneck.md`, 측정이 필요하면 `references/profile.md` |
| 메모리 증가, OOM, 누수 | `references/mem-check.md` |
| 구조 정리·리팩토링 | `references/refactor.md`, `references/complexity.md` |

추측으로 고치지 않는다. 재현하거나 근거(로그·측정·코드 경로)를 먼저 잡는다.

## 3. 수정
- 1단계에서 찾은 엮인 코드를 먼저 읽고 고친다. 공유 함수의 근본 원인을 한 곳에서 고친다.
- 요청 범위 밖은 건드리지 않는다.

## 4. 회귀 점검 (생략 금지)
1. 바뀐 파일과 바뀐 심볼을 쓰는 곳을 다시 grep 해 깨지지 않는지 본다.
2. 관련 테스트를 찾아 **실제로 실행한다**: 바뀐 파일 이름·심볼로 테스트 파일을 찾고, 프로젝트의 테스트 명령(package.json·Makefile·gradle·pytest·`tests/run_tests.sh` 등)으로 돌린다.
3. 테스트가 없으면 이번 버그를 잡는 가장 작은 테스트 하나를 제안하거나 추가한다.

## 5. 보고
수정 요약(파일:라인) / 엮인 코드 확인 결과 / 회귀 위험 [高/中/低] / 실행한 테스트와 결과.
