All key claims verified against actual code. Here is the final consolidated report.

# 스킬 통합/분할 최종 진단 리포트

> 대상: `.claude/commands/` + `.claude/skills/` (현 71개 등록 스킬)
> 방법: 8개 그룹 분석가 발견 종합 + 핵심 코드 근거 직접 재검증
> 원칙: 이름 유사성이 아닌 실제 코드(파일 존재/exec 대상/백엔드/부작용) 근거. 실제 변경 없음.

---

## 1. 핵심 요약

| 분류 | 건수 | 비고 |
|------|------|------|
| 🔴 즉시 처리 (깨짐/죽음) | **6건** | 실행 시 크래시 또는 silent 실패 — 기능 오류 |
| 🟡 통합 권고 (merge) | **7건** | high 5 / medium 2 |
| 🟢 분할 권고 (split) | **1건 (low)** | 사실상 "경계 정리" 권고 |
| ✅ 유지 (keep-separate) | **17쌍/군** | 이름은 겹쳐 보이나 코드상 고유 |

**규모 전망**: 현 71개 → **약 62~64개**.
- merge 확정분(smart-qa-read, docs-search/status, doc-writer 또는 tech-doc-writer, idea 또는 brainstorm, monggle, rule-upgrade, planner 또는 product-manager, team/team-status alias 정리)으로 alias 흡수.
- 깨진 등록(front-bugfix, css-bugfix, debug-master.sh 경로, upgrade) 제거 시 추가 감소.
- alias로 "유지"되는 항목(new, test, team-status)은 카운트상 줄지 않을 수 있어 범위로 표기.

**검증 노트**: 본 리포트는 분석가 인용 근거 중 영향이 큰 항목(team 스텁, front/css-bugfix 부재, debug-master.sh 부재, harness jq 오타, lib/git.sh 데드, docs 공유 백엔드, 백업 잔재)을 직접 재확인했고 모두 사실로 확인됨.

---

## 2. 🔴 즉시 처리 (기능 오류 — 깨진 위임 / 죽은 코드)

### R1. `/debug` 의 위임 대상 3개가 존재하지 않음 — 기본 경로조차 크래시 [high, 검증완료]
`debug.sh`는 `set -euo pipefail` 상태에서 존재하지 않는 `.sh`를 exec.
- `debug.sh:48` → `exec debug-master.sh` : **재검증 — `debug-master.sh` 없음, `debug-master.md`만 존재**. 인자 없는 `/debug`(가장 기본 경로)가 깨짐.
- `debug.sh:61` → `exec front-bugfix.sh`, `debug.sh:73` → `exec css-bugfix.sh` : **재검증 — `find` 결과 0건, `.sh`/`.md` 어떤 형태도 없음**. `--web`/`--css` 분기 100% 크래시.
- 5개 분기 중 3개(general/--web/--css)가 부재 파일 exec.
- 조치: case 문에서 `--web/--css/--frontend/--js/--react/--style` 제거, default 경로를 실재 진입점으로 교체(또는 `/debug`를 `.md` 디스패처로 재구성). 단 `--perf`→bottleneck.sh, `--mem`→mem-check.sh 두 분기는 정상이므로 보존.

### R2. 라우팅 문서가 존재하지 않는 스킬을 "원본 이름"으로 광고 [high, 검증완료]
`skill-structure.md:16-17`(`/debug-web→front-bugfix`, `/debug-css→css-bugfix`), `intent-routing.md`, `README.md`, `CLAUDE.md`, `AUTOCOMPLETE.md:186`(`debug.sh --web` 사용 예시), `CHANGELOG.md:194`가 모두 부재 스킬로 사용자를 안내(환각 라우팅).
- 조치: R1 구현 전까지 4개 문서의 `/debug-web`·`/debug-css` 매핑 일괄 삭제.

### R3. `team` 과 `team-status.sh` 가 7바이트 깨진 스텁 [high, 검증완료]
**재검증**: `file` 결과 `team`·`team-status.sh` 모두 `ASCII text, no line terminators`, 내용은 리터럴 문자열 `team.sh`(7바이트). 심볼릭링크 아님.
- `team-status.sh`는 exec 비트가 켜져 있어 실행 시 `team.sh`(PATH에 없음)를 맨명령으로 호출 → 실패. `git status`도 `T .claude/commands/team-status.sh`(typechange)로 표시 — 커밋 `7469ab3 "스킬 스크립트 버그 136건 일괄 수정"`이 ~4.8KB 원본을 이 스텁으로 덮어씀.
- 대조: 확장자 없는 `team-status`는 정상 심볼릭링크(`team-status -> team.sh`, **재검증: 실제 실행 가능 bash**), `team.sh`는 5511바이트 정상 실행 파일.
- 조치: `team`·`team-status.sh`를 `team.sh`를 가리키는 실제 심볼릭링크로 교체.

