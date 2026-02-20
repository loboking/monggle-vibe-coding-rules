# Vibe Coding Rules

> **Agent 기반 Vibe Coding 방법론 - PRD 없이는 어떠한 개발 요청도 응답하지 않습니다.**

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

# 3. PRD 작성
cp prd/feature.md prd/feature-my-task.md
# -> PRD 내용 작성

# 4. 실행
/pipeline prd/feature-my-task.md
```

---

## v2.0 Features

### 0. AI Reviewer System

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
# Manual review
/review                   # Review current changes
/review path/to/file.py   # Review specific file
/review --json            # Output as JSON
```

**Configuration:**
```yaml
# .claude/config/team.yaml
ai_reviewer:
  enabled: true
  mode: "semi-auto"       # manual | semi-auto | auto
  provider: "rule-based"  # API-free, rule-based review
  auto_merge_threshold: 0.9
  checks:
    - security
    - performance
    - best_practices
    - test_coverage
```

**CI/CD Integration:**
- **GitHub**: Automatically creates `.github/workflows/ai-reviewer.yml`
- **GitLab**: Updates `.gitlab-ci.yml` with AI reviewer
- Detects platform from `git remote origin.url`

**Features:**
- Security vulnerability detection
- Performance issue identification
- Best practices validation
- Test coverage analysis
- Documentation completeness check
- Error handling pattern review

---

### 1. One-Click Installation

### 1. One-Click Installation

```bash
./install.sh              # 현재 디렉토리에 설치
./install.sh /path/to/project  # 특정 프로젝트에 설치
```

설치 과정:
- Python 3.8+ 자동 감지
- settings.json 동적 생성
- 실행 권한 자동 설정
- 필수 디렉토리 생성

### 2. Dynamic Path Resolution

절대 경로 하드코딩 문제 해결:
- `scripts/generate_settings.py` - settings.json 동적 생성
- `install.sh` - 경로 자동 감지
- 타인이 클론해도 바로 작동

### 3. Full Agent Pipeline

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

### 4. Python 3.8+ Compatible

모든 Python 코드는 3.8+에서 실행 가능:
- `pathlib.Path` 사용
- `typing` 모듈 활용
- 3.13 전용 문법 배제

### 5. Slash Commands

**`/review`** - AI 코드 리뷰
```bash
/review                    # 현재 변경사항 리뷰
/review path/to/file.py    # 특정 파일 리뷰
/review --json             # JSON 출력
```

**`/gate`** - PRD 검증
```bash
/gate                    # 자동 감지 및 검증
/gate prd/feature.md     # 특정 파일 검증
```

**`/pipeline`** - 전체 에이전트 파이프라인 실행
```bash
/pipeline                    # 전체 파이프라인 실행
/pipeline prd/feature.md     # 특정 PRD로 실행
/pipeline --dry-run          # 계획만 표시
```

**`/trace`** - 로그 뷰어
```bash
/trace                    # 최신 로그
/trace --list             # 모든 로그 목록
```

---

## Project Structure

```
project-root/
├── CLAUDE.md                # Claude Code 규칙
├── install.sh               # 원클릭 설치 스크립트
├── .claude/
│   ├── config/
│   │   └── team.yaml        # AI Reviewer 설정 (자동 생성)
│   ├── hooks/
│   │   └── pre-tool-use.sh  # PRD 검증 훅
│   ├── commands/
│   │   ├── gate.sh          # /gate 명령어
│   │   ├── pipeline.sh      # /pipeline 명령어
│   │   ├── trace.sh         # /trace 명령어
│   │   └── review.sh        # /review 명령어 (AI Reviewer)
│   ├── scripts/
│   │   └── ai_reviewer.py   # AI Reviewer 엔진
│   ├── settings.json        # 자동 생성 (수정 금지)
│   └── settings.json.template
├── .github/workflows/
│   └── ai-reviewer.yml      # GitHub Actions AI Reviewer
├── agents/                  # Agent 구현 (Python)
│   ├── base_agent.py        # 기본 클래스
│   ├── scan_agent.py        # Scan Agent
│   ├── fold_agent.py        # Fold Agent
│   ├── verdict_agent.py     # Verdict Agent
│   ├── patch_agent.py       # Patch Agent
│   └── trace_agent.py       # Trace Agent
├── scripts/
│   ├── init_core.py         # 프로젝트 초기화
│   ├── generate_settings.py # settings.json 생성
│   └── run_agent.py         # Agent 실행 CLI
├── prd/                     # PRD 템플릿
│   ├── feature.md           # Feature PRD
│   ├── bug.md               # Bug PRD
│   ├── refactor.md          # Refactor PRD
│   └── experiment.md        # Experiment PRD
├── rules/                   # Agent 규칙
├── tests/                   # 단위 테스트
│   └── test_agents.py
└── logs/                    # 실행 로그
```

---

## PRD Types

### 작업 PRD

개별 작업 시 마다 작성:

| 타입 | 템플릿 | 용도 |
|------|--------|------|
| **Feature** | `prd/feature.md` | 새로운 기능 개발 |
| **Bugfix** | `prd/bug.md` | 버그 수정 |
| **Refactor** | `prd/refactor.md` | 코드 리팩토링 |
| **Experiment** | `prd/experiment.md` | 실험적 기능 |

```bash
cp prd/feature.md prd/feature-user-auth.md
# -> PRD 내용 작성
```

---

## Verdict System

### PASS (진행)

**조건:**
- Gate: PASS (PRD 유효)
- Scan: 복잡도 Medium 이하, 충돌 없음
- Fold: 구현 가능성 High 이상

**결과:** 즉시 구현 시작

### FIX (수정 필요)

