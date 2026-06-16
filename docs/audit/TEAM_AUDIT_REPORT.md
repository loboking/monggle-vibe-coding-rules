Confirmed: 23 duplicate loboking entries + 1 unsubstituted placeholder = 24 member entries. The earlier "22" estimate was close; actual is 23. No `--intent` arg in langgraph_team argparse (only prd positional, --max-retries, --visualize, --verbose). All findings verified. Writing the report.

---

# 팀 협업 도구 분석 리포트 — Vibe Coding 툴킷

> 작성일: 2026-06-16 · 범위: 코드 정적 추적 + 실제 실행 검증 · 변경 없음(리포트 전용)

---

## 1. 한눈에 보기 — "팀"이라는 단어의 두 가지(사실은 네 가지) 의미

이 툴킷에서 "팀"은 하나의 일관된 기능이 아니라, **서로 배선되지 않은 독립 서브시스템 4개**가 같은 이름을 공유하는 구조입니다.

| # | "팀"의 의미 | 진입점 | 실제 하는 일 | 다른 것과 연결? |
|---|-----------|--------|-------------|----------------|
| A | **AI 가상 개발팀** | `/team-run` (`team-run.sh`) → `langgraph_team.py` | planner/coder/reviewer 3노드 시뮬레이션 | ❌ 코드 미생성, 상태 미기록 |
| B | **사람 협업 (PR + AI 리뷰)** | `install.sh` → `team.yaml`, GitHub Actions → `ai_reviewer.py` | PR에 규칙기반 코멘트 | ❌ A/C와 무관 |
| C | **팀 상태 모니터링** | `/team`, `/team-status` (`team-status.sh`) → `team_state.py` | 상태 테이블 출력 | ❌ A가 상태를 안 씀 |
| D | **PRD 강제 모드** | `/mode team` (`mode.sh`) → `monggle.config.yaml` | PRD 없으면 강제 트리거 | ❌ 단독 효과 1개뿐 |

**핵심 혼동 지점**: 사용자가 "팀으로 일하자"며 가장 먼저 칠 `/team`은 A(가상 개발팀 기동)가 아니라 **C(상태 구경)**로 연결됩니다. `/team`, `/team.sh`, `/team-status`는 전부 `team-status.sh` 심볼릭 링크입니다(실측 확인).

- 사람이 협업하는 부분은 사실상 B 하나뿐인데, B에는 팀원 자동 등록이 없고 AI 리뷰가 LLM이 아닙니다.
- A는 데모/시뮬레이션 수준으로, 실제 코드를 만들지 않습니다.

---

## 2. 시나리오 A: AI 가상 개발팀 (`/team-run`)

### PRD를 넣으면 실제로 일어나는 일 (단계별)

```
/team-run prd/xxx.md
  ↓ team-run.sh
1. PRD 자동탐지 (team-run.sh:122-140): 인자 없으면 prd/ 내 최신 .md 1개 선택
2. LangGraph 설치 확인 (112-119): 결과와 무관하게 항상 langgraph_team.py 호출(159)
  ↓ langgraph_team.py
3. build_team() (260-292): StateGraph 고정 3노드
     planner → coder → reviewer → (조건부 루프)
```

**각 노드가 실제로 하는 일:**

| 노드 | 역할(광고) | 실제 동작 | 근거 |
|------|-----------|----------|------|
| planner_node | "시니어 아키텍트" | PRD에서 `## 타겟`/`## Target` 불릿 파싱 → target_file. 못 찾으면 `main.py` fallback | `langgraph_team.py:95-104` |
| coder_node | "주니어 개발자 - 코드 구현" | **파일을 읽기만 함.** 빈 파일일 때만 메모리에 주석 한 줄 placeholder. 디스크 쓰기 0건 | `:142-159` |
| reviewer_node | "QA - 검증" | 길이/독스트링/try 휴리스틱 + **첫 실행(retry==0)이면 무조건 가짜 에러 주입** | `:204-206` |

**라우팅**: `should_continue`(233)가 에러 있고 retry<max면 coder로 되돌림. coder가 매 호출 retry+1(176)이므로 강제 에러 → 1회 재시도 → 보통 PASS. 종료 후 success/verdict/retry 요약만 출력하고 `current_code`는 버려집니다(454-477).