### R4. `harness.sh:227` jq 호출 오타 — 자동 제안이 영원히 안 보임 [high, 검증완료]
**재검증**: 실제 라인 = `... "$suggestion_file" 2-head -20 2>/dev/null || true`. `2-head`는 유효 토큰이 아니라 jq에 파일 인자로 잘못 전달 → 항상 실패하고 `|| true`로 삼켜짐. `improvement-suggestions.json`이 있어도 자동 제안 0% 표시.
- 조치: `... "$suggestion_file" 2>/dev/null | head -20`로 수정.

### R5. `upgrade` 등록이 깨짐 (호출 대상 부재) [medium]
available-skills에 `upgrade: upgrade`가 있으나 `upgrade.sh`/`upgrade.md` 부재.
- 조치: 등록 제거 또는 `monggle-upgrade`의 alias로 명시.

### R6. 백업 잔재 파일 정리 [medium, 검증완료]
**재검증**: `pipeline.sh.bak`(12507B, 4월17), `team-status.sh.backup`(4882B, 5월20) 실재. `install.sh`가 여러 곳(라인 281/335/501)에서 `*.sh`를 glob하며 `.bak`/`.backup`는 특례 처리 안 함 → install/sync 혼선 가능.
- 조치: 두 잔재 삭제.

---

## 3. 🟡 통합 권고 (merge)

### M1. `smart-qa-read` → `smart-qa --report` 흡수 [high]
`smart-qa.sh`는 이미 `--report`를 완전 구현(parse_args L173-176, run_tests L613에서 auto-fix 블록 skip, print_summary L646). `smart-qa-read.sh`는 그 동작의 stale 사본 — 기능이 더 적음: 단일파일 모드 kt/swift/ts/jsx 핸들러 없음(L317-342), `detect_project_type`에 Java/Spring·Docker 누락, console.log 검사가 server에서 `print(`만 보고 logger 제외 로직 부재(read L395 vs smart-qa L532). 두 사본이 silent divergence 분기 버그.
- 조치: `smart-qa-read.sh` 제거, `test.sh`의 `--report`도 `smart-qa.sh --report`로 변경.

### M2. `docs-index` + `docs-search` + `docs-status` → `/docs <subcmd>` [high, 검증완료]
**재검증**: 세 스크립트 모두 동일 백엔드(`$HOME/.claude/docs-search/venv/bin/python`, `.../lib/search_engine.py`)를 가리킴. 각각 그 단일 엔진의 서브커맨드 1:1 매핑(index→`sync`/`index`, search→`search --scope --limit`, status→헬스체크). 이미 서로 "Related commands"로 상호 참조. 보일러플레이트 3중복.
- 조치: `/docs index|search|status`로 통합, 기존 이름은 하위호환 alias. **단 `api-docs`·`readme-sync`는 백엔드 미공유이므로 통합 금지(아래 ✅ 참조).**

### M3. `doc-writer` + `tech-doc-writer` → 단일 문서작성 에이전트 [high]
둘 다 LLM이 산문 문서를 생성하는 `.md` 에이전트로 동일 책임. 문서 타입 readme/api/guide/changelog 4종 중복, README/API 템플릿·model 기본 sonnet·`-h/-s/-o`·`--lang`·도움말 박스·Final Metadata Output 포맷 동형. 차이는 보완적(doc-writer=LSP+git-changelog 분류 doc-writer.md:207-211, tech-doc-writer=WebFetch/WebSearch+architecture/deployment/troubleshoot/spec+스타일가이드 tech-doc-writer.md:208-224) — 별도 스킬로 나눌 만한 도메인 분리 아님.
- 조치: 도구·타입 합집합으로 1개 정본, 나머지 alias.

### M4. `idea` + `brainstorm` → 1개 스크립트, 다른 하나 alias [high]
diff 674 vs 684줄로 90%+ 동일. 실질 차이: 명령 이름 문자열, SESSION_DIR(`.idea` vs `.brainstorm`), brainstorm의 `extracted_info` 8필드 추가 + init에서 `extract_constraints_advanced` 호출(L101), jq 표현식 견고성. description·옵션 세트(`--free/--analyze/--to-prd/--export/--list/--clear`) 동일.
- 조치: **brainstorm.sh를 정본**(스키마/jq 더 완전), 이름·SESSION_DIR은 basename 분기.

