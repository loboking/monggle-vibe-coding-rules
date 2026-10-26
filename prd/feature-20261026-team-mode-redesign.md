---
type: feature
title: 팀 모드 재설계 — 팀 기억 공유 + 위험한 변경에만 가벼운 스펙
priority: P1
created: 2026-10-26
status: draft
related: prd/refactor-20261026-skill-consolidation.md
---

# PRD: 팀 모드 재설계

## 1. 배경
- 지금 팀 모드의 뜻은 "PRD 가 있어야 작업 진행" 하나다(`bin/mode.sh`, `prd_required: true`). 초창기 규칙이다.
- 팀 협업용 git 스크립트(동기화·충돌·PR)는 한 번도 구현되지 않았고, 기본 도구(`git pull --rebase --autostash`, `gh pr create`)와 AI 로 대체된다 → 축소 PRD 에서 push-safe 로 정리.
- brain 기억은 각자 PC(`~/.claude/brain`)에만 있다. 팀원끼리, 팀원 각자의 AI 끼리 "왜 이렇게 했는지"를 공유하지 못한다.

## 2. 판단: PRD 필수 규칙은 필요한가
- **목적은 지금 더 필요하다.** AI 로 코드 작성 비용이 거의 0 이 되면서 병목이 "무엇을 왜"를 맞추는 일과 리뷰로 옮겨 갔다. 업계도 스펙 우선(spec-kit, Kiro 스펙, plan 모드)으로 가고 있다. 팀에서는 각자의 AI 가 각자 해석해 만든 코드가 섞이는 걸 막아야 한다.
- **방식은 바꿔야 한다.**

| 지금 | 문제 | 바꿀 것 |
|---|---|---|
| 팀 모드면 모든 작업에 PRD | 오타 수정에도 PRD → 우회하거나 모드를 끔 | **위험도 기준**: 여러 파일·API·DB 스키마·인증/권한·새 기능일 때만 |
| 사업 기획서 형식 + 확신도 Verdict | 오래 걸리고 AI 가 매긴 점수는 의미가 약함 | **가벼운 스펙**: 목표 1줄 / 완료 조건 / 안 할 것 / 영향 파일 |
| 쓰고 끝 | 구현 중 바뀐 결정이 문서에 안 남음 | 완료 조건 → **테스트**, 바뀐 결정 → **팀 기억** |
| 따로 떨어진 파일 | 리뷰어가 따로 찾음 | PR 본문에 스펙 링크, 리뷰는 "스펙 대비 diff" |

## 3. 기능
### 3.1 팀 기억 (저장소 공유)
- 위치: `<저장소>/.monggle/memory/<날짜>-<slug>.md` — **기억 하나 = 파일 하나**(git 충돌 방지).
- 형식: frontmatter `type(decision|bug|caution) · paths · commit · created · review_after` + 본문(무엇을, 왜, 대안·버린 이유).
- 올라가는 것: 결정·버그 원인·주의사항만. 나머지는 개인 brain 에 남는다.
- 만드는 법: brain 저장 시 팀 모드면 해당 타입을 팀 기억 후보로 표시 → 작업 끝에 AI 가 "팀 기억으로 올릴까요" 목록 제시 → 사용자 승인분만 파일로. (자동 커밋 없음)
- 회상: brain recall 이 개인 기억과 함께 `.monggle/memory/` 도 검색. 수정하려는 파일이 `paths` 에 걸리면 우선 표시.
- 비밀값: brain 의 가림 기능 + push-safe 검사.
- 오래된 기억: `paths` 의 파일이 `commit` 이후 바뀌었으면 "다시 확인 필요" 표시(삭제 안 함).

### 3.2 위험도 기준 스펙
- 판단: 변경 예정 파일 수, 경로 패턴(`migrations/ schema auth api/ routes` 등), 새 파일 비율. 설정 `monggle.config.yaml: spec_required: risky|always|never` (팀 기본 risky, 솔로 기본 never).
- 강제 방식: 차단하지 않고 **경고 + PR 체크리스트**. 하드 차단은 `always` 일 때만.
- 스펙은 `spec` 스킬 형식. 완료 조건은 테스트 이름과 연결.

### 3.3 PR 연결
- push-safe 가 PR 을 만들 때 관련 스펙 파일·이번에 추가된 팀 기억을 본문에 링크.

## 4. 엣지 케이스
- 팀 기억 동시 생성: 파일명에 시각+slug, 충돌 없음.
- 팀원이 brain 미설치: 팀 기억은 일반 마크다운이라 사람·AI 가 그냥 읽을 수 있다. `AGENTS.md` 에 "작업 전 `.monggle/memory/` 에서 관련 파일 확인" 한 줄.
- 잘못된 기억: PR 리뷰에서 걸러짐. 틀리면 파일 삭제 대신 `superseded_by` 로 연결.
- 솔로 모드: 3.1 은 옵션(끄면 지금과 같음), 3.2 never.

## 5. 검증
- 팀 기억 생성·회상: 임시 저장소 2개(A·B 클론)에서 A 가 결정 저장→커밋→B 가 pull 후 같은 파일 수정 시 회상에 나타남
- 비밀값 포함 기억은 파일로 안 써짐
- 위험도: 오타 1줄 → 스펙 요구 없음 / `migrations/` 변경 → 경고
- 오래된 기억 표시

## 6. 범위 밖
- 기억 웹 UI 의 팀 보기(brain-web) — 후속
- 원격 서버 동기화(저장소 git 이 유일한 공유 수단)

## 7. 열린 질문 (사용자 결정)
- 팀 기억 위치 `.monggle/memory/` vs `docs/decisions/`(사람이 찾기 쉬움)
- 승인 없이 자동으로 올릴 타입이 있는가(예: caution)
