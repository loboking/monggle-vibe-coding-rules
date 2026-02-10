# Vibe Coding Rules

> **Agent 기반 Vibe Coding 방법론 - PRD 없이는 어떠한 개발 요청도 응답하지 않습니다.**

## Table of Contents

- [Quick Start](#-quick-start)
- [Agent Pipeline](#-agent-pipeline)
- [PRD Types](#-prd-types)
- [File Structure](#-file-structure)
- [Core Principles](#-core-principles)
- [Branching Strategy](#-branching-strategy)
- [Workflow](#-workflow)
- [Usage Examples](#-usage-examples)
- [FAQ](#-faq)
- [Related Projects](#-related-projects)

---

## 🚀 Quick Start

> ⚠️ **PRD 없이는 어떠한 개발 요청도 응답하지 않습니다.**

### 1단계: 프로젝트 PRD 작성 (최초 1회)

```bash
# 저장소 클론
git clone https://github.com/loboking/monggle-vibe-coding-rules.git
cd monggle-vibe-coding-rules

# 프로젝트 PRD 템플릿 복사
cp scripts/templates/prd.md.template my-project-prd.md

# 프로젝트 PRD 파일에 프로젝트 정보 입력
# - 프로젝트 이름, 설명
# - 기술 스택 (언어, 프레임워크)
# - Git 설정 (remote URL, default branch)
# - CI/CD 설정 (선택)
```

### 2단계: 프로젝트 초기화

```bash
# 초기화 스크립트 실행
python3 scripts/init_core.py my-project-prd.md
```

**초기화 내용:**
- ✅ 프로젝트 정보 설정
- ✅ Git 설정 (user, email)
- ✅ CI/CD 워크플로우 초기화
- ✅ CLAUDE.md, .cursorrules 설정
- ✅ 초기 커밋 생성

### 3단계: 작업 PRD 작성 (각 작업마다)

```bash
# 템플릿 선택 및 복사
cp prd/feature.md prd/feature-user-auth-20250209.md      # 새로운 기능
cp prd/bug.md prd/bugfix-login-error-20250209.md          # 버그 수정
cp prd/refactor.md prd/refactor-auth-module-20250209.md   # 리팩토링
cp prd/experiment.md prd/experiment-ai-recommend-20250209.md  # 실험

# PRD 내용 작성 (YAML frontmatter + 마크다운 본문)
vim prd/feature-user-auth-20250209.md
```

### 4단계: Claude Code에 요청

```bash
# Claude Code에서 PRD 파일 경로로 요청
"prd/feature-user-auth-20250209.md 구현해줘"
```

AI가 **Agent 파이프라인**을 실행하여 자동으로 구현합니다.

---

## 🤖 Agent Pipeline

모든 개발 작업은 다음 Agent 파이프라인을 거칩니다:

```
Gate → Scan → Fold → Verdict → Patch → Trace
```

| Agent | 역할 | 출력 |
|-------|------|------|
| **Gate** | PRD 유효성 검사 | PASS/FAIL (필수 섹션 확인) |
| **Scan** | 코드베이스 영향 분석 | 영향받는 파일, 의존성, 충돌 |
| **Fold** | 결과 종합 및 타당성 평가 | 실행 가능성, 위험도, 접근 방식 |
| **Verdict** | 최종 판단 | PASS/FIX/FAIL + 피드백 |
| **Patch** | 코드 생성/수정 (최대 5회 반복) | 구현된 코드, 커밋 메시지 |
| **Trace** | 실행 로그 기록 | 타임라인, 성능 지표, 개선 권장사항 |

### Verdict 기준

- **PASS**: 바로 구현 진행
  - Gate: PASS
  - 복잡도: Medium 이하
  - 실행 가능성: High 이상
- **FIX**: 수정 후 재검토
  - 일부 섹션 누락/불완전
  - 해결 가능한 문제
- **FAIL**: 불가능한 작업
  - Gate: FAIL
  - 복잡도: Too High
  - 해결 불가능한 차단 문제

---

## 📋 PRD Types

### 1. 프로젝트 PRD (`.project-prd.md`)

프로젝트 시작 시 **1회성**으로 작성합니다.

**용도:**
- 프로젝트 개요 정의
- 기술 스택 설정
- Git/CI/CD 초기화

**생성:**
```bash
python3 scripts/init_core.py my-project-prd.md
```

### 2. 작업 PRD (`prd/feature-*.md`, `prd/bug-*.md`, 등)

개별 기능/버그/리팩토링 작업 시 작성합니다.

**타입별 용도:**

| 타입 | 템플릿 | 용도 | 예시 |
|------|--------|------|------|
| **Feature** | `prd/feature.md` | 새로운 기능 개발 | 사용자 인증, 결제 시스템 |
| **Bugfix** | `prd/bug.md` | 버그 수정 | 로그인 에러, 데이터 손실 |
| **Refactor** | `prd/refactor.md` | 코드 리팩토링 | 인증 모듈 분리, DB 쿼리 최적화 |
| **Experiment** | `prd/experiment.md` | 실험적 기능 시도 | AI 추천 시스템 A/B 테스트 |

**생성:**
```bash
cp prd/feature.md prd/feature-user-auth-20250209.md
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
AI: "✅ Agent 파이프라인을 시작합니다...
     Gate: ✅ PASS
     Scan: ✅ 영향 파일 3개
     Fold: ✅ 실행 가능성 High
     Verdict: ✅ PASS (confidence: 0.95)
     Patch: ✅ 3회 반복 후 완료"
```

---

## 📦 File Structure

```
project-root/
├── .project-prd.md          # 프로젝트 PRD (1회성)
├── CLAUDE.md                # Claude Code 규칙
├── .cursorrules             # Cursor IDE 규칙
├── .github/
│   └── copilot-instructions.md  # GitHub Copilot 규칙
├── prd/                     # 작업 PRD 폴더
│   ├── feature.md           # Feature 템플릿
│   ├── bug.md               # Bugfix 템플릿
│   ├── refactor.md          # Refactor 템플릿
│   └── experiment.md        # Experiment 템플릿
├── agents/                  # Agent 정의
│   ├── agent_m_gate.md      # PRD 검증
│   ├── agent_m_scan.md      # 영향 분석
│   ├── agent_m_fold.md      # 종합 평가
│   ├── agent_m_verdict.md   # 최종 판단
│   ├── agent_m_patch.md     # 코드 생성
│   └── agent_m_trace.md     # 실행 로그
├── rules/                   # Agent 규칙
│   ├── verdict_rules.yaml   # Verdict 기준
│   └── patch_policy.md      # Patch 정책
├── scripts/
│   ├── init_core.py         # 프로젝트 초기화 스크립트
│   └── templates/
│       └── prd.md.template  # 프로젝트 PRD 템플릿
└── logs/                    # 실행 로그
    └── trace-*.json         # 세션별 추적 로그
```

---

## 📋 Core Principles

1. **PRD 먼저** - 코딩 전에 반드시 PRD 작성
2. **Agent 파이프라인** - 모든 작업은 Agent 검증을 거침
3. **AI가 검증** - 리뷰/검증/판단은 AI가 담당
4. **개발자는 집중** - 구현과 창의성에만 집중
5. **자유로운 실험** - 개인 브랜치에서 마음껏

---

## 🎯 적용 범위

### 모든 프로젝트 유형에 적용 가능
- ✅ **웹**: React, Next.js, Vue, Angular...
- ✅ **모바일**: iOS, Android, Flutter, React Native...
- ✅ **백엔드**: Node.js, Python, Java, Go...
- ✅ **데스크톱**: Electron, Qt, Desktop 앱...
- ✅ **라이브러리**: 오픈소스 패키지, SDK...
- ✅ **DevOps**: 인프라, CI/CD, IaC...

**공통 조건:** PRD만 작성하면 됩니다.

### 팀 규모별 적용

| 팀 규모 | 적용 여부 | 특징 |
|---------|----------|------|
| **1인 (개인)** | ✅ 가능 | PRD, 커밋 규칙만 지키면 됨 |
| **2-5인 (소팀)** | ✅ 권장 | 전체 워크플로우 활용 |
| **5-20인 (중팀)** | ✅ 최적 | 협업 효과 극대화 |
| **20인+ (대팀)** | ✅ 가능 | 조직 레벨 템플릿 활용 |

---

## 🌿 Branching Strategy

```
main                          ← Production (Protected)
 ├─ dev/{user}/{feature}      ← 개인 개발
 └─ hotfix/{issue-id}         ← 긴급 수정
```

---

## 📊 Workflow

```
PRD 작성 → Agent 파이프라인 실행 → 개발 → 커밋 → PR → 머지
          (Gate→Scan→Fold→Verdict→Patch→Trace)
```

---

## 📖 Usage Examples

### Example 1: 간단 프로젝트 (팀 규모: 1-3인)

#### 시나리오
- 프로젝트: 개인 블로그
- 기술 스택: Next.js
- 팀원: 1명 (개인)

#### 설정 단계

```bash
# 1. Vibe Coding Rules 클론
git clone https://github.com/loboking/monggle-vibe-coding-rules.git
cd monggle-vibe-coding-rules

# 2. 프로젝트 PRD 작성
cat > my-blog-prd.md << 'EOF'
---
project_name: "My Blog"
description: "Personal blog with Next.js"
type: "web"
language: "javascript"
framework: "nextjs"
git_remote_url: "git@github.com:john/my-blog.git"
git_default_branch: "main"
ci_cd_provider: "github-actions"
ci_cd_template: "basic"
---

# My Blog PRD

## 개요
개인용 기술 블로그

## 목표
- 마크다운 기반 글 작성
- 코드 하이라이팅
- 반응형 디자인

## 기술 스택
- Next.js 14 (App Router)
- TypeScript
- Tailwind CSS
EOF

# 3. 프로젝트 초기화 실행
python3 scripts/init_core.py my-blog-prd.md

# 4. Next.js 프로젝트 생성
cd ..
npx create-next-app@latest my-blog --typescript --tailwind --app
cd my-blog

# 5. Git 원격 저장소 연결
git remote add origin git@github.com:john/my-blog.git
git push -u origin main
```

#### 사용 예시

```bash
# 1. 새 기능 PRD 작성
cp prd/feature.md prd/feature-comment-system-20250209.md
vim prd/feature-comment-system-20250209.md
# -> PRD 내용 작성

# 2. 브랜치 생성
git checkout -b dev/john/add-comment-system

# 3. Claude Code에 요청
# "prd/feature-comment-system-20250209.md 구현해줘"
# AI가 Agent 파이프라인 실행 → 자동 구현

# 4. 커밋 (규칙에 따른 커밋 메시지)
git add .
git commit -m "feat(comment): add comment system with markdown support"
git push

# 5. PR 생성 (PRD 링크 포함)
gh pr create --title "Add comment system" --body "PRD: prd/feature-comment-system-20250209.md"
```

---

### Example 2: 중규모 프로젝트 (팀 규모: 3-10인)

#### 시나리오
- 프로젝트: 이커머스 백엔드
- 기술 스택: Django, PostgreSQL
- 팀원: 5명 (FE 2, BE 2, DevOps 1)

#### 설정 단계

```bash
# 1. 프로젝트 PRD 작성
cat > ecommerce-prd.md << 'EOF'
---
project_name: "E-Commerce API"
description: "RESTful API for e-commerce platform"
type: "api"
language: "python"
framework: "django"
git_remote_url: "git@github.com:company/ecommerce-api.git"
git_default_branch: "main"
ci_cd_provider: "github-actions"
ci_cd_template: "docker"
---

# E-Commerce API PRD

## 개요
온라인 쇼핑몰을 위한 RESTful API 서버

## 목표
- 상품 관리
- 주문 처리
- 결제 연동
- 사용자 인증

## 기술 스택
- Python 3.11
- Django 4.2
- PostgreSQL 15
- Docker
EOF

# 2. 프로젝트 초기화 실행
python3 scripts/init_core.py ecommerce-prd.md
```

#### 팀 워크플로우

```bash
# 백엔드 개발자 (Alice)
cp prd/feature.md prd/feature-product-api-20250209.md
# -> PRD 작성
git checkout -b dev/alice/product-api
# "prd/feature-product-api-20250209.md 구현해줘"
git commit -m "feat(product): add product CRUD API"
git push
gh pr create --title "Add product API" --body "PRD: prd/feature-product-api-20250209.md"

# 프론트엔드 개발자 (Bob)
cp prd/feature.md prd/feature-product-list-ui-20250209.md
# -> PRD 작성
git checkout -b dev/bob/product-list-ui
# "prd/feature-product-list-ui-20250209.md 구현해줘"
git commit -m "feat(ui): add product list page"
git push
gh pr create --title "Add product list UI" --body "PRD: prd/feature-product-list-ui-20250209.md"
```

---

## 💡 FAQ

**Q: PRD 없이 개발할 수 없나요?**
A: 네, PRD 없이는 AI가 응답하지 않습니다. 모든 개발은 PRD에서 시작해야 합니다.

**Q: 여러 AI 도구를 쓰는데요?**
A: 같은 내용으로 여러 파일 배치:
- Claude → `CLAUDE.md`
- Cursor → `.cursorrules`
- Copilot → `.github/copilot-instructions.md`

**Q: 기존 프로젝트에도 적용 가능한가요?**
A: 넵! 먼저 프로젝트 PRD를 작성한 후 `init_core.py`로 초기화하면 됩니다.

**Q: CI/CD는 필수인가요?**
A: 아니요. `ci_cd_provider: "none"`으로 설정하면 건너뜁니다.

**Q: Agent 파이프라인을 직접 실행해야 하나요?**
A: 아니요! PRD 파일 경로로 Claude Code에 요청하면 AI가 자동으로 Agent 파이프라인을 실행합니다.

---

## 📜 Final Declaration

> **"버그 없는 시스템이 아닌, 실패를 통제하고 반복하지 않는 시스템을 만든다."**

---

## 🔗 Related Projects & Resources

### Same Series Projects

**[monggle-claudecode-skills-agents](https://github.com/loboking/claude-code-skills)**
> Claude Code 전용 커맨드 & 에이전트 툴킷

- **목적**: Claude Code에서 반복 작업 자동화 (`/duo`, `/run`, `/super` 등)
- **대상**: Claude Code 사용자
- **활용**: 본 규칙을 적용한 프로젝트에서 효율성 극대화

**관계**:
- 본 프로젝트 = **"어떻게 협업할 것인가"** (규칙)
- Skills Toolkit = **"어떻게 자동화할 것인가"** (도구)

### External Expert Guides

- [Conventional Commits](https://www.conventionalcommits.org/) - 커밋 메시지 표준
- [GitHub Flow](https://docs.github.com/en/get-started/using-github/github-flow) - 브랜치 전략
- [Axios API Design Guide](https://github.com/axios/axios/blob/master/docs/README.md) - API 설계 원칙
- [GitLab Flow](https://docs.gitlab.com/ee/topics/gitlab_flow.html) - 브랜치 전략 대안

---

## 👥 Team Onboarding

### 새 팀원 추가 절차

#### 1단계: 권한 설정 (관리자)
Git 서비스에서 팀원 초대:
- GitHub: Settings → Collaborators
- GitLab: Project → Members → Invite members
- Bitbucket: Repository settings → Access management

#### 2단계: 로컬 설정 (팀원)

**방법 A: GUI 클라이언트 (가장 쉬움) ⭐**
```bash
# GitHub Desktop, GitKraken 등 설치
# Git 계정으로 로그인 → Repository 클론 → 완료!
```

**방법 B: 명령줄 (HTTPS)**
```bash
# 1. 저장소 클론
git clone https://github.com/org/project.git
cd project-name

# 2. Git 설정
git config user.name "Your Name"
git config user.email "your@email.com"

# 3. 프로젝트 PRD 확인
cat .project-prd.md

# 4. 첫 푸시 시 브라우저에서 로그인
git push  # 브라우저가 열리고 로그인하면 됨
```

**방법 C: SSH 키 (선택사항)**
```bash
# 한 번만 설정하면 모든 프로젝트에 사용 가능
ssh-keygen -t ed25519 -C "your@email.com"
cat ~/.ssh/id_ed25519.pub  # Git 서비스에 등록
```

#### 3단계: 첫 작업 시작

```bash
# 1. 작업 PRD 작성
cp prd/feature.md prd/feature-my-first-task-20250209.md
# -> PRD 내용 작성

# 2. 작업 브랜치 생성
git checkout -b dev/{your-name}/{feature}

# 3. Claude Code에 요청
# "prd/feature-my-first-task-20250209.md 구현해줘"

# 4. 커밋 & 푸시
git add .
git commit -m "feat(scope): description"
git push

# 5. PR 생성 (웹에서)
# push 후 출력된 URL 클릭 → PRD 링크 포함
```

**핵심:**
- **PRD 먼저 작성** - 모든 개발은 PRD에서 시작
- **브랜치 규칙 준수** - `dev/{user}/{feature}`
- **커밋 메시지** - `feat/fix/refactor(scope): description`

---

## 🤝 Contributing

기여를 환영합니다! 다음 단계를 따라주세요:

1. 포크합니다
2. PRD 작성 (`prd/feature-*.md`)
3. 기능 브랜치 생성 (`dev/{your-name}/{feature}`)
4. 커밋 (`feat: add awesome feature`)
5. PR 생성 (PRD 링크 포함)
6. 머지 대기

---

## 📄 License

MIT License - 자유롭게 사용, 수정, 배포 가능

---

**Created with Vibe Coding Methodology v2.0 (Agent-based)**
