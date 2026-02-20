# Vibe Coding Rules

> **Agent 기반 Vibe Coding 방법론 - PRD 없이는 어떠한 개발 요청도 응답하지 않습니다.**
> **v2.2: Solo/Team Mode, Fast Track, Auto Pipeline, Stats, Single Source of Truth**

---

## Quick Start

```bash
# 1. 저장소 클론
git clone https://github.com/loboking/monggle-vibe-coding-rules.git
cd monggle-vibe-coding-rules

# 2. 설치 스크립트 실행 (원클릭 설치)
./install.sh

# 또는 기존 프로젝트에 설치
./install.sh /path/to/your-project

# 3. 모드 설정 (선택)
/mode                    # 현재 모드 확인
/mode solo               # Solo 모드 (PRD 선택적)
/mode team               # Team 모드 (PRD 필수)

# 4. PRD 작성
cp prd/feature.md prd/feature-my-task.md
# -> PRD 내용 작성

# 5. 실행
/pipeline prd/feature-my-task.md

# 긴급 수정의 경우
cp prd/hotfix.md prd/hotfix-urgent-fix.md
/quick prd/hotfix-urgent-fix.md
```

---

## What's New in v2.2

### 1. Solo/Team Mode (NEW)

Flexibility for different workflows:

| Mode | PRD Required | Use Case |
|------|--------------|----------|
| **Solo** | Optional | Personal projects, quick iterations |
| **Team** | Required | Team collaboration, quality assurance |

```bash
/mode solo               # Quick iterations allowed
/mode team               # PRD required for all dev work
```

### 2. Fast Track Hotfix (NEW)

Urgent bug fix workflow:

```bash
/quick [prd_file]        # Skip Fold agent, faster execution
```

**Hotfix PRD Template** (`prd/hotfix.md`):
- Minimal required sections
- Skip Fold agent (saves time)
- Focused on speed while maintaining quality

### 3. Auto Pipeline (NEW)

PRD type-based agent auto-selection:

```bash
# Automatically selects agents based on PRD type
/pipeline prd/feature-my-task.md
/pipeline prd/bugfix-login-error.md
/pipeline prd/hotfix-production-crash.md
```

**Pipeline by Type:**
| PRD Type | Pipeline |
|----------|----------|
| Feature/Bug/Refactor | Gate → Scan → Fold → Verdict → Patch → Trace |
| Hotfix | Gate → Scan → Verdict → Patch → Trace (Skip Fold) |
| Experiment | Gate → Scan → Fold → Verdict → Trace (Skip Patch) |

### 4. Pipeline Statistics (NEW)

Track your pipeline performance:

```bash
/stats                   # Show execution statistics
/stats --json            # JSON output
/stats --clear           # Clear all logs
```

**Statistics include:**
- Total runs, success rate
- Verdict distribution (PASS/FIX/FAIL)
- Agent performance (duration, success rate)
- Recent runs history

### 5. Single Source of Truth (NEW)

`rules/core-rules.yaml` is now the single source of truth:

```bash
# Sync all config files from core rules
python3 scripts/sync_rules.py

# Automatically updates:
# - .cursorrules (IDE rules)
# - CLAUDE.md (Project guidelines)
# - .claude/settings.json (Claude Code settings)
```

### 6. Free Chat Allowed (NEW)

**In Solo Mode:**
- Development requests WITHOUT PRD are allowed
- Quick iterations and experiments encouraged
- PRD still recommended for complex features

**In Team Mode:**
- Development requests require PRD
- Quality assurance through documentation

**PRD Exemptions (always allowed):**
- "explain X", "show me Y", "how does Z work"
- "review code", "analyze performance"
- "document X", "add comments"

---

## v2.0 Features (Existing)

### AI Reviewer System

**Automated code review powered by AI**

Three modes available:

| Mode | Description | Use Case |
|------|-------------|----------|
| **Manual** | Review only when `/review` command is used | Development phase, on-demand review |
| **Semi-Auto** | Auto-review on PR creation, merge requires admin approval | Team collaboration, quality gate |
| **Auto** | Auto-review + auto-merge if confidence >= threshold | Fully automated CI/CD |

**Setup:**
```bash
./install.sh              # Automatically configures AI reviewer
# Select mode during installation
# Creates .claude/config/team.yaml with your settings
```

**Usage:**
```bash
# Manual review (Claude Code AI-powered)
/review                   # Review current changes
/review path/to/file.py   # Review specific file
/review --staged          # Review staged changes
```

