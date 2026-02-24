# Vibe Coding Rules

> **Agent 기반 Vibe Coding 방법론 - PRD 없이는 어떠한 개발 요청도 응답하지 않습니다.**
> **v2.3: Interactive PRD Creation (/init), Natural Language PRD Generation**

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

# 4. PRD 작성 (대화형 또는 수동)

## 방법 A: 대화형 PRD 생성 (추천)
/init feature            # Claude Code가 질문하며 PRD 작성
# 또는 그냥 설명하면 자동으로 타입 감지
/init
# -> "이메일 로그인 기능 추가해줘"

## 방법 B: 수동 PRD 작성
cp prd/feature.md prd/feature-my-task.md
# -> 에디터로 직접 작성

# 5. 실행
/pipeline prd/feature-my-task.md

# 긴급 수정의 경우
/init hotfix             # 대화형 hotfix PRD 생성
# 또는
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

### PRD Creation Commands

**`/init`** - Interactive PRD creation (NEW v2.3)
```bash
/init                    # Auto-detect type from description
/init feature            # Create feature PRD
/init bug                # Create bug fix PRD
/init refactor           # Create refactor PRD
/init hotfix             # Create hotfix PRD (fast track)
/init experiment         # Create experiment PRD
```

**How it works:**
1. Claude Code asks you questions based on PRD type
2. You answer in natural language
3. PRD is automatically generated
4. You can review and proceed with `/pipeline`

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

## Usage Examples

### Example 1: User Authentication (Feature)

```bash
# Step 1: Start interactive PRD creation
/init feature

# Claude Code will ask:
📝 Feature Name?
> 이메일 로그인 기능

📝 What problem does this solve?
> 사용자가 이메일과 비밀번호로 로그인할 수 있게 해요

📝 What are the functional requirements?
> - 이메일 형식 검증
> - 비밀번호 8자 이상
> - 로그인 상태 유지 (JWT)
> - 비밀번호 찾기 기능

📝 What edge cases should we handle?
> - 중복 이메일 가입 방지
> - 비밀번호 재설정 링크 24시간 유효
> - 로그인 5회 실패 시 계정 잠금

📝 How should we test this?
> - 단위 테스트: 이메일 검증, 비밀번호 암호화
> - 통합 테스트: 로그인 flow, 토큰 발급

# Step 2: PRD automatically generated
✅ PRD created: prd/feature-email-login-20250224-143022.md

# Step 3: Review and proceed
Would you like to:
1) Proceed with pipeline
2) Edit PRD first
3) Start over
> 1

# Step 4: Pipeline executes automatically
/pipeline prd/feature-email-login-20250224-143022.md
```

### Example 2: Login Button Crash (Hotfix)

```bash
# Step 1: Describe the issue
/init hotfix

# Claude Code will ask:
📝 What's the urgent problem?
> 로그인 버튼 클릭 시 앱이 크래시돼요. 프로덕션에서 발생하고 있어요.

📝 What's the immediate fix?
> 버튼 onClick 핸들러가 null 체크 없이 호출되고 있어요.
> null 체크를 추가해야 해요.

📝 Quick verification steps?
> - 로그인 버튼 클릭 시 앱 크래시 없어야 함
> - 로그인 성공 시 정상적으로 홈 화면으로 이동

# Step 2: PRD generated for hotfix
✅ PRD created: prd/hotfix-login-button-crash-20250224-143545.md

# Step 3: Fast track execution (skips Fold agent)
/quick prd/hotfix-login-button-crash-20250224-143545.md
```

### Example 3: Code Refactoring (Refactor)

```bash
/init refactor

📝 What's the current state?
> UserService에 500줄이 넘는 코드가 있어요. 모든 로직이 한 클래스에 있어요.

📝 What problems exist?
> - 테스트하기 어려움
> - 코드 중복이 많음
> - 새 기능 추가 시 버그 발생

📝 What changes do you want?
> - 비즈니스 로직을 서비스 계층으로 분리
> - 데이터베이스 작업을 Repository로 분리
> - 유효성 검증을 Validator로 분리

📝 What impact will this have?
> - API 동작은 변화 없음
> - 기존 테스트는 모두 통과해야 함
> - 성능은 유지되거나 개선되어야 함

📝 How to ensure nothing breaks?
> - 통합 테스트 실행
> - E2E 테스트 실행
> - 성능 테스트 실행

✅ PRD created: prd/refactor-user-service-20250224-144218.md
```

### Example 4: Natural Language Request (Auto-detect)

```bash
# Just describe what you want
/init

📝 Please describe what you want to build:
> 결제 시스템에 카카오페이를 추가하고 싶어요. 기존 신용카드 결제는 그대로 유지하면서 새로운 결제 수단을 추가해야 해요.

✅ Detected type: feature
✅ PRD created: prd/feature-kakao-pay-20250224-144500.md
```

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

**Q: /init로 PRD를 만들면 바로 실행되나요?**
A: 아니요, PRD가 생성된 후 내용을 확인하고 수정할 수 있습니다. 준비가 되면 `/pipeline`으로 실행하세요.

**Q: 이미 작성한 PRD 파일이 있어도 되나요?**
A: 너! `cp prd/feature.md prd/my-feature.md`로 템플릿을 복사해서 직접 작성하셔도 됩니다.

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

**Vibe Coding Rules v2.3** (Interactive PRD Creation, Natural Language PRD)
