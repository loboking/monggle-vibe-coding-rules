# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [3.2.1] - 2026-05-15

### Changed 🔧

- **`/compact` 명령어 제거**
  - Claude Code 내장 compact 기능과 중복 제거
  - install.sh에서 compact 스킬 메타데이터 생성 제거

- **Auto-compact 자동 활성화 제거**
  - install.sh에서 설치 시 자동 활성화 로직 제거
  - 사용자가 직접 제어하도록 변경

### Added ✨

- **`/auto-compact` 스킬 추가**
  - `/auto-compact on`: auto-compact 활성화
  - `/auto-compact off`: auto-compact 비활성화
  - `/auto-compact status`: 현재 상태 확인
  - 80% 기준 (Claude Code 내장 설정과 동일)

- **`/verify` 스킬 추가** (AI 응답 검증 전용)
  - **읽기 전용** (Edit, Write 권한 제거)
  - 정확성, 안전성, 완결성, 실행성 4가지 카테고리 검증
  - `/verify "AI 응답"`: 전체 검증
  - `/verify --code`: 코드 구현 검증
  - `/verify --safety`: 보안 집중 검증
  - `/verify --duo`: Claude + Gemini 교차 검증

- **`/security` 스킬 추가** (보안성 검증 전용)
  - **읽기 전용** (Edit, Write 권한 제거)
  - OWASP Top 10 (2021) 기반 검증
  - STRIDE 위협 모델링 지원
  - `/security "코드"`: 전체 보안 검증
  - `/security --owasp`: OWASP 기반
  - `/security --stride`: 위협 모델링
  - `/security --auth`, `--sql`, `--xss`, `--crypto` 옵션

---

## [3.2.0] - 2026-05-14

### Added 🔥

- **사용자 편의성 고도화**
  - 자주 쓰는 기능 상단 배치
  - 직관적인 카테고리 분류
  - 예제 중심 설명

---

## [3.1.0] - 2026-05-13

### Added 🔧 업그레이드 시스템

- **`/monggle-upgrade` 스킬**
  - GitHub 원격 저장소에서 최신 버전 확인
  - 자동 업그레이드 (git pull + install.sh)
  - 24시간 체크 쓰로틀링 (너무 잦은 체크 방지)
  - `--check-only`: 확인만 하고 설치 안함
  - `--force`: 강제 업그레이드 체크

- **자동 업그레이드 체크**
  - `common.sh`에 `check_upgrade_available()` 함수 추가
  - 스킬 최초 실행시 자동 업그레이드 체크
  - 알림만 표시하고 사용자가 직접 업그레이드 결정
  - `UPGRADE_CHECK=false` 환경변수로 비활성화 가능

### Added 📦 자동 등록 강화

- **install.sh 개선**
  - `monggle-*.sh` 스킬들도 전역 자동 복사
  - `~/.claude/lib/` 디렉토리로 라이브러리 전역 복사
  - 모든 .sh 파일 실행 권한 자동 부여
  - 전역 하네스 파일 자동 설치

### Fixed 🐛 크로스플랫폼 호환성

- **macOS stat 명령어 호환성**
  - `platform.sh`의 `stat_mtime()` 함수로 해결
  - macOS: `stat -f "%m"` / Linux: `stat -c "%Y"`
  - 크로스플랫폼 QA 28개 테스트 전체 통과

### Changed 📝

- **`.claude/version` 파일 추가**
  - 버전 관리를 위한 별도 파일
  - 업그레이드 체크시 참조

---

## [3.0.0] - 2026-05-11

### Added 🧠 뇌 시스템 (Brain System) - 주요 업데이트

- **생체 모방 뇌 시스템 구현**
  - 해마 (Hippocampus): 단기 기억 (24시간 보관)
  - 대뇌피질 (Neocortex): 장기 기억 저장소
  - 시냅스 (Synapses): 뉴런 간 연결 & 강도 관리
  - 편도체 (Amygdala): 감정 가중치 (긴급도, 중요도)
  - 망각 곡선: 오래된 약한 기억 자동 삭제