**조건:**
- 일부 섹션 누락/불완전
- 해결 가능한 문제

**결과:** PRD 수정 후 재검토

### FAIL (불가능)

**조건:**
- Gate: FAIL (PRD 무효)
- 해결 불가능한 차단 문제

**결과:** 요구사항 재검토

---

## Free Chat Prohibition

### PRD 없는 요청 (응답 거부)
```
사용자: "로그인 기능 추가해줘"
AI: "PRD가 없습니다. 먼저 prd/feature-*.md를 작성해주세요."
```

### PRD 있는 요청 (정상 응답)
```
사용자: "prd/feature-user-auth.md 구현해줘"
AI: "Agent 파이프라인을 시작합니다..."
```

---

## Core Principles

1. **PRD 먼저** - 코딩 전에 반드시 PRD 작성
2. **Agent 파이블라인** - 모든 작업은 Agent 검증을 거침
3. **AI가 검증** - 리뷰/검증/판단은 AI가 담당
4. **개발자는 집중** - 구현과 창의성에만 집중
5. **자유로운 실험** - 개인 브랜치에서 마음껏

---

## TDD (Test-Driven Development)

이 프로젝트는 **TDD(Test-Driven Development)**를 따릅니다.

### Red-Green-Refactor Cycle

```
┌─────────────────────────────────────────────────────────────────┐
│  RED          GREEN          REFACTOR                           │
│  실패하는      최소한의        코드 품질                          │
│  테스트 작성   구현으로         개선                               │
│              통과하게                                              │
└─────────────────────────────────────────────────────────────────┘
```

### Running Tests

```bash
# 전체 테스트 실행
python3 -m unittest discover tests/

# 특정 테스트 파일
python3 tests/test_agents.py

# 상세 출력
python3 -m unittest tests.test_agents -v

# 특정 테스트 케이스만
python3 -m unittest tests.test_agents.TestScanAgent.test_scan_complexity
```

### Test Categories

| 타입 | 설명 | 예시 |
|------|------|------|
| **Unit Tests** | 개별 컴포넌트 테스트 | PRD 파싱, YAML 검증 |
| **Integration Tests** | 전체 워크플로우 테스트 | 초기화부터 생성까지 |
| **Error Tests** | 예외 상황 테스트 | 누락된 PRD, 잘못된 형식 |

### Test Coverage Requirements

| 단계 | 커버리지 | 차단 여부 |
|------|----------|----------|
| 개인 브랜치 | 80%+ 권장 | No |
| PR 생성 | 80%+ 필수 | Yes |
| Main Merge | Full 필수 | Yes |

### Test Naming Convention

```python
# 테스트 파일: test_<모듈>.py
test_agents.py
test_init_core.py

# 테스트 클래스: Test<기능>
TestScanAgent
TestPRDParsing

# 테스트 메서드: test_<기능>_<상황>
def test_scan_complexity_medium(self):
def test_parse_valid_prd(self):
def test_error_missing_file(self):
```

### Testing

```bash
# 단위 테스트 실행
python3 tests/test_agents.py

# Agent 직접 실행
python3 agents/scan_agent.py prd/feature.md
python3 agents/fold_agent.py prd/feature.md
python3 agents/verdict_agent.py prd/feature.md

# 파이프라인 실행
python3 scripts/run_agent.py prd/feature.md
```

---

## FAQ

**Q: PRD 없이 개발할 수 없나요?**
A: 네, PRD 없이는 AI가 응답하지 않습니다.

**Q: 기존 프로젝트에도 적용 가능한가요?**
A: 넵! `./install.sh /path/to/project`로 설치하세요.

**Q: Python 3.8 미만에서는?**
A: Bash fallback 모드로 제한된 기능을 제공합니다.

**Q: settings.json을 직접 수정해도 되나요?**
A: 아니요. `scripts/generate_settings.py`를 다시 실행하세요.

**Q: AI Reviewer는 어떤 모드를 선택해야 하나요?**
A:
- **개발初期**: Manual 모드 (on-demand 리뷰)
- **팀 프로젝트**: Semi-Auto 모드 (자동 리뷰 + 승인 필요)
- **완전 자동화**: Auto 모드 (높은 신뢰도 시 자동 머지)

**Q: AI Reviewer가 필요한가요?**
A: 선택사항입니다. 설치 시 "1" (Manual)을 선택하면 `/review` 명령어로만 사용 가능합니다.

**Q: GitHub/GitLab이 아닌 곳에서도 사용 가능한가요?**
A: 네, AI Reviewer는 범용 솔루션입니다. `git remote`가 없어도 동작합니다.

**Q: API 키가 필요한가요?**
A: 아니요! **API 키가 전혀 필요 없습니다.**
- **로컬**: Claude Code 내장 기능 사용 (무료)
- **CI/CD**: Rule-based 검사 (무료)
- **AI 리뷰**: `/review` 명령어로 Claude Code가 직접 리뷰

**Q: TDD는 필수인가요?**
A: 네, 개발 프로세스의 핵심입니다. Red-Green-Refactor 사이클을 따라주세요:
1. **RED**: 실패하는 테스트 작성
2. **GREEN**: 최소한의 코드로 통과
3. **REFACTOR**: 코드 품질 개선

**Q: 테스트 커버리지 기준은?**
A:
- 개인 브랜치: 80%+ 권장
- PR 생성: 80%+ 필수 (CI에서 차단)
- Main Merge: Full 커버리지 필수

**Q: 어떤 테스트 프레임워크를 사용하나요?**
A: Python `unittest` 표준 라이브러리를 사용합니다.

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

**Vibe Coding Rules v2.1** (with AI Reviewer)