**LangGraph 미설치 시 fallback**: `run_fallback_pipeline`(299)이 `run_agent.py`의 선형 6단계(Gate→Scan→Fold→Verdict→Patch→Trace)로 대체. 단 `--max-retries`/`--verbose` 등 인자는 버려지고 PRD 경로만 전달됩니다(311-313). PatchAgent도 "implementation_plan: Ready" 문자열만 반환(`base_agent.py:327-348`).

### 결론 (A)
**어떤 경로로 가든 디스크에 코드를 쓰지 않습니다.** 검증 결과 `langgraph_team.py`/`run_agent.py`/`team-run.sh` 전체에서 파일 쓰기 호출 0건. PRD를 주고 돌려도 산출물은 0이며, "가상 개발팀"은 분석·판정·시뮬레이션 데모입니다.

---

## 3. 시나리오 B: 사람 팀 협업 (mode team + AI Reviewer + PR)

### 여러 개발자가 실제로 쓰는 흐름

```
[설정]   install.sh:587 setup_ai_reviewer
           → git config user.email/name으로 "현재 실행자 1명"만 등록
           → team.yaml 생성/갱신
[PR]     /push-safe → push-safe.sh + pr_helper.sh
[리뷰]   PR open → GitHub Actions(ai-reviewer.yml) → ai_reviewer.py → PR 코멘트
```

### 단계별 실제 동작

**1) 팀원 등록 (install.sh)**: `git config`로 **설치 실행자 1명**만 admin/member로 기록(`install.sh:650-655`). 여러 개발자를 추가하는 인자/프롬프트가 없어 수동 편집 필요.

**2) PR 자동 생성 (push-safe.sh)**: `push-safe.sh:21-22`가 `grep '^mode:'`, `grep '^create_pr:'`로 col0 키를 찾지만 **team.yaml에는 그 키가 없습니다**(실제 mode는 ai_reviewer 블록 내부 2칸 들여쓰기). 실측 `grep -c '^mode:' team.yaml = 0`. 따라서 `TEAM_MODE`는 항상 빈 문자열 → `push-safe.sh:145`의 팀 PR 분기가 **영원히 거짓** → 항상 일반 push로 떨어집니다. (PR 생성 로직 `pr_helper.sh` 자체는 gh CLI/curl로 정상 구현돼 있어 다른 경로로 부르면 동작.)

**3) AI 리뷰 (GitHub Actions)**: PR opened/synchronize(main,dev 대상) 시 트리거. `team.yaml`은 `model: gpt-4`, `OPENAI_API_KEY`로 "AI 리뷰"를 광고하지만, **실제로는 LLM을 호출하지 않습니다**:
- `ai_reviewer.py:141-143` 주석 그대로 "Always use rule-based analysis (API-free)" → 항상 `_rule_based_analysis`만 호출.
- `_call_claude`(196)/`_call_openai`(223)는 **호출되지 않는 dead code**(검증 확인).
- 실제 검사 = eval/exec/shell=True/하드코딩 패스워드 정규식 + TODO/HACK/FIXME grep뿐. security만 분기 처리하고 performance/test_coverage/documentation/error_handling 체크는 무시.
- 이슈 없으면 무조건 `confidence=0.8`(284-286).

### 결론 (B)
사람 협업은 (a) 팀원 자동 등록 없음(1명 고정), (b) push-safe 자동 PR은 키 불일치로 미작동, (c) AI 리뷰는 GPT-4가 아니라 얕은 정규식 grep, (d) members 명단은 수집되지만 머지 권한 판정에 쓰이지 않는 죽은 데이터.

---

## 4. 동시성 / 상태 공유 — 여러 명이 동시에 쓸 때

### 상태 저장소 구조 (team_state.py)
`.claude/teams/state/<team>_state.json`(상태), `history/<team>_audit.log`(감사), `<team>_state.json.lock`(flock), `.tmp`(원자적 쓰기). project_root는 스크립트 기준 고정이라 호출 위치 무관.

