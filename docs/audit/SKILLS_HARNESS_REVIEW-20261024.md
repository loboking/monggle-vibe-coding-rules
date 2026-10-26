# 스킬·하네스·팀·파이프라인 검토 (2026-10-24)

> 목적: 정리·개선 전에 **지금 무엇이 되고 무엇이 깨졌는지** 근거로 확정한다. 삭제·수정은 이 검토 → 기획 → PRD 순서를 거친다.
> 이 문서는 진단만 한다. 아무것도 지우거나 고치지 않았다(회귀 테스트만 추가).

## 0. 한눈에

| 급 | 무엇 | 영향 |
|---|---|---|
| **P0** | `bin/` 15개 스크립트의 저장소 루트 경로가 한 단계 위로 잡힘 | gate·stats·team-status·team-run·pipeline·prd·quick·trace 등 **팀·파이프라인 전체가 사실상 동작 안 함** |
| **P0** | `push-safe.sh` 가 없는 `lib/git_helper.sh`·`pr_helper.sh` 를 불러 즉시 실패 | `/push-safe` 스크립트 경로 불가 (스킬 문서대로 AI 가 손으로 하면 됨) |
| **P1** | 하네스 정리 로직이 **아예 없다** (정리 코드는 시각만 기록하는 빈 껍데기였다) | 루프 기록·개선 로그가 쌓이기만 함 |
| **P1** | 하네스 기록이 틀린 사람을 탓함 (읽기 전용 스킬도 작업트리 전체 변경을 자기 수정으로 기록) | 루프 경고·과다수정 경고가 거짓 양성 |
| **P1** | 내장 명령과 이름 충돌: `review` `debug` `verify` `init` `stats` | 특히 `verify` 는 Claude Code 내장 `/verify`(앱 실행 확인)와 뜻이 전혀 다름 |
| **P1** | `new`·`msg` 가 대화형 입력을 기다림 | 에이전트가 부르면 멈춤 |
| P2 | 실사용 거의 없음 + 네이티브 기능과 중복 다수 | 컨텍스트 낭비, 자동 발동 품질 저하 |
| P2 | 팀 기능이 두 갈래(LangGraph / 페르소나 서브에이전트)로 갈라져 있고 LangGraph 쪽은 설치조차 안 됨 | "팀 기능이 희석됐다"의 실체 |
| P3 | 스킬 표준 위반(대문자 이름, 이름만 반복하는 description), Codex 설치가 deprecated 경로 | 자동 발동·도구 호환 |

---

## 1. 실제 사용 기록 (근거)

`~/.claude/projects/*.jsonl` 2026-08-15 ~ 10-24 (약 2.5개월, 360개 세션)의 **Skill 호출**만 셌다.

| 스킬 | 호출 |
|---|---|
| verify | 31 |
| push-safe | 1 |
| mode | 1 |
| 나머지 이 킷 스킬 48개 | **0** |

- 파일 경로 언급(`skills/x/SKILL.md`, `bin/x.sh`)은 대부분 이 킷을 **고치는 작업**에서 나온 것이라 사용 근거로 보지 않았다.
- Codex·Gemini 사용 기록은 집계하지 않았다(다음 단계에서 보강).
- 해석: 스킬 대부분이 "있지만 안 불린다". 자동 발동(description) 품질 문제와 네이티브 기능 중복이 겹친 결과로 본다.

---

## 2. 하네스

### 2.1 구조
- 코드: `brain/harness-tracker.sh`(기록), `brain/skill-harness-wrapper.sh`(스킬 시작·끝에서 호출), `bin/harness.sh`(조회), `lib/loop_detection.sh`(별도 루프 탐지기), `scripts/auto_improvement.py`(개선 제안)
- 데이터: `~/.claude/.harness/` 한 곳 (전 프로젝트 공용)
- 연결: `bin/` 의 7개 스크립트(debug·fix·format-check·lint-smart·review·smart-qa·…)만 래퍼를 부른다. AI 가 SKILL.md 만 읽고 처리하면 기록되지 않는다.

