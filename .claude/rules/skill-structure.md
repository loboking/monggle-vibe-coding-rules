# 스킬 구조 v3.0

> **Last Updated:** 2026-10-26 — 51개를 입구 스킬로 줄였다. 근거: `prd/refactor-20261026-skill-consolidation.md`

## 원칙
- AI 에게 보이는 건 입구 스킬 몇 개. 세부 절차는 `skills/<입구>/references/*.md` 에 두고 고른 뒤에만 읽는다.
- description 은 **"언제 쓰는지"로 시작**한다.
- 반드시 지켜야 하는 것(기억 저장·비밀값 검사)은 훅·스크립트로 고정한다.
- 킷은 AI 를 직접 부르지 않는다. 판단은 각 플랫폼 AI 가 한다.

## 입구 스킬
| 스킬 | 언제 | references |
|---|---|---|
| `fix` | 버그·기존 코드 수정 | impact, debug, bottleneck, mem-check, profile, refactor, complexity |
| `qa` | 동작 확인·점검 | code-qa, test, audit, security, lint-smart, format-check, bench |
| `spec` | 새 기능·위험한 변경 전 | prd, new, gate, pipeline, quick, monggle-planner, product-manager, brainstorm |
| `push-safe` | 커밋·푸시·PR | — |
| `answer-check` | 답변 검증 (구 verify, 별칭 2026-11-09까지) | — |
| `team` | 큰 일을 AI 팀에게 | team-builder |
| `mode` | solo/team 전환 | — |
| `brain`, `brain-web` | 기억 (훅 자동) | — |

## 전환 규칙
| 상황 | 스킬 |
|---|---|
| 무엇이 문제인지 모름, 느림, 메모리 | `fix` (증상별 reference) |
| 수정 전 영향만 보고 싶음 | `fix --dry` |
| 새 기능인데 스펙 없음 | `spec` → `fix`/구현 |
| 오타·한 줄 수정 | `spec` 없이 `fix` |
| 머지 전 | `qa` → `push-safe` |

## 새 스킬을 만들 때
1. 기존 입구의 reference 로 넣을 수 있으면 그렇게 한다.
2. 새 입구는 "다른 입구와 언제가 겹치지 않을 때"만. 입구는 10개 이하(`tests/bash/brain_harness.bats` 가 검사).
3. 옛 스킬은 지우지 않고 `archive/skills/` 로 옮긴다. 재설치 때 설치본은 킷 원본과 같을 때만 정리된다.
