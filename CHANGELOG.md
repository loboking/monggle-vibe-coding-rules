# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
