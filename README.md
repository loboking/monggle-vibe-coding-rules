# Vibe Coding Rules

> **Agent 기반 Vibe Coding 방법론 - PRD 없이는 어떠한 개발 요청도 응답하지 않습니다.**

---

## 🚀 Quick Start

```bash
# 1. 저장소 클론
git clone https://github.com/loboking/monggle-vibe-coding-rules.git
cd monggle-vibe-coding-rules

# 2. 파일 복사 (기존 프로젝트인 경우)
cp -r .claude/ /path/to/your-project/
cp -r agents/ /path/to/your-project/
cp -r prd/ /path/to/your-project/
cp -r rules/ /path/to/your-project/
cp CLAUDE.md /path/to/your-project/

# 3. PRD 작성
cp prd/feature.md prd/feature-my-task.md
# -> PRD 내용 작성

# 4. 실행
/gate prd/feature-my-task.md
/pipeline prd/feature-my-task.md
```

---

## 🎯 MVP v1.0 Features

### 1. Pre-Tool Hook

파일 수정 전 PRD를 자동으로 검증:

- ✅ PRD 파일 존재 확인
- ✅ YAML frontmatter 검증
- ✅ 필수 섹션 검증 (타입별)
- ✅ 컬러 콘솔 출력

### 2. 슬래시 커맨드

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
/trace --tail             # 실시간 로그
```

### 3. Example Project

실제 작동하는 To-Do 리스트 앱:
- `example-project/` - 완전한 예시 프로젝트
- HTML + CSS + JavaScript
- LocalStorage 기반 CRUD

### 4. 구조

```
.claude/
├── hooks/
│   └── pre-tool-use.sh    # PRD 검증 훅
├── commands/
│   ├── gate.sh            # /gate 명령어
│   ├── pipeline.sh        # /pipeline 명령어
│   └── trace.sh           # /trace 명령어
└── settings.json

agents/                     # 에이전트 정의
prd/                        # PRD 템플릿 (feature, bug, refactor, experiment)
rules/                      # 에이전트 규칙
example-project/            # 예시 프로젝트
logs/                       # 실행 로그
```

---

## 🤖 Agent Pipeline

```
Gate → Scan → Fold → Verdict → Patch → Trace
```

| Agent | 역할 | 출력 |
|-------|------|------|
| **Gate** | PRD 유효성 검사 | PASS/FAIL |
| **Scan** | 코드베이스 영향 분석 | 영향 파일, 의존성 |
| **Fold** | 결과 종합 및 타당성 평가 | 실행 가능성, 위험도 |
| **Verdict** | 최종 판단 | PASS/FIX/FAIL |
| **Patch** | 코드 생성/수정 | 구현된 코드 |
| **Trace** | 실행 로그 기록 | 타임라인, 성능 지표 |

---

## 📋 PRD Types

### 프로젝트 설정 파일

프로젝트 시작 시 1회 작성:
- 프로젝트 개요, 기술 스택
- Git/CI/CD 설정

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

## ❌ Free Chat Prohibition

### PRD 없는 요청 (응답 거부)
```
사용자: "로그인 기능 추가해줘"
AI: "❌ PRD가 없습니다. 먼저 prd/feature-*.md를 작성해주세요."
```

### PRD 있는 요청 (정상 응답)
```
사용자: "prd/feature-user-auth.md 구현해줘"
AI: "✅ Agent 파이프라인을 시작합니다..."
```

---

## 📦 File Structure

```
project-root/
├── CLAUDE.md                # Claude Code 규칙
├── .cursorrules             # Cursor IDE 규칙
├── .claude/
│   ├── hooks/               # PRD 검증 훅
│   └── commands/            # 슬래시 커맨드
├── agents/                  # 에이전트 정의 (6개)
├── prd/                     # PRD 템플릿 (4개)
├── rules/                   # 에이전트 규칙
├── logs/                    # 실행 로그
└── example-project/         # 예시 프로젝트
```

---

## 📋 Core Principles

1. **PRD 먼저** - 코딩 전에 반드시 PRD 작성
2. **Agent 파이프라인** - 모든 작업은 Agent 검증을 거침
3. **AI가 검증** - 리뷰/검증/판단은 AI가 담당
4. **개발자는 집중** - 구현과 창의성에만 집중

---

## 💡 FAQ

**Q: PRD 없이 개발할 수 없나요?**
A: 네, PRD 없이는 AI가 응답하지 않습니다.

**Q: 기존 프로젝트에도 적용 가능한가요?**
A: 넵! `.claude/`, `agents/`, `prd/`, `rules/` 폴더만 복사하면 됩니다.

**Q: CI/CD는 필수인가요?**
A: 아니요. `ci_cd_provider`를 비워두면 설정되지 않습니다.

**Q: Agent 파이프라인을 직접 실행해야 하나요?**
A: 아니요! `/pipeline` 명령어로 실행하면 됩니다.

---

## 🤝 Contributing

기여를 환영합니다!

1. 포크합니다
2. PRD 작성 (`prd/feature-*.md`)
3. 기능 브랜치 생성
4. PR 생성 (PRD 링크 포함)

---

## 📄 License

MIT License

---

**Vibe Coding Rules v2.0 (MVP v1.0)**