### 2.2 문제 (급한 순)
| # | 문제 | 근거 |
|---|---|---|
| H1 | **정리 없음.** 구 세션 종료 훅의 "하네스 주기 정리"는 주석(30일 루프·90일 로그 정리)만 있고 실제 삭제 코드가 없었다. 현재 훅에서는 그 블록도 빠졌다 | `~/.claude/hooks/brain-session-end.sh:52-67` (구), `loop-detection.json` 144개 파일 항목 |
| H2 | **잘못된 귀속.** 스킬이 끝나면 `git diff HEAD` 전체를 그 스킬의 수정으로 기록 → 읽기 전용 `lint-smart` 가 "154파일 3767줄 과다수정"으로 기록됨 | `skill-harness-wrapper.sh:97-111`, `improvement-log.jsonl` 2026-10-22 |
| H3 | **프로젝트 섞임.** 루프 기록 키가 `AGENTS.md` 같은 상대경로라 다른 저장소의 같은 이름 파일과 합산 | `harness-tracker.sh:160-190` |
| H4 | `cooldown_minutes`(30) 설정은 있는데 쓰는 코드가 없음 → 한 번 5회 넘으면 영원히 경고 | `harness-tracker.sh:104`, `harness_check_loops` |
| H5 | 경고가 사용자에게 안 보임: 세션 시작 훅이 `harness_analyze` stderr 를 버림 | `brain-session-start.sh:48` |
| H6 | 개선 제안이 "제안"으로만 쌓이고 처리됨/폐기됨 상태가 없음 | `harness_log_improvement` |
| H7 | 루프 탐지기 2벌 (`harness-tracker` / `lib/loop_detection.sh`), 개선 분석기는 다른 폴더를 읽던 이력 | `docs/audit/BRAIN_VS_HARNESS_REPORT.md:96` |
| H8 | 임시파일 이름 고정(`*.tmp`) → 동시 실행 시 깨짐 (brain 에서 겪은 것과 같은 유형) | `harness-tracker.sh:164,219` |
| H9 | 래퍼의 `PROJECT_ROOT` 가 작업 폴더가 아니라 설치 위치 기준 | `skill-harness-wrapper.sh:37-52` |

### 2.3 방향 (PRD 입력)
- **삭제가 아니라 강등.** 항목마다 `first_seen / last_fired / fire_count / evidence / review_after` 를 두고: 상시 경고 → 조회 전용 → 보관(git 기록) 순으로 내린다. 실제 삭제는 사용자 승인.
- **귀속을 바로잡는다.** 스킬 시작 시점의 diff 를 찍어 두고 끝날 때 차이만 기록. 키는 `<저장소 루트>:<경로>`.
- **기한.** cooldown 을 실제로 적용하고, N일 발동 없는 루프 기록은 자동 강등.
- **보이게.** 경고는 세션 시작 JSON(`additionalContext`)으로 한 줄만.
- 참고 관행: Codex RFC #40575(ADD·NARROW·REPLACE·RETIRE·MERGE, 상시 로드 예산), "발동 0회 규칙은 정리 후보", "삭제 전 규칙 없이 돌려 차이 확인". 상세 출처는 §6.

---

## 3. 스킬별 상태 (급한 순)

점검 방법: 전 스크립트 `bash -n`, 참조 파일 존재 확인, 임시 HOME·임시 저장소에서 `--help` 실행.

### P0 — 깨짐
| 스킬 | 문제 | 근거 | 제안 |
|---|---|---|---|
| gate | `bin/../hooks/pre-tool-use.sh` 를 찾음(실제는 `.claude/hooks/`) | `bin/gate.sh:27` | 경로 수정 |
| stats | `~/orca/scripts/stats.py` 를 찾음 | `bin/stats.sh:32,50` | 경로 수정 |
| team-status | 현재 폴더의 `scripts/team_state.py` 를 찾음 | `bin/team-status.sh:33-37` | 경로 수정 |
| team-run | 루트 오계산 + `langgraph` 미설치 | `bin/team-run.sh:27,175` | 경로 수정, 존폐는 §4 |
| pipeline·prd·quick·trace·mode·harness·init·brainstorm·cleanup-zombies·smart-qa·monggle-upgrade | 같은 `../..` 경로 문제 | `grep 'SCRIPT_DIR/../..' bin/*.sh` | 일괄 수정(설치본 `~/.monggle/bin` 도 동일) |
| push-safe | 없는 `lib/git_helper.sh`·`pr_helper.sh`·`git.conf` | `bin/push-safe.sh:11-18` | 필요한 함수만 `lib/git.sh` 로 흡수 |
| smart-qa | 없는 `lib/skill_loader.sh` (오류는 숨김) | `bin/smart-qa.sh:27` | 참조 제거 또는 복구 |

원인: `dc05efc`(도구 중립 구조 전환)에서 `.claude/commands/` → `bin/` 으로 한 단계 얕아졌는데 상대경로를 그대로 뒀다. 그때 이 스크립트들을 실행해 보는 테스트가 없었다.