- **뉴런 타입**
  - `decision`: 아키텍처/기술 결정
  - `pattern`: 코드 패턴/관용구
  - `bug`: 해결된 버그
  - `context`: 프로젝트 컨텍스트
  - `todo`: 작업 항목
  - `conversation`: 대화 요약

- **자동 학습 메커니즘**
  - 세션 시작: 컨텍스트 로드 (해마)
  - 세션 종료: 자동 고착화 (대뇌피질)
  - 시냅스 연결 및 감정 가중치 부여
  - 망각 곡선에 따른 자동 청소

- **Brain 커맨드**
  - `/brain`: 뇌 통계 보기
  - `/brain save <type> <title>`: 뉴런 수동 저장
  - `/brain query <tags>`: 태그로 검색
  - `/brain recall <id>`: 특정 뉴런 로드
  - `/brain link <src> <tgt>`: 시냅스 연결
  - `/brain cleanup`: 망각 청소

- **Hook 통합**
  - `SessionStart`: brain-session-start.sh (뇌 초기화 + 컨텍스트 로드)
  - `SessionEnd`: brain-session-end.sh (세션 저장 + 고착화)

### Added 🔀 스킬 통합 및 간소화 (Hybrid Commands)

- **통합 명령어 시스템**
  - `/debug [options]`: 통합 디버깅
    - `--web`: 프론트엔드 (JS, React)
    - `--css`: CSS 전용
    - `--perf`: 성능 병목
    - `--mem`: 메모리 누수
  - `/test [options]`: 통합 QA 테스트
    - `--report`: 보고서만 (수정 없음)
    - `--quick`: 빠른 스모크 테스트
  - `/review [options]`: 통합 리뷰
    - `--code`: 코드 품질 리뷰
    - `--arch`: 아키텍처 리뷰
  - `/msg`: 대화모드 (Message Mode)

- **스킬-뇌 통합**
  - 통합 명령어 실행 시 관련 기억 자동 검색
  - brain_query_by_tags로 컨텍스트 제공
  - 버그/패턴/결정 태그 자동 연결

- **하이브리드 호환성**
  - 통합 명령어와 기존 별칭 모두 지원
  - `/debug` = `/debug-master` (기본)
  - `/debug --web` = `/front-bugfix`
  - `/test` = `/qa`
  - `/review` = PR diff 리뷰

### Changed
- README 버전 3.0.0으로 업데이트
- settings.json에 뇌 시스템 설정 추가
- wrapper.sh에 brain 관련 명령어 추가
- wrapper.sh에 통합 명령어 처리 로직 추가 (_is_integrated_command, _exec_integrated_command)

### Files Added
- `.claude/brain/SPEC.md`: 뇌 시스템 명세서
- `.claude/brain/brain-core.sh`: 뇌 시스템 코어 라이브러리
- `.claude/hooks/brain-session-start.sh`: 세션 시작 훅
- `.claude/hooks/brain-session-end.sh`: 세션 종료 훅
- `.claude/commands/brain.sh`: 뇌 시스템 커맨드
- `.claude/commands/debug.sh`: 통합 디버깅 커맨드
- `.claude/commands/test.sh`: 통합 QA 커맨드
- `.claude/commands/review-integrated.sh`: 통합 리뷰 커맨드
- `.claude/commands/msg.sh`: 대화모드 커맨드
- `.vscode/settings.json`: VSCode 설정 (slashCommands)

---

## [2.6.0] - 2026-04-17