### 락 안전성 — 부분적으로만 안전
- ✅ **`acquire_lock`은 안전**: flock(LOCK_EX) 안에서 디스크 재독 → 검사 → 기록까지 read-modify-write 전체가 원자적(`team_state.py:248-291`). 30분 stale-lock 해제도 같은 임계영역.
- 🔴 **나머지 mutator는 비안전**: `set_status`/`complete_task`/`update_progress` 등은 `_save_state`(344-359)를 거치는데, 이는 flock을 "쓰기 순간에만" 잡고 `__init__` 시점(96)에 적재한 stale 메모리를 그대로 직렬화합니다. 변경 전 디스크 재독이 없어 **lost-update 발생**: A가 락을 잡은 직후 stale 메모리를 가진 B가 complete_task를 호출하면 A의 락/진행상태가 통째로 덮어써집니다. flock은 직렬화만 보장할 뿐 lost-update를 못 막습니다.

### 결정적 문제 — 상태와 실행의 배선 단절
검증 결과 `langgraph_team.py`/`run_agent.py`/`team-run.sh` 모두 `team_state` 참조 **0건**. 즉 `/team-run`으로 작업해도 BUSY/진행률/락이 전혀 기록되지 않습니다. `/team-status`는 항상 IDLE/빈 값만 표시합니다.

### 부가 문제
- **가짜 팀 목록**: `get_all_states()`(309-316)가 `.claude/teams/*.json` 중 `*_state.json`만 제외하고 글롭 → backend/database/debug/frontend/performance/security 6개 **구성 템플릿**을 "팀"으로 오인해 IDLE로 표시(실측). 실제 상태는 `state/` 하위에 있는데(security_state.json 1개만 존재) 다른 디렉토리·다른 스키마를 같은 글롭으로 섞음.
- **세션 ID 약함**: `--unlock`이 SESSION_ID 없으면 빈 문자열을 써서 `locked_by==session_id` 비교가 절대 일치 안 함 → CLI로 잡은 락을 CLI로 못 품(`team_state.py:464, 297`).

---

## 5. 실제 온보딩 순서 (코드 기준)

```
1) git clone → ./install.sh            # team.yaml 생성(설치자 1명 등록) - 단, 재실행 시 누적 손상
2) /mode team                          # monggle.config.yaml에 prd_required:true 기록
                                       #   → 유일한 효과: PRD 강제 (pre-tool-use.sh:230-238)
3) /prd                                # PRD 작성 (team 모드면 훅이 강제 트리거)
4) /team-run prd/xxx.md                # LangGraph 시뮬레이션 (실제 코드 변경 없음, 데모)
5) /team-status                        # 상태 확인 - 단, 4)가 상태를 안 써서 항상 빈/낡은 값
```

**주의사항**:
- 2단계의 `/mode team`은 변경 후 존재하지 않는 `scripts/sync_rules.py`를 호출(조용히 no-op, `mode.sh:111-114`).
- `monggle.config.yaml`은 저장소에 없어, /init·/mode 미실행 시 기본 solo(PRD 강제 꺼짐).
- 이 흐름 어디에도 **여러 사람이 실시간 협업하는 부분이 없습니다.** 사람 협업(B)은 별개의 PR/Actions 경로이며 위 흐름과 무관.
- `/team-run`은 단축 별칭조차 없어(team-run 바레 심볼릭 링크 부재) 발견성이 낮습니다.

---

## 6. 🔴 발견된 문제 (심각도별)

### HIGH