### P1 — 오동작·충돌
| 스킬 | 문제 | 제안 |
|---|---|---|
| verify | Claude Code 내장 `/verify`(앱 실행 확인)와 이름 충돌, 뜻도 다름. **유일하게 많이 쓰는 스킬** | 이름 변경(예: `answer-check`) — 사용자 습관 고려해 별칭 기간 |
| review · debug · init · stats | 내장 명령과 이름 충돌 (`/review`=`/code-review`, `/debug`=세션 디버그, `/init`=CLAUDE.md, `/stats`=`/usage`) | 이름 변경 또는 내장으로 대체 |
| new | 실행하면 언어 선택 입력을 기다림 | 비대화형 기본값 |
| msg | 대화형 REPL — 에이전트가 쓸 수 없음 | 삭제 후보(plan mode 로 대체) |
| quick · trace · debug · mode · pipeline · test | `--help` 를 인자로 오인하거나 exit 1 | 사소, 일괄 정리 |

### P2 — 중복·네이티브 대체 (삭제·통합 후보, 바로 지우지 않음)
| 묶음 | 겹치는 것 | 제안 |
|---|---|---|
| QA | qa · code-qa · test (+smart-qa 스크립트) | `qa` 하나 |
| 보안 | audit · security (+내장 `/security-review`) | 하나로, 네이티브에 없는 시크릿·의존성 검사만 |
| 기획 | prd · new · monggle-planner · product-manager · gate · pipeline · quick | 스펙 3단계(spec→plan→tasks) 하나로 재편 검토 |
| 문서 | docs · tech-doc-writer · api-docs · readme-sync · changelog | 2개 이하 |
| 리팩토링 | refactor · complexity (+내장 `/simplify`) | 축소 |
| 오타·도움말 | AUTOCOMPLETE · wrapper · help (내장 `/` 퍼지 매칭, `/skills`) | 삭제 후보 |
| 컨텍스트 | auto-compact (내장 `/compact`·자동 압축) | 삭제 후보 |
| 팀 | team · team-run · team-status · team-builder · cleanup-zombies | §4 |

삭제·통합 시 깨질 수 있는 것: `AGENTS.md` 의도→스킬 표, `.claude/rules/skill-structure.md` 전환 규칙, `tests/bash/skills.bats`, `install.sh` 설치 목록, 서로 부르는 스크립트(`debug.sh` → bottleneck/mem-check 안내 등). 통합 PRD 에 이 목록을 체크리스트로 넣는다.

### P3 — 다듬기
- `AUTOCOMPLETE` 대문자 이름(표준 위반), `monggle-planner`·`product-manager`·`tech-doc-writer` description 이 이름만 반복.
- 대부분 description 이 `X - Y. "/x" 등에서 동작한다` 형식 → "언제 쓰는지"가 약해 자동 발동에 불리.
- 실행 코드가 스킬 폴더가 아니라 루트 `bin/` 에 있어 스킬 폴더만 배포하면 깨짐(`scripts/` 표준 구조 아님).
- Codex 설치가 deprecated 된 `~/.codex/prompts`, Gemini 는 `~/.gemini/commands` — 둘 다 `~/.agents/skills` 하나로 통일 가능.
- `AGENTS.md` 363줄(권장 200줄 미만), 상당 부분이 description 이 할 일(의도→스킬 표).

---

## 4. 팀 기능·파이프라인

### 4.1 현재 모습 — 두 갈래로 갈라짐
| 갈래 | 구성 | 상태 |
|---|---|---|
| A. LangGraph 가상팀 | `team-run` → `scripts/langgraph_team.py` (planner·coder·reviewer 노드), `team_state.py`, `dynamic_team.py` | **동작 안 함**: 경로 오류 + `langgraph` 미설치. 별도 API 호출 구조라 도구 구독과 따로 비용 |
| B. 페르소나 서브에이전트 | `~/.claude/agents/team_*.md` 10명(도현·나루·태오·세린·준·다빈·서연·도윤·한나·시윤), 기억 `~/.claude/agents-team/` (74개 파일, 최근 2개월 16개 갱신), `team-builder`, `clock-in.sh` | **동작함(Claude 전용)**. 무인 출근(launchd)은 미등록, 출근 기록 0 |

- "희석"의 실체: 이름은 `team-*` 로 같지만 A 와 B 가 서로 모른다. 상태 보기(`team-status`)는 A 기준이라 B 의 실제 활동을 못 보여준다.
- B 는 Claude Code 전용 위치(`~/.claude/agents`)라 Codex·Gemini 에서는 팀이 없다.

### 4.2 파이프라인 (Gate→Scan→Fold→Verdict→Patch→Trace)
- 스크립트 전부가 P0 경로 문제로 현재 실행 불가.
- 기능 자체는 지금 도구들의 plan mode·`/goal`·서브에이전트와 많이 겹친다. 고유 가치는 **PRD 템플릿과 Verdict(PASS/FIX/FAIL) 기준** 정도.