### Added
- **🤖 의도 기반 스킬 실행 시스템 (Intent-Based Skill Routing)**
  - 자연어 입력에서 의도(Intent)를 파악하여 자동 스킬 실행
  - 키워드 매칭이 아닌 의미 이해 기반 (Semantic Understanding)
  - 다국어 지원 (한국어, 영어)
  - 21개 의도-스킬 매핑 테이블
  - CLAUDE.md에 실행 프로세스 및 시나리오 예시 추가
  - README에 "의도 기반 스킬 실행" 섹션 추가

- **작업 관리 스킬 3개 추가**
  - `/save-point` - 세이브포인트: 작업 상태 저장/복구
    - Git 상태, 완료/진행 중/남은 작업, 결정 사항 저장
    - 브랜치 간 작업 전환 시 유용
  - `/arch-review` - 아키텍처 리뷰
    - 컴포넌트 분리, 데이터 흐름, 엣지 케이스 검토
    - 테스트 커버리지, 성능, 보안 체크
  - `/weekly-recap` - 주간 회고
    - 커밋 통계, 기여자 분석, 코드 품질 추이
    - 팀원별 칭찬 & 개선점

### Changed
- README 버전 배지 2.6.0으로 업데이트
- README.md, README_EN.md에 "의도 기반 스킬 실행" 섹션 추가
- "전체 명령어" 섹션에 "작업 관리" 카테고리 추가

---

## [2.5.1] - 2026-04-10

### Added
- **PRD 다국어 지원 확장** - 중국어(zh), 일본어(ja) 완전 지원
  - `scripts/prd_creator.py` 언어별 메시지 추가 (zh, ja)
  - PRD 섹션 이름 번역 (모든 PRD 타입)
  - 인터랙티브 언어 선택 프롬프트 (1=ko, 2=en, 3=zh, 4=ja)
  - `--language` 옵션으로 4개 언어 완전 지원
- **PRD 템플릿 디렉토리 구조** - `prd/templates/{ko,en,zh,ja}/`
- **12개 스킬 완전 구현** (README v2.4에 언급된 모든 스킬)

#### 코드 품질 스킬 (4개)
- `/lint-smart` - 프로젝트 자동 감지 후 린터 실행
  - Python: pylint, flake8, ruff, mypy
  - JavaScript/TypeScript: eslint, prettier, tsc
  - Go: gofmt, go vet, golangci-lint
  - Rust: cargo fmt, cargo clippy
  - Java: checkstyle, spotbugs, Android lint
  - Ruby: rubocop
- `/audit` - 보안 취약점 스캔 (bandit, semgrep)
- `/format-check` - 코드 포맷 검사 (black, prettier)
- `/complexity` - 복잡도 분석 (radon, lizard)

#### 문서 자동화 스킬 (4개)
- `/changelog` - Git 로그 → CHANGELOG.md 자동 생성
- `/bump` - 버전 업 + Git 태그 생성
- `/api-docs` - Docstring → API 문서 추출
- `/readme-sync` - README 동기화

#### 성능 분석 스킬 (4개)
- `/bottleneck` - 성능 병목 지점 분석
- `/profile` - 프로파일링 실행
- `/bench` - 벤치마크 실행/비교
- `/mem-check` - 메모리 누수 탐지

#### 공통 유틸리티
- `.claude/lib/common.sh` - 색상 출력, 로깅, 프로젝트 타입 감지
- `scripts/check_tools.py` - 필수 도구 설치 확인

### Changed
- README FAQ 다국어 지원 관련 답변 업데이트
- PRD Creator 버전 2.4 → 2.5

### Docs
- PRD 생성 가이드에 4개 언어 지원 명시
- 각 스킬 사용법 추가

---

## [2.5.0] - 2026-04-09