**Configuration:**
```yaml
# .claude/config/team.yaml
ai_reviewer:
  enabled: true
  mode: "semi-auto"       # manual | semi-auto | auto
  auto_merge_threshold: 0.9
  checks:
    - security
    - performance
    - best_practices
    - test_coverage
```

### Full Agent Pipeline

```
Gate -> Scan -> Fold -> Verdict -> Patch -> Trace
```

| Agent | 역할 | 상태 |
|-------|------|------|
| **Gate** | PRD 유효성 검사 | Hook |
| **Scan** | 코드베이스 영향 분석 | Python 구현 |
| **Fold** | 결과 종합 및 타당성 평가 | Python 구현 |
| **Verdict** | 최종 판단 (PASS/FIX/FAIL) | Python 구현 |
| **Patch** | 코드 생성/수정 | Python 구현 |
| **Trace** | 실행 로그 기록 | Python 구현 |

---

## Slash Commands

### Pipeline Commands

**`/pipeline`** - Execute full agent pipeline
```bash
/pipeline                    # Auto-detect PRD and execute
/pipeline prd/feature.md     # Execute with specific PRD
/pipeline --skip-gate        # Skip gate validation
```

**`/quick`** - Fast track for hotfixes
```bash
/quick                       # Auto-detect hotfix PRD
/quick prd/hotfix-fix.md     # Execute specific hotfix
```

**`/stats`** - Pipeline statistics
```bash
/stats                       # Show statistics
/stats --json                # JSON output
/stats --clear               # Clear logs
```

### Mode Commands

**`/mode`** - Project mode management
```bash
/mode                        # Show current mode
/mode solo                   # Switch to solo mode
/mode team                   # Switch to team mode
```

### Review Commands

**`/review`** - AI code review
```bash
/review                    # Current changes
/review path/to/file.py    # Specific file
/review --json             # JSON output
```

**`/gate`** - PRD validation
```bash
/gate                    # Auto-detect and validate
/gate prd/feature.md     # Validate specific file
```

**`/trace`** - Log viewer
```bash
/trace                    # Latest log
/trace --list             # All logs
```

---

## Project Structure

```
project-root/
├── CLAUDE.md                # Claude Code 규칙 (auto-synced)
├── .cursorrules             # IDE 규칙 (auto-synced)
├── monggle.config.yaml      # 프로젝트 모드 설정
├── install.sh               # 원클릭 설치 스크립트
├── .claude/
│   ├── hooks/
│   │   └── pre-tool-use.sh  # PRD 검증 훅 (mode-aware)
│   ├── commands/
│   │   ├── pipeline.sh      # /pipeline 명령어
│   │   ├── quick.sh         # /quick 명령어 (hotfix)
│   │   ├── stats.sh         # /stats 명령어
│   │   ├── mode.sh          # /mode 명령어
│   │   ├── gate.sh          # /gate 명령어
│   │   ├── trace.sh         # /trace 명령어
│   │   └── review.sh        # /review 명령어
│   └── settings.json        # 자동 생성 (수정 금지)
├── agents/                  # Agent 구현 (Python)
│   ├── base_agent.py        # 기본 클래스
│   ├── pipeline_config.py   # 파이프라인 설정 (NEW)
│   ├── scan_agent.py        # Scan Agent
│   ├── fold_agent.py        # Fold Agent
│   ├── verdict_agent.py     # Verdict Agent (FIX feedback)
│   ├── patch_agent.py       # Patch Agent
│   └── trace_agent.py       # Trace Agent
├── scripts/
│   ├── init_core.py         # 프로젝트 초기화
│   ├── sync_rules.py        # 규칙 동기화 (NEW)
│   ├── stats.py             # 통계 수집 (NEW)
│   └── run_agent.py         # Agent 실행 CLI
├── rules/
│   └── core-rules.yaml      # Single Source of Truth (NEW)
├── prd/                     # PRD 템플릿
│   ├── feature.md           # Feature PRD
│   ├── bug.md               # Bug PRD
│   ├── refactor.md          # Refactor PRD
│   ├── hotfix.md            # Hotfix PRD (NEW)
│   └── experiment.md        # Experiment PRD
├── tests/                   # 단위 테스트
│   └── test_agents.py
├── example-project/         # 예제 프로젝트 (NEW)
│   ├── prd/
│   │   ├── todo-feature.md
│   │   └── hotfix-button-crash.md
│   └── ...
└── logs/                    # 실행 로그
```

---

## PRD Types

