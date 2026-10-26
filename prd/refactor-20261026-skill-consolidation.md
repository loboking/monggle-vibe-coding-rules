---
type: refactor
title: 스킬 축소 — 입구 스킬 몇 개 + 안에 든 절차, 사용자는 몰라도 되게
priority: P1
created: 2026-10-26
status: in-progress
related: docs/audit/SKILLS_HARNESS_REVIEW-20261024.md, prd/feature-20261026-team-mode-redesign.md
---

# PRD: 스킬 축소

## 1. 배경
- 스킬을 나눈 의도: 사용자는 "고쳐줘"만 말하고 절차(영향 확인→수정→호출처 점검→테스트)를 말하지 않는다. 스킬이 그 절차를 대신 넣어 준다.
- 결과: 51개로 쪼개져 이름을 알아야 쓰게 됐고, AI 자동 선택도 실패했다(2.5개월 Skill 호출: verify 31, push-safe 1, mode 1, 나머지 48개 0회).
- 원인 추정: 비슷한 설명 51개가 동시에 보이면 AI 가 하나를 고르지 못한다. 설명이 "무엇을"만 말하고 "언제"를 말하지 않는다.
- 반례: brain 은 이름을 몰라도 훅으로 저절로 돌아서 실제로 쓰인다.

## 2. 원칙
1. **킷은 AI 를 직접 부르지 않는다.** 판단·실행은 각 플랫폼 AI(Claude·Codex·Gemini·OpenCode)가 하고, 킷은 절차 파일·스크립트·훅만 준다. 별도 API 비용이 드는 기능(LangGraph 팀)은 두지 않는다.
2. **반드시 지켜야 하는 것은 AI 에게 맡기지 않는다.** 기억 저장·비밀값 검사는 훅·스크립트로 고정한다.
3. **AI 에게 보이는 건 입구 몇 개, 노하우는 그 안에.** AI 는 스킬 설명만 미리 보고 본문·참고 파일은 고른 뒤에 읽는다. 세부 절차는 `skills/<입구>/references/` 로 옮겨 서로 경쟁하지 않게 한다.
4. **설명은 "언제"로 시작한다.** 예: `버그를 고치거나 기존 코드를 바꿀 때. …`
5. **지우지 않고 보관한다.** `archive/` 로 옮기고 2주 관찰 후 사용자가 삭제를 결정한다.

| 단계 | 사용자가 알 것 | 대상 |
|---|---|---|
| 자동(훅) | 없음 | brain |
| AI 가 고름 | 없음 | fix, qa, push-safe, answer-check, spec |
| 직접 부름 | 1~2개 | team(AI 팀), mode(사람 팀 모드) |

## 3. 대상

### 3.1 입구 스킬 (사용자·AI 에게 보이는 것)
| 스킬 | 흡수하는 것 (`references/`) | 비고 |
|---|---|---|
| **fix** | impact, debug, bottleneck, mem-check, profile, refactor, complexity | 1) 영향 범위 2) 증상별 참고 절차 3) 최소 수정 4) 관련 테스트 실제 실행 5) 보고. `--dry` 는 영향 분석만 |
| **qa** | code-qa, test, audit, security, lint-smart, format-check, bench | 프로젝트 자동 판별 유지 |
| **spec** (신규) | prd, new, gate, pipeline, quick, monggle-planner, product-manager, brainstorm | 가벼운 스펙(목표·완료 조건·안 할 것·영향 파일). 위험도 기준은 팀 모드 PRD |
| **push-safe** | — | 스크립트 재작성(§3.3) |
| **answer-check** | — | 구 `verify`. 내장 `/verify`(앱 실행 확인)와 이름 충돌 해소 |
| **team** | team-builder | AI 팀(페르소나 서브에이전트). 큰 일만 팀장 도현에게 |
| **mode** | — | 사람 팀 모드. 의미 재정의는 팀 모드 PRD |
| **brain**, **brain-web** | — | 유지 |
| verify | — | answer-check 별칭. **2026-11-09 까지만** |

### 3.2 보관 (`archive/skills/`)
- 내장 기능과 겹침: review, init, stats, auto-compact, AUTOCOMPLETE, wrapper, help
- 문서류: docs, tech-doc-writer, api-docs, readme-sync, changelog, bump
- 동작 안 함·대화형·별도 비용: team-run, team-status, cleanup-zombies, msg, monggle-upgrade, trace, harness(사용자 스킬에서 빼고 brain 내부 기능으로)