### Added
- **Git 협업 스킬 시스템** - 팀 개발을 위한 안전한 Git 동기화 및 충돌 해결
  - `/update` - 원격 저장소 안전 동기화
    - 자동 stash로 작업 안전 저장
    - git pull --rebase로 최신화
    - 충돌 발생 시 자동 rollback
    - `--auto`, `--dry-run` 옵션 지원
  - `/push-safe` - 안전한 전송 및 PR 자동 생성
    - 뒤처짐 감지 후 자동 `/update` 연동
    - GitHub/GitLab/Bitbucket PR 자동 생성
    - `--no-pr`, `--dry-run` 옵션 지원
  - **Git 공통 라이브러리** (`.claude/lib/git_helper.sh`)
    - Git 저장소 감지 (`is_git_repo`)
    - 변경사항 확인 (`has_uncommitted_changes`)
    - 뒤처짐/앞섬 확인 (`is_behind_origin`, `is_ahead_origin`)
    - 브랜치/원격 URL/호스트 감지
    - 충돌 파일/마커 감지
    - stash 자동화 (`git_safe_stash`, `git_safe_stash_pop`)
  - **PR 생성 라이브러리** (`.claude/lib/pr_helper.sh`)
    - GitHub PR 생성 (`create_github_pr`)
    - GitLab MR 생성 (`create_gitlab_pr`)
    - Bitbucket PR 생성 (`create_bitbucket_pr`)
    - 호스트 자동 감지 및 API 연동
  - **충돌 해결 가이드** (`.claude/lib/conflict_helper.sh`)
    - 충돌 원인 분석 (`analyze_conflict`)
    - 충돌 유형 분류 (같은 줄/인접 줄/함수)
    - 해결 옵션 (`resolve_keep`, `resolve_theirs`, `resolve_merge`)
    - 충돌 파일 목록 표시 (`show_conflict_files`)
  - **테스트 스위트** - 단위 테스트 + E2E 테스트
    - `tests/bash/git_helper.bats` - Git 공통 함수 (10개 케이스)
    - `tests/bash/update.bats` - 동기화 스크립트 (6개 케이스)
    - `tests/bash/push-safe.bats` - 전송 스크립트 (8개 케이스)
    - `tests/bash/conflict_helper.bats` - 충돌 해결 (6개 케이스)
    - `tests/bash/e2e_git_collaboration.bats` - E2E 테스트 (11개 시나리오)
  - **문서화**
    - `.claude/docs/git-collaboration.md` - Git 협업 가이드
    - `.claude/config/git.conf` - Git 설정 파일
    - `.claude/config/team.yaml` - 팀 협업 설정 (업데이트)

### Changed
- README v2.5 업데이트
  - Git 협업 스킬 섹션 추가
  - FAQ 팀 협업 관련 답변 업데이트
- 버전 배지 2.4 → 2.5

### Technical Details
- Bash 스크립트: update.sh, push-safe.sh
- 라이브러리: git_helper.sh (9개 함수), pr_helper.sh (7개 함수), conflict_helper.sh (7개 함수)
- 지원 Git 호스팅: GitHub, GitLab, Bitbucket
- 테스트 프레임워크: bats-core

---

## [2.4.2] - 2026-04-07

### Added
- **Initial Setup Wizard** (`/init`) - 1회 설정 후 저장
  - 작업 모드 선택 (solo/team)
  - PRD 언어 선택 (ko/en/zh/ja)
  - 기본 AI 모델 선택 (haiku/sonnet/opus)
  - 사용자 정보 (이름, 이메일)
  - 설정 저장 (`user.conf`) 및 재시작 시 자동 로드
- **Auto-improvement check after PRD creation** - PRD 생성 후 하네스 자동 체크
- **Harness Methodology Implementation** - Complete Doom Loop Detection + Auto-Improvement
  - `scripts/auto_improvement.py` - 통계 분석으로 개선 제안 자동 생성
  - `.harness/loop-detection.json` - 루프 탐지 데이터 저장소
  - `.harness/improvement-log.jsonl` - 개선 제안 로그
  - `.harness/HARNESS_COMPLETED.md` - 하네스 방법론 적용 완료 보고서