### M5. `monggle` → `help` 흡수 (alias) [high]
둘 다 "스킬 카탈로그 출력" 중복 구현. `monggle.sh`(17-77)는 하드코딩 정적 출력, `help.sh`는 `SKILL_DATA`(L27-70) + `--search/--list/--summary`/카테고리 필터(L217-257)로 상위호환. 이미 드리프트 발생(monggle만 `/brain`·`/weekly-recap`, help만 verify·security).
- 조치: 카탈로그 단일 소스를 `help.sh`로, monggle은 alias.

### M6. `rule-upgrade` → `monggle-upgrade` 흡수 [high]
같은 스크립트 변종. `_compare_versions` vs `compare_versions` 동일 알고리즘, `do_upgrade()`가 stash→`git pull origin main --rebase`→stash pop 동일 흐름(rule-upgrade.sh:124-164, monggle-upgrade.sh:196-238). monggle-upgrade가 상위호환(Releases API 조회 L101, 24h throttle, 업그레이드 후 install.sh 재실행 L232). rule-upgrade는 `.md` 등록도 없어 반(半)고아.
- 조치: rule-upgrade 제거, 고유 기능 `.upgrade.log` 기록만 monggle-upgrade에 흡수.

### M7. `planner` + `product-manager` → 통합 (정본=product-manager) [medium]
둘 다 model sonnet, allowed-tools 거의 동일, 출력 템플릿(User Story As-a/Given-When-Then, 우선순위 매트릭스, scope In/Out, roadmap) 대거 중복. planner `--full` ≈ PM `--prd`. **confidence medium 사유**: PM에만 `--metrics`(OKR/KPI)·`--competitive`·WebSearch 시장조사 존재 → 통합 시 이 기능 보존 필수.

### M-보너스. `lib/git.sh` 데드 라이브러리 정리 [medium, 검증완료]
스킬 통합 이슈는 아니나 보고. **재검증: `lib/git.sh`를 source하는 command 0건**. 실사용은 `git_helper.sh`(pipeline.sh/push-safe.sh/update.sh가 source). 두 라이브러리가 `is_git_repo()`/`get_current_branch()` 중복 정의. `git.sh`의 changelog 헬퍼도 changelog.sh가 common.sh만 쓰므로 미사용.
- 조치: `lib/git.sh` 제거 또는 git_helper.sh로 통합.

---

## 4. 🟢 분할 권고 (split)

### S1. 통합된 idea/brainstorm 에서 "PRD 변환" 책임 분리 [low — 사실상 경계 정리]
단일 idea/brainstorm은 세션관리/자유대화/제약추출/export 등이 응집적이라 분할 필요 낮음. 다만 `to-prd`가 미구현 스텁(아래 R-관련)이라 "아이디어 수집 vs PRD 생성" 경계가 모호.
- 조치: PRD 생성 책임은 `prd.sh`로 일원화(분할이라기보다 경계 명확화).
- **연계 깨짐(주의)**: `idea.sh` L654-662(brainstorm 동일)의 to-prd는 `log_warn "PRD 변환 기능은 구현 중"` + `# TODO` 스텁. `prd.sh`는 `.idea/.brainstorm` 세션을 전혀 읽지 않음 → idea→prd 핸드오프 단절. 옵션 제거하거나 `prd.sh`에 `--from-session <path>` 추가 권장.

> 그 외 과다 책임으로 "분할"을 강하게 권할 스킬은 발견되지 않음. mem-check/bottleneck은 합치면 책임 과대(아래 ✅)이지 현재가 과대는 아님.

---

## 5. ✅ 유지 (keep-separate — 겹쳐 보이나 코드상 고유)