`bin/` 스크립트는 참고 절차에서 계속 쓰므로 **남긴다.** 단, 보관 스킬 전용으로만 쓰이는 `msg wrapper auto-compact help team team-run team-status cleanup-zombies` 는 `archive/bin/` 으로. `bin/init.sh` 는 훅이 부르므로 남긴다.

### 3.3 push-safe 재작성
- `lib/git_helper.sh`·`pr_helper.sh`·`bin/update.sh`·`config/git.conf` 는 **복구하지 않는다.** git 에 커밋된 적이 없다(2026-04-10 `b8a4cfd` 에 테스트·문서만 들어감). 2026-06 `7469ab3` 메시지에 고친 기록이 있어 로컬에는 있었으나 커밋되지 않은 채 사라졌다. 되살려도 `git pull --rebase --autostash`·`gh pr create`·AI 의 충돌 해결로 대체되는 기능이다.
- 순서: 원격 받기 → 뒤처졌으면 `git pull --rebase --autostash` (충돌 시 멈추고 AI·사람이 해결) → **보낼 커밋**의 비밀값 검사 → `git push`(force 금지) → 팀 모드·main 이 아닌 브랜치면 `gh pr create --fill`(gh 없으면 안내만).
- 비밀값 예외: 테스트용 가짜 값은 그 줄에 `pragma: allowlist secret` 을 붙인다.
- `lib/conflict_helper.sh` 와 그 기반 테스트(`git_helper.bats`·`update.bats`·`conflict_helper.bats`·`e2e_git_collaboration.bats`) 보관. 충돌은 AI 가 내용을 읽고 합치는 쪽이 파일 단위 한쪽 선택보다 정확하다.
- 루트의 `push-safe`·`update` 바로가기(없는 `.claude/commands/` 를 가리킴): push-safe 는 `bin/` 으로 고치고 update 는 보관.

## 4. 깨질 수 있는 곳
- [ ] `install.sh` 는 지금 **추가만** 한다 → 보관한 스킬이 설치 위치에 남는다. 재설치 때 "원본에서 빠진 이름"이고 **설치본이 킷 원본과 같을 때만** 지운다. 사용자가 고쳤거나 킷이 만들지 않은 스킬(graphify·humanize 등)은 건드리지 않는다.
- [ ] Codex·Gemini 는 SKILL.md 본문만 받으므로 `references/` 는 `~/.monggle/skills/` 로 함께 설치하고 본문에서 그 경로를 쓴다.
- [ ] `AGENTS.md` 의도→스킬 표, `.claude/rules/skill-structure.md`
- [ ] `tests/bash/skills.bats` 는 `bin/` 스크립트를 검사 — bin 을 남기므로 영향 없음
- [ ] 스크립트끼리 부르는 곳: `team.sh→team-run/team-status`, `team-status→cleanup-zombies` (같이 보관), `pre-tool-use→init.sh`(남김)
- [ ] AI 팀원 `~/.claude/agents-team/*/skills.md` 가 옛 스킬 이름을 언급하는지 확인(저장소 밖 사용자 데이터 — 보고만)

## 5. 진행 단계
1. **(이번)** 입구 스킬 재작성 + references 이동 + 보관 + install 정리 + push-safe 재작성 + 테스트 정리 + AGENTS.md 갱신
2. fix 의 "관련 테스트 찾아 실행"을 스크립트로, spec↔팀 기억 연결(팀 모드 PRD)
3. 2주 관찰(2026-11-09까지): Skill 호출 기록으로 자동 선택 횟수 집계, 아쉬운 것 복구
4. 사용자가 보관분 삭제 여부 결정

## 6. 검증
- 설치: 임시 HOME 에 (a) 킷이 설치한 옛 스킬 (b) 사용자가 고친 옛 스킬 (c) 킷 외 스킬을 두고 재설치 → (a)만 사라짐
- 설치본에서 다른 프로젝트 기준으로 입구 스킬이 가리키는 스크립트·참고 파일이 모두 존재
- push-safe: 정상 push / 뒤처짐→rebase 후 push / 충돌→멈춤·push 안 함 / 비밀값→멈춤 / 예외 표시→통과 / dry-run→push 안 함 / force 미사용
- bats 실패 0

## 7. 범위 밖
- 하네스 자동 정리(강등·귀속·cooldown) → 하네스 PRD
- 팀 기억 공유, 위험도 기준 스펙 강제 → `prd/feature-20261026-team-mode-redesign.md`
- AI 팀의 Codex·Gemini 지원

## 8. 완료 기준
- 보이는 스킬 10개(별칭 포함), 설명이 "언제"로 시작
- §6 전부 통과, 기존 bats 실패 28 → 0