- `/harness` command - 하네스 메트릭 및 관리 도구
- Curl one-line installation method
- Auto-improvement check after pipeline completion
- **Multilingual PRD Output Support** - PRD 섹션 이름 다국어 지원
  - 한국어, 영어, 중국어, 일본어 섹션 번역
  - UI 메시지 다국어 지원
  - 언어 선택 프롬프트 (인터랙티브 모드, 미선택 시 영어 기본값)
  - `--language` 옵션 (ko, en, zh, ja)

### Changed
- Project renamed to "Vibe Coding Skills for Claude" (emphasizing team + skills)
- README optimized with SEO keywords
- Pipeline integration with auto-improvement system
- Only 100% supported features documented (no future/unimplemented features)

### Docs
- Harness methodology 4-quadrant framework (Guides + Sensors)
- "On the Loop" paradigm documentation
- Progressive Disclosure pattern

---

### Added
- `CONTRIBUTING.md` - 상세한 기여 가이드라인
- Project badges to README (License, Version, Claude Code compatible)

### Changed
- README reorganized for clarity (650 lines → 202 lines)
- Improved visual hierarchy with emojis and tables
- Consolidated command references
- Added pipeline ASCII diagram

### Removed
- Obsolete documentation files (8 files, 1,862 lines)
  - `docs/CODE_REVIEW_REPORT.md`
  - `AI_REVIEWER_IMPLEMENTATION.md`
  - `agents/agent_m_*.md` (6 files) - replaced by Python implementation

### Docs
- Link to CONTRIBUTING.md for collaboration details
- Improve Quick Start with 5-minute guide
- Add Overview section with core features table

---

## [2.4.0] - 2026-03-16

### Added
- 12 code quality/documentation/performance skills
  - `/lint-smart` - Auto-detect project linter
  - `/audit` - Security vulnerability scan
  - `/format-check` - Code format check
  - `/complexity` - Complexity analysis
  - `/changelog` - Auto-generate CHANGELOG from Git commits
  - `/bump` - Version up + tag creation
  - `/api-docs` - API documentation extraction
  - `/readme-sync` - README synchronization
  - `/bottleneck` - Performance bottleneck finder
  - `/profile` - Profiling
  - `/bench` - Benchmark execution/comparison
  - `/mem-check` - Memory leak detection
- PRD templates (5 types)
- Solo/Team modes
- Interactive PRD creation (`/init`)
- AI Reviewer system (Manual/Semi-Auto/Auto modes)

---

## [2.3.0] - 2026-02-24

### Added
- Interactive PRD creation (`/init` command)
- Natural language PRD generation
- Hotfix PRD template with fast-track pipeline

---

## [2.2.0] - 2026-02-19

### Added
- Solo/Team mode flexibility
- Fast track hotfix workflow (`/quick`)
- Auto pipeline based on PRD type
- Pipeline statistics (`/stats`)
- Single source of truth (`rules/core-rules.yaml`)

---

## [2.0.0] - 2025-02-19

### Added
- Full Agent Pipeline (Gate → Scan → Fold → Verdict → Patch → Trace)
- AI Reviewer system
- Verdict System (PASS/FIX/FAIL)
- PRD-based development methodology

---

## Links

- [GitHub Repository](https://github.com/loboking/monggle-vibe-coding-rules)
- [Contributing](CONTRIBUTING.md)

---

[2.4.1]: https://github.com/loboking/monggle-vibe-coding-rules/compare/v2.4.0...v2.4.1
[2.4.0]: https://github.com/loboking/monggle-vibe-coding-rules/compare/v2.3.0...v2.4.0
[2.3.0]: https://github.com/loboking/monggle-vibe-coding-rules/compare/v2.2.0...v2.3.0
[2.2.0]: https://github.com/loboking/monggle-vibe-coding-rules/compare/v2.0.0...v2.2.0
[2.0.0]: https://github.com/loboking/monggle-vibe-coding-rules/releases/tag/v2.0.0