| 스킬(군) | 유지 근거 (코드) |
|---------|------------------|
| `bottleneck` vs `mem-check` | 성능(py-spy/clinic/pprof 안내 + 정적 안티패턴 grep) vs 메모리(누수/heap, RSS 실시간 모니터링). 도구·대상 배타적 |
| `bottleneck` vs `profile` | bottleneck=정적 grep/awk 스캐너(프로파일러 미실행, 안내만), profile=cProfile/clinic/pprof 실제 execute(L103/162/207). 정적 vs 동적 |
| `bench` | 처리량/시간 측정 + `--compare REF`로 git worktree baseline benchstat(L218-229) — 타 4개에 없는 고유 기능 |
| `complexity` | radon/lizard/gocyclo/detekt 순환복잡도·유지보수성 메트릭. 런타임 무관 — "성능 계열" 분류 자체가 부정확, 품질 계열로 재분류 권장 |
| `gate` vs `smart-qa`/`prd` | gate=PRD 문서 검증, hooks/pre-tool-use.sh(7080B 실재)에 위임. 소스코드 검사와 입력·목적 무관 |
| `verify` vs `smart-qa` | verify=heredoc로 읽기전용 스킬 명세 마크다운 stdout 방출(프롬프트 emitter), 실제 grep/shellcheck 미수행 |
| `api-docs` vs `docs-*` | search_engine.py 미참조. Sphinx/TypeDoc/godoc/javadoc로 소스→API 생성(docs-*는 기존 문서 색인/검색) |
| `readme-sync` | README.md 단일파일 유지보수(배지/설치명령/contributors/링크점검). 독립 백엔드 |
| `new` → `prd` | 78줄 thin wrapper, detect_type 후 `exec prd.sh` (alias) |
| `test` → `smart-qa` | 순수 라우터, 검사 코드 0줄 (alias) |
| `push-safe`/`update`/`bump`/`changelog` | 입력/출력/부작용 전부 다름. push-safe→update는 의도된 위임(push-safe.sh:111) |
| `quick` vs `fix` | quick=PRD 찾아 run_agent.py 파이프라인 러너, fix=impact.sh 기반 수정 헬퍼. 도메인 무관 |
| `save-point`/`handover`/`brain`/`harness` | 4개 데이터 스토어·목적 직교(세션복구/인수인계문서/메모리그래프/메트릭) |
| `save-point` vs `brain` | 스토어 다름이나 "이어서 작업" 의도 1군데 겹침 → 통합 X, 라우팅 문서로 역할 명시 |
| `stats` vs `trace` | stats=stats.py 집계 메트릭, trace=logs/*.log raw 뷰어. 백엔드 미공유 |
| `mode` | monggle.config.yaml 토글, 오케스트레이션군과 백엔드 미공유 |
| `team-status` vs `team-run` | team-status=team_state.py 읽기전용 관찰, team-run=langgraph_team.py 실행. 직교(R3 수리 후 `/team status`·`/team run`로 노출 가능) |
| `init` vs `setup-gemini` | init=user.conf 설정 마법사, setup-gemini=~/.gemini/config 키 저장. 대상·위치 무관 |
| `cleanup-zombies`/`auto-compact`/`wrapper` | 좀비 상태정리 / autoCompact 토글 / Levenshtein 오타교정 디스패처. 무관 |

> **추가 통합 후보(medium)**: `team-run` ↔ `pipeline`. team-run.sh:122-140과 pipeline.sh:192-237이 PRD 자동탐지 중복, LangGraph 부재 시 team-run이 `langgraph_team.py:300-315` fallback으로 pipeline.sh와 동일한 `run_agent.py`(pipeline.sh:37/306) 실행 → LangGraph 미설치 환경에서 동작 동일. 진짜 delta는 StateGraph 레이어뿐 → `/pipeline --team` 플래그로 흡수 가능, 최소한 PRD 탐지 로직 공통 lib화 권장. (현 시점 분류는 keep-separate이나 중복 부채 존재.)

---

## 6. 우선순위 표

| 우선순위 | 항목 | 분류 | 영향 | confidence |
|---------|------|------|------|------------|
| P0 | R3 team/team-status.sh 스텁 복구 | broken | 팀 명령 3중 2개 실행 불가 | high (검증) |
| P0 | R1 /debug 부재 exec 3분기 | broken | /debug 기본+web+css 크래시 | high (검증) |
| P0 | R4 harness jq `2-head` 오타 | broken | 자동제안 영구 미표시 | high (검증) |
| P1 | R2 문서의 존재안하는 스킬 매핑 제거 | broken | 환각 라우팅 | high (검증) |
| P1 | S1연계 idea/brainstorm `--to-prd` 스텁 | broken | 핸드오프 단절 | high |
| P1 | R5 upgrade 깨진 등록 | broken | 호출 대상 부재 | medium |
| P1 | R6 + lib/git.sh 데드/백업 잔재 | dead | install 혼선 | medium (검증) |
| P2 | M1 smart-qa-read 흡수 | merge | divergence 버그 제거 | high |
| P2 | M2 docs-* 통합 | merge | 보일러 3중복 | high (검증) |
| P2 | M5 monggle→help | merge | 카탈로그 드리프트 | high |
| P2 | M6 rule-upgrade→monggle-upgrade | merge | 반고아 제거 | high |
| P3 | M3 doc-writer/tech-doc-writer | merge | 에이전트 중복 | high |
| P3 | M4 idea/brainstorm 통합 | merge | 90% 사본 | high |
| P3 | M7 planner/product-manager | merge | 템플릿 수렴 | medium |
| P4 | team-run↔pipeline 중복 부채 | merge후보 | LangGraph외 동일 | medium |

**확신 낮음 명시**: M7(planner/PM, medium — PM 고유 metrics/competitive 보존 필요), team-run↔pipeline(medium — LangGraph 레이어가 진짜 차이), S1(low — 분할보다 경계정리), R5/R6(medium — 부작용 작음). 나머지 P0~P2 핵심 항목은 코드 직접 재검증 완료(high).