| 타입 | 템플릿 | 용도 | Pipeline |
|------|--------|------|----------|
| **Feature** | `prd/feature.md` | 새로운 기능 개발 | Full |
| **Bugfix** | `prd/bug.md` | 버그 수정 | Full |
| **Refactor** | `prd/refactor.md` | 코드 리팩토링 | Full |
| **Hotfix** | `prd/hotfix.md` | 긴급 수정 | Fast Track |
| **Experiment** | `prd/experiment.md` | 실험적 기능 | No Patch |

```bash
cp prd/feature.md prd/feature-user-auth.md
cp prd/hotfix.md prd/hotfix-login-crash.md
```

---

## Verdict System

### PASS (진행)

**조건:**
- Gate: PASS (PRD 유효)
- Scan: 복잡도 Medium 이하, 충돌 없음
- Fold: 구현 가능성 High 이상

**결과:** 즉시 구현 시작

### FIX (수정 필요) - Enhanced

**조건:**
- 일부 섹션 누락/불완전
- 해결 가능한 문제

**결과:**
- PRD 수정 후 재검토
- **자동 수정 제안 제공** (NEW)

### FAIL (불가능)

**조건:**
- Gate: FAIL (PRD 무효)
- 해결 불가능한 차단 문제

**결과:** 요구사항 재검토

---

## Free Chat Rules

### Solo Mode

**Allowed without PRD:**
- Quick fixes and iterations
- Experiments and prototypes
- Code reviews and analysis
- Documentation

**PRD Recommended for:**
- Complex features
- Breaking changes
- Team collaborations

### Team Mode

**PRD Required for:**
- All development work
- Code modifications
- Feature implementations

**Exemptions (always allowed):**
- "explain X", "show me Y"
- "review code", "analyze performance"
- "document X", "add comments"

---

## Core Principles

1. **PRD 먼저** - 코딩 전에 PRD 작성 (Team 모드)
2. **Agent 파이프라인** - 모든 작업은 Agent 검증을 거침
3. **AI가 검증** - 리뷰/검증/판단은 AI가 담당
4. **개발자는 집중** - 구현과 창의성에만 집중
5. **자유로운 실험** - Solo 모드에서 빠른 반복

---

## Example Project

See `example-project/` for a working example:

```bash
cd example-project

# View PRD
cat prd/todo-feature.md
cat prd/hotfix-button-crash.md

# Run pipeline
../scripts/run_agent.py prd/todo-feature.md
../scripts/run_agent.py prd/hotfix-button-crash.md --type hotfix --skip-fold
```

---

## TDD (Test-Driven Development)

이 프로젝트는 **TDD(Test-Driven Development)**를 따릅니다.

### Running Tests

```bash
# 전체 테스트 실행
python3 -m unittest discover tests/

# 특정 테스트 파일
python3 tests/test_agents.py

# 상세 출력
python3 -m unittest tests.test_agents -v
```

### Test Coverage Requirements

| 단계 | 커버리지 | 차단 여부 |
|------|----------|----------|
| 개인 브랜치 | 80%+ 권장 | No |
| PR 생성 | 80%+ 필수 | Yes |
| Main Merge | Full 필수 | Yes |

---

## FAQ

**Q: Solo 모드와 Team 모드의 차이는?**
A:
- **Solo**: PRD 선택적, 빠른 반복 가능
- **Team**: PRD 필수, 품질 보장

**Q: Hotfix는 언제 사용하나요?**
A: 프로덕션 서비스 중단, 데이터 손실 위험, 보안 취약점 등 긴급 상황에만 사용하세요.

**Q: /quick와 /pipeline의 차이는?**
A:
- `/quick`: Fold agent 건너뛰기, hotfix용
- `/pipeline`: 전체 파이프라인, 일반 작업용

**Q: 통계는 어떻게 확인하나요?**
A: `/stats` 명령어로 파이프라인 실행 통계를 확인할 수 있습니다.

**Q: 규칙을 동기화하려면?**
A: `python3 scripts/sync_rules.py`를 실행하세요.

**Q: Python 3.8 미만에서는?**
A: Bash fallback 모드로 제한된 기능을 제공합니다.

**Q: API 키가 필요한가요?**
A: 아니요! **API 키가 전혀 필요 없습니다.**

---

## Contributing

기여를 환영합니다!

1. 포크합니다
2. PRD 작성 (`prd/feature-*.md`)
3. 기능 브랜치 생성
4. PR 생성 (PRD 링크 포함)

---

## License

MIT License

---

**Vibe Coding Rules v2.2** (Solo/Team Mode, Fast Track, Auto Pipeline, Stats)