### 4.3 방향 (PRD 입력)
1. **경로부터 복구**(P0) — 존폐 판단 전에 "원래 되던 상태"로 돌린 뒤 비교한다.
2. **팀은 B 하나로.** A(LangGraph)는 보관 후보. B 의 페르소나·기억을 도구 공용 위치로(Codex 서브에이전트·Gemini 서브에이전트 형식 지원 여부 확인 후).
3. **파이프라인은 얇게.** spec→plan→tasks 3파일 + Verdict 기준만 남기고, 실행 루프는 각 도구 네이티브(plan mode·`/goal`·`/batch`)에 맡긴다.
4. `team-status` 는 B 의 기억·작업 기록을 보여주도록 다시 정의.

---

## 5. 새로 필요한 스킬 아이디어 (생성 여부는 사용자 결정)

| 우선 | 이름(가칭) | 하는 일 | 왜 |
|---|---|---|---|
| P1 | skill-eval | 스킬이 있을 때/없을 때 비교 실행, 발동 적중률 측정 | 공식 가이드 1순위 권고. §1처럼 "안 불리는" 문제를 수치로 잡고, 하네스 강등·승격 근거가 됨 |
| P1 | skill-lint | 이름 규칙·description·500줄·내장 이름 충돌·참조 경로를 CI 에서 검사 | 이번 P0(경로)·P1(이름 충돌)을 다시 못 들어오게 |
| P1 | handoff | 진행 중 작업 상태를 `.agents/handoffs/` 에 남기고 다음 세션·다른 도구에서 이어받기 | brain(기억)과 짝. Claude↔Codex↔Gemini 오가는 이 킷 성격에 맞음 |
| P2 | dep-guard | 패키지 설치 명령을 가로채 존재·게시일·유사 이름 검사 | AI 가 지어낸 패키지 이름 선점 공격(slopsquatting) 대응 |
| P2 | spec | prd·gate·pipeline·quick·new 를 spec→plan→tasks 하나로 | 업계 표준 흐름, 스킬 수 감소 |
| P2 | browser-verify | 브라우저로 화면·콘솔·네트워크 확인 후 Playwright 테스트 생성 | UI 수정 "보기엔 맞음" 통과 방지 |
| P3 | context-budget | 상시 로드되는 스킬·AGENTS.md·회상 크기 합산, 안 쓰는 스킬 이름만 싣기 제안 | 스킬 많을수록 description 이 잘려 자동 발동 실패 |

---

## 6. 출처 (트렌드 조사)
- Agent Skills 규격: https://agentskills.io/specification · 평가: https://agentskills.io/skill-creation/evaluating-skills
- Anthropic 스킬 작성 가이드: https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
- Claude Code 스킬·명령·메모리: https://code.claude.com/docs/en/skills · https://code.claude.com/docs/en/commands · https://code.claude.com/docs/en/memory
- Codex 커스텀 프롬프트 deprecated: https://developers.openai.com/codex/custom-prompts · 규칙 생명주기 RFC: https://github.com/openai/codex/issues/40575
- Gemini CLI 스킬: https://geminicli.com/docs/cli/skills/ · OpenCode: https://opencode.ai/docs/skills
- Spec Kit: https://github.github.com/spec-kit/
- Slopsquatting: https://www.endorlabs.com/learn/slopsquatting-when-ai-agents-hallucinate-malicious-packages
- 규칙 쌓기 문제: https://hackernoon.com/ai-coding-tip-034-stop-hoarding-rules-in-your-agentsmd
- 일부는 2차 출처라 원문 미확인(조사 보고 기준). 내장 명령과 사용자 스킬 이름이 같을 때 어느 쪽이 우선인지는 공식 문서에서 확인 못 함.

---

## 7. 테스트로 고정한 것
`tests/bash/brain_harness.bats` (21개: 통과 16, 알려진 문제 skip 5)
- 고정(지금 잘 됨): brain MCP 6개, brain 훅 7개, 하네스 기록·루프 경고·bin 연동 3개
- 알려진 문제(고치면 skip 제거): 하네스 정리 없음, 프로젝트 섞임, 잘못된 귀속, bin 경로 `../..`, push-safe 의존 파일 없음
- 기존 `tests/bash` 28개 실패는 저장소에 없는 `lib/git_helper.sh`·`bin/update.sh` 를 테스트하는 것(이번 변경과 무관, 기준선 동일)

## 8. 다음 단계 제안
1. 이 검토 확인 → 범위 결정(사용자)
2. **P0 경로 복구 PRD** (작고 안전, 먼저) → 복구 후 위 skip 2개 제거
3. 하네스 정리(강등·귀속·기한) PRD
4. 스킬 통합·이름 변경 PRD (사용 기록 + 깨질 것 체크리스트 포함)
5. 신규 스킬은 §5 중 사용자가 고른 것만
