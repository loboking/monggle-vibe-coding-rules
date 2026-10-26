---
name: spec
description: 새 기능을 만들거나 여러 파일·API·DB·인증에 걸친 위험한 변경을 시작하기 전에 쓴다. 목표·완료 조건·안 할 것·영향 파일을 담은 가벼운 스펙을 만들고, 필요하면 계획과 작업 목록으로 나눈다. "기획 세워줘", "PRD", "스펙", "계획 세워", "요구사항 정리", "아이디어" 등. 오타·한 줄 수정에는 쓰지 않는다.
allowed-tools: Bash, Read, Grep, Glob, Edit, Write
---

# spec

참고 파일 위치: 저장소 안이면 `skills/spec/references/`, 아니면 `~/.monggle/skills/spec/references/`.

## 1. 스펙이 필요한가
필요: 새 기능, 파일 여러 개, API 계약, DB 스키마·마이그레이션, 인증·권한, 되돌리기 어려운 변경.
불필요: 오타, 한 줄 수정, 로컬 실험 → 바로 `fix` 로.

## 2. 가벼운 스펙 (기본)
`<프로젝트>/prd/<type>-<YYYYMMDD>-<slug>.md` 에 쓴다. type: feature·bug·refactor·hotfix·experiment.

```markdown
---
type: feature
title: <한 줄>
status: draft
created: <YYYY-MM-DD>
---
## 목표
<한 문장: 누가 무엇을 할 수 있게 되나>
## 완료 조건
- [ ] <확인 가능한 조건 — 가능하면 테스트 이름으로>
## 안 할 것
- <이번 범위에서 뺀 것>
## 영향 파일
- <경로:심볼 — 모르면 fix 의 impact 절차로 먼저 찾는다>
## 결정
- <정한 것과 이유. 구현 중 바뀌면 여기와 brain 에 남긴다>
```
- 사용자가 준 정보로 채우고, 모르는 칸은 질문 1~3개로 묻는다. 지어내지 않는다.
- 완료 조건은 구현 후 테스트로 옮긴다.

## 3. 더 필요할 때 (해당할 때만 읽는다)
| 상황 | 참고 파일 |
|---|---|
| 큰 기능 → 계획·작업 목록으로 쪼개기 | `references/monggle-planner.md` |
| 사업·상품 관점 정의, 우선순위 | `references/product-manager.md` |
| 정식 PRD 템플릿(api·migration·ml·devops) | `references/prd.md` (`bin/prd.sh`) |
| 스펙 완성도 점검 | `references/gate.md` |
| 아이디어 발산 | `references/brainstorm.md` |
| 급한 핫픽스 | `references/quick.md` |