| # | 문제 | 근거 |
|---|------|------|
| H1 | **`/team`이 팀을 기동 안 하고 status로 빠짐** — 가장 직관적 이름의 오라우팅. 디스패처(team run\|status) 부재 | `team -> team-status.sh` 심볼릭 링크; main()이 인자 미사용 |
| H2 | **`/team-run`이 코드를 전혀 생성/수정 안 함** (디스크 쓰기 0건) | `langgraph_team.py:142-159`; 파일 쓰기 호출 0건 검증 |
| H3 | **reviewer가 첫 실행에 무조건 가짜 에러 주입** (프로덕션에 테스트 루프) | `langgraph_team.py:204-206` |
| H4 | **실행 엔진이 team_state와 미연동** → /team-status 항상 무의미 | team_state 참조 0건 검증 |
| H5 | **상태 mutator 대부분 멀티프로세스 비안전** (lost-update) — TOCTOU 수정이 acquire_lock에만 적용 | `team_state.py:344-359` vs `262-268` |
| H6 | **team.yaml 데이터 손상**: loboking 23회 중복 + ai_reviewer 키 2회(58,60행) + `{{ADMIN_EMAIL}}` 미치환. install.sh 보존 루프가 매 설치마다 누적 | 실측 `grep -c loboking=47`(라인), 멤버 24엔트리(23중복+1플레이스홀더); `install.sh:615,659-718` |
| H7 | **push-safe 팀 PR 자동화가 키 불일치로 절대 미작동** | `push-safe.sh:21-22`; `grep -c '^mode:' team.yaml=0` 실측 |
| H8 | **AI Reviewer가 LLM 아닌 정규식 grep** — 설정/문서와 불일치 | `ai_reviewer.py:141-143`, dead code `_call_openai/_call_claude` |
| H9 | **dynamic_team 안내 명령(`--intent`)이 langgraph_team에 없어 즉시 실패** | `dynamic_team.py:340`; argparse에 --intent 0건 검증 |
| H10 | **핵심 팀 명령이 문서에 전무** — `/team-run`/`/team-status`/`/team`이 GUIDE/README/CLAUDE.md 어디에도 없음 | grep 결과 미언급 |

### MEDIUM

| # | 문제 | 근거 |
|---|------|------|
| M1 | auto 머지 사실상 발동 불가 (고정 confidence 0.8 < 임계 0.9) | `ai_reviewer.py:284-286`; `team.yaml:77` |
| M2 | 팀원 자동 등록 경로 없음 (설치자 1명 고정), members는 어떤 로직에도 안 쓰임 | `install.sh:650-655`; should_auto_merge members 미사용 |
| M3 | dynamic_team이 team-run 흐름에서 완전 단절 (호출처 0건). teams/*.json 6개 죽은 데이터 | grep 0건 검증 |
| M4 | team-status가 구성 템플릿을 가짜 '팀'으로 오인 표시 | `team_state.py:309-316` |
| M5 | `/mode team` 실효 효과가 'PRD 강제' 단 하나뿐 (과장된 문구) | `mode.sh:118-122` vs `pre-tool-use.sh:230-238` |
| M6 | mode.sh가 존재하지 않는 sync_rules.py 호출 (죽은 코드) | `mode.sh:111-114` |
| M7 | PRD 타겟 파싱 형식 불일치 → 거의 항상 main.py fallback | `langgraph_team.py:95-104`; 실제 PRD에 `## 타겟` 없음 |
| M8 | 세션 ID 약해 CLI 락 해제 불가/소유자 혼동 | `team_state.py:464,297` |
| M9 | repo vs 전역 ~/.claude의 team 정의 drift (심볼릭 vs 독립 복사본) | diff 차이 |
| M10 | `--visualize`도 PRD를 강제 요구하나 정작 미사용 | `team-run.sh:122-143` vs `langgraph_team.py:374-393` |

### LOW
- fallback이 `--max-retries`/`--verbose` 인자 버림 / agents 경로 추가 후 미사용(죽은 코드) / 30분 stale-lock이 장시간 작업 무단 탈취 가능(heartbeat 없음) / team-status 테이블 테두리 정렬 깨짐 / team.yaml이 커밋돼 개발자별 git 정보 충돌·노출 / skill.md가 빈 스텁이라 커맨드 의도 미문서화.

---

## 7. 한 줄 결론

**아니요 — 지금은 팀 단위로 쓸 준비가 되지 않았습니다.** "팀"이라는 4개 서브시스템이 서로 배선되지 않은 채(`/team-run`은 코드를 안 만들고, 만든 작업은 `team_state`에 안 기록되며, `push-safe`의 팀 PR은 키 불일치로 안 돌고, "AI 리뷰"는 LLM이 아닌 grep이고, `team.yaml`은 설치 반복으로 손상됨), 사람이 실제로 협업하는 경로는 GitHub Actions 규칙기반 PR 코멘트(B) 하나뿐인데 그조차 팀원 등록·자동 머지가 작동하지 않습니다. 데모/단일 사용자 실험 단계이며, 팀 도입 전에 최소 H1~H8 수정이 선행돼야 합니다.