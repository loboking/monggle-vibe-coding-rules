---
type: bug
title: P0 스킬 실행 경로 복구 — KIT_ROOT/PROJECT_ROOT 분리, 설치본 구조 보존
priority: P0
created: 2026-10-24
status: done
related: docs/audit/SKILLS_HARNESS_REVIEW-20261024.md
---

# PRD: P0 스킬 실행 경로 복구

## 1. 버그 요약
`bin/` 스크립트가 킷 자원(`scripts/*.py`·`lib/`·훅)과 사용자 프로젝트(`prd/`·`logs/`·`.claude/`)를 **같은 `PROJECT_ROOT` 하나**로 찾는다. 그 값도 `SCRIPT_DIR/../..` 라 한 단계 위를 가리킨다. 그 결과 팀·파이프라인 스크립트 대부분과, 저장소 밖(설치본 `~/.monggle/bin`)에서 도는 스크립트 19개가 시작하자마자 실패한다.

## 2. 상세 설명
| 증상 | 재현 |
|---|---|
| `/prd` 실패 | `bash bin/prd.sh bug --non-interactive` → `can't open file '/Users/…/orca/scripts/prd_creator.py'` |
| `/stats` 실패 | `bash bin/stats.sh` → `Stats script not found: …/orca/scripts/stats.py` |
| `/gate` 실패 | `bash bin/gate.sh` → `Hook file not found: bin/../hooks/pre-tool-use.sh` |
| `/team-status` 실패 | 다른 폴더에서 실행 → `can't open file '<현재폴더>/scripts/team_state.py'` |
| 설치본 전멸 | 다른 프로젝트에서 `bash ~/.monggle/bin/format-check.sh --help` → `…/.monggle/bin/../lib/common.sh: No such file or directory` |

## 3. 원인
1. `dc05efc`(도구 중립 전환)에서 스크립트를 `.claude/commands/` → `bin/` 으로 한 단계 얕게 옮기면서 `../..` 를 그대로 뒀다.
2. 예전에는 킷을 **프로젝트마다** `.claude/` 안에 복사했으므로 "킷 위치 = 프로젝트 위치"였다. 전역 설치로 바뀌며 둘이 갈라졌는데 변수는 하나로 남았다.
3. `install.sh` 의 `install_scripts` 가 `bin/` 만 `~/.monggle/bin` 에 복사한다(`lib/`·`scripts/`·`brain/`·`agents/`·훅 없음).
4. 이 스크립트들을 저장소 밖에서 실행해 보는 테스트가 없었다.

## 4. 수정 계획
### 4.1 두 변수로 나눈다 (14개 스크립트 + 훅 1개)
```bash
KIT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"                                   # 킷 자원: scripts/ lib/ agents/ VERSION 훅
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"   # 사용자 데이터: prd/ logs/ .claude/ 프로젝트 판별
```
- 킷 자원을 가리키는 11곳(`scripts/*.py`, `agents/`, `VERSION`)은 `KIT_ROOT` 로 바꾼다.
- 사용자 데이터를 가리키는 곳(`prd/`, `logs/`, `.claude/…`, `monggle.config.yaml`, `build.gradle` 등 판별)은 `PROJECT_ROOT` 를 그대로 쓴다 — 값만 바르게 된다.
- `gate.sh:27`, `pipeline.sh:57` 훅 경로 → `${KIT_ROOT}/.claude/hooks/pre-tool-use.sh`.
- `.claude/hooks/pre-tool-use.sh:26` 도 같은 방식.
- `trace.sh:29` 로그 위치 → `${PROJECT_ROOT}/logs`, `team-status.sh:33` → `KIT_ROOT`.
- `monggle-upgrade.sh:49` 는 "최후 폴백"으로 의도된 코드라 동작 확인 후 판단(변경 최소).

### 4.2 설치본이 저장소와 같은 구조를 갖게 한다
`install_scripts` 가 `bin/ lib/ scripts/ brain/ agents/ VERSION .claude/hooks/pre-tool-use.sh` 를 `~/.monggle/` 아래 **같은 상대 위치**로 복사한다. 그러면 `bin/..` = `~/.monggle` 이 저장소 루트와 같은 역할을 한다.

### 4.3 범위 밖 (이번에 하지 않음)
- `scripts/*.py` 내부의 경로 로직, LangGraph 미설치, 스킬 통합·이름 변경, 하네스 정리 → 별도 PRD.
- `push-safe.sh` 의 없는 `git_helper.sh`·`pr_helper.sh` → 별도 PRD(함수 흡수 vs 단순화 결정 필요).
- `smart-qa.sh` 의 없는 `skill_loader.sh`(오류를 숨기고 진행) → 참조만 제거.

## 5. 엣지 케이스
- git 저장소가 아닌 폴더에서 실행 → `PROJECT_ROOT=pwd`.
- 바깥에서 export 된 `PROJECT_ROOT` 는 쓰지 않는다(래퍼가 틀린 값을 export 하고 있어 그대로 이어받으면 버그가 남는다).
- 저장소 안에서 실행(개발 중) → `KIT_ROOT`=저장소, `PROJECT_ROOT`=저장소. 지금과 같은 결과.
- 설치본 재설치 → 기존 `~/.monggle/` 의 사용자 데이터는 없다(데이터는 프로젝트에 생김). 덮어써도 안전.
- 경로에 공백 → 모든 경로 변수는 따옴표로 감싼다.

## 6. 검증 (테스트)
`tests/bash/brain_harness.bats` 에 추가·해제:
1. `[known] bin scripts must not climb two levels` skip 해제 → `../..` 0건.
2. **설치본 스모크**: 임시 HOME 에 `install.sh` 의 스크립트 설치를 돌리고, 다른 임시 git 프로젝트에서 각 `~/.monggle/bin/*.sh --help` 실행 → "No such file or directory" 0건.
3. `prd.sh bug --non-interactive` 를 임시 프로젝트에서 실행 → `<임시 프로젝트>/prd/` 에 파일 생성, 킷 폴더에는 생기지 않음.
4. `stats.sh`·`gate.sh`·`team-status.sh` 가 "not found" 없이 실행.
5. 기존 brain·harness 테스트 16개 계속 통과, 기존 bats 실패 수 28 이하(늘면 실패).

## 7. 완료 기준
- 위 검증 1~5 통과.
- `/review` 지적 사항 처리.
- 커밋은 사용자 확인 후 `/push-safe` 절차(author loboking, AI 서명 없음).
