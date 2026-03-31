# Vibe Coding Rules

<div align="center">

**Agent 기반 Vibe Coding 방법론 - PRD 중심의 개발 프로세스**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-2.4-blue)](https://github.com/loboking/monggle-vibe-coding-rules)
[![Claude Code](https://img.shields.io/badge/Claude_Code-Compatible-orange)](https://claude.com/claude-code)

[Features](#-features) • [Quick Start](#-quick-start) • [Commands](#-commands) • [Contributing](#-contributing)

</div>

---

## 📖 Overview

Vibe Coding Rules는 **Claude Code**를 위한 개발 방법론 프레임워크입니다. PRD(Product Requirements Document) 기반 개발을 통해 품질과 협업 효율을 높입니다.

### 핵심 기능

| 기능 | 설명 |
|------|------|
| **PRD 기반 개발** | 코딩 전 명확한 요구사항 정의 |
| **Agent 파이프라인** | Gate → Scan → Fold → Verdict → Patch → Trace |
| **Solo/Team 모드** | 상황에 맞는 워크플로우 선택 |
| **AI Reviewer** | Manual/Semi-Auto/Auto 리뷰 모드 |
| **12개 스킬** | 코드 품질, 문서, 성능 분석 |

---

## 🚀 Quick Start

```bash
# 1. 저장소 클론
git clone https://github.com/loboking/monggle-vibe-coding-rules.git
cd monggle-vibe-coding-rules

# 2. 원클릭 설치
./install.sh

# 3. 기존 프로젝트에 적용
./install.sh /path/to/your-project
```

### 5분 만에 시작하기

```bash
# 모드 설정
/mode solo               # Solo 모드 (PRD 선택적)
/mode team               # Team 모드 (PRD 필수)

# PRD 작성 (대화형)
/init                    # 자동 타입 감지
/init feature            # Feature PRD
/init hotfix             # 긴급 수정

# 실행
/pipeline prd/feature.md # 전체 파이프라인
/quick prd/hotfix.md     # 빠른 핫픽스
```

---

## ✨ Features

### v2.4 새로운 기능

#### 코드 품질 스킬 (4개)
```bash
/lint-smart              # 프로젝트 자동 감지 린터
/audit                   # 보안 취약점 스캔
/format-check            # 코드 포맷 검사
/complexity              # 복잡도 분석
```

#### 문서 자동화 스킬 (4개)
```bash
/changelog               # Git 커밋 기반 CHANGELOG 생성
/bump                    # 버전 업 + 태그 생성
/api-docs                # API 문서 추출
/readme-sync             # README 동기화
```

#### 성능 분석 스킬 (4개)
```bash
/bottleneck              # 성능 병목 지점 찾기
/profile                 # 프로파일링 실행
/bench                   # 벤치마크 실행/비교
/mem-check               # 메모리 누수 탐지
```

### Agent 파이프라인

```
┌─────┐   ┌─────┐   ┌─────┐   ┌─────────┐   ┌───────┐   ┌──────┐
│ Gate │ → │ Scan │ → │ Fold │ → │ Verdict │ → │ Patch │ → │ Trace│
└─────┘   └─────┘   └─────┘   └─────────┘   └───────┘   └──────┘
PRD 검증   영향 분석   종합       판단(PASS/FIX/FAIL)  구현     로깅
```

| Agent | 역할 |
|-------|------|
| **Gate** | PRD 유효성 검사 |
| **Scan** | 코드베이스 영향 분석 |
| **Fold** | 결과 종합 및 타당성 평가 |
| **Verdict** | 최종 판단 (PASS/FIX/FAIL) |
| **Patch** | 코드 생성/수정 |
| **Trace** | 실행 로그 기록 |

### Solo/Team 모드

| 모드 | PRD | 용도 |
|------|-----|------|
| **Solo** | 선택적 | 개인 프로젝트, 빠른 반복 |
| **Team** | 필수 | 팀 협업, 품질 보장 |

### AI Reviewer

| 모드 | 설명 |
|------|------|
| **Manual** | `/review` 명령어로 수동 리뷰 |
| **Semi-Auto** | PR 생성 시 자동 리뷰 |
| **Auto** | 자동 리뷰 + 조건부 머지 |

---

## 📋 PRD Types

| 타입 | 템플릿 | Pipeline |
|------|--------|----------|
| **Feature** | `prd/feature.md` | Full |
| **Bugfix** | `prd/bug.md` | Full |
| **Refactor** | `prd/refactor.md` | Full |
| **Hotfix** | `prd/hotfix.md` | Fast Track (Fold 생략) |
| **Experiment** | `prd/experiment.md` | No Patch |

### Verdict System

| Verdict | Confidence | 결과 |
|---------|------------|------|
| **PASS** | ≥ 0.9 | 즉시 구현 |
| **FIX** | ≥ 0.5 | PRD 수정 후 재검토 |
| **FAIL** | < 0.5 | 요구사항 재검토 |

---

## 💻 Commands

### PRD & 파이프라인

```bash
/init                    # 대화형 PRD 생성 (자동 타입 감지)
/init feature            # Feature PRD
/init bug                # Bug fix PRD
/init hotfix             # Hotfix PRD (fast-track)

/pipeline [prd]          # 전체 파이프라인 실행
/quick [prd]             # 핫픽스 빠른 실행 (Fold 생략)
/stats                   # 파이프라인 통계
```

### 모드 관리

```bash
/mode                    # 현재 모드 확인
/mode solo               # Solo 모드 전환
/mode team               # Team 모드 전환
```

### 검토 & 로그

```bash
/gate [prd]              # PRD 유효성 검사
/review [path]           # AI 코드 리뷰
/trace                   # 실행 로그 확인
```

### 코드 품질

```bash
/lint-smart              # 프로젝트 자동 감지 린터
/audit                   # 보안 취약점 스캔
/format-check            # 코드 포맷 검사
/complexity              # 복잡도 분석
```

### 문서 자동화

```bash
/changelog               # CHANGELOG 생성
/bump [major|minor|patch] # 버전 업 + 태그
/api-docs                # API 문서 추출
/readme-sync             # README 동기화
```

### 성능 분석

```bash
/bottleneck              # 병목 지점 찾기
/profile                 # 프로파일링
/bench                   # 벤치마크
/mem-check               # 메모리 누수 탐지
```

---

## 📁 Project Structure

```
monggle-vibe-coding-rules/
├── CLAUDE.md              # Claude Code 규칙
├── .cursorrules           # IDE 규칙
├── install.sh             # 원클릭 설치
├── CONTRIBUTING.md        # 기여 가이드
├── .claude/
│   ├── hooks/             # 자동화 훅
│   ├── commands/          # 슬래시 명령어
│   └── config/            # 설정 (team.yaml)
├── agents/                # Agent 구현 (Python)
├── prd/                   # PRD 템플릿
├── scripts/               # 유틸리티
├── rules/                 # 코어 규칙
└── tests/                 # 테스트
```

---

## 📖 Usage Examples

### Example 1: 이메일 로그인 기능

```bash
# Step 1: 대화형 PRD 생성
/init feature

📝 Feature Name?
> 이메일 로그인 기능

📝 What problem does this solve?
> 사용자가 이메일과 비밀번호로 로그인할 수 있게 해요

📝 Functional requirements?
> - 이메일 형식 검증
> - 비밀번호 8자 이상
> - JWT 토큰 발급

# Step 2: PRD 자동 생성
✅ prd/feature-email-login.md

# Step 3: 파이프라인 실행
/pipeline prd/feature-email-login.md
```

### Example 2: 긴급 핫픽스

```bash
# Step 1: 핫픽스 PRD 생성
/init hotfix

📝 What's the urgent problem?
> 로그인 버튼 클릭 시 앱 크래시

📝 Immediate fix?
> null 체크 추가

# Step 2: 빠른 실행
/quick prd/hotfix-login-crash.md
```

---

## 🧪 Testing

```bash
# 전체 테스트
python3 -m unittest discover tests/

# 특정 테스트
python3 tests/test_agents.py -v

# 커버리지
python3 -m coverage run -m unittest discover tests/
python3 -m coverage report
```

### 커버리지 요구사항

| 단계 | 커버리지 | 차단 |
|------|----------|------|
| 개인 브랜치 | 80%+ 권장 | No |
| PR 생성 | 80%+ 필수 | Yes |
| Main Merge | Full 필수 | Yes |

---

## ❓ FAQ

**Q: Solo vs Team 모드?**
- Solo: PRD 선택적, 빠른 반복
- Team: PRD 필수, 품질 보장

**Q: Hotfix는 언제 사용?**
- 프로덕션 중단, 데이터 손실, 보안 취약점 등 긴급 상황

**Q: API 키 필요?**
- 아니요! API 키가 전혀 필요 없습니다.

**Q: Python 3.8 미만?**
- Bash fallback 모드로 제한된 기능 제공

---

## 🤝 Contributing

기여는 환영합니다! 상세한 가이드는 **[CONTRIBUTING.md](CONTRIBUTING.md)**를 확인하세요.

```bash
# 1. 포크 및 클론
git clone https://github.com/YOUR_USERNAME/monggle-vibe-coding-rules.git

# 2. 브랜치 생성
git checkout -b feature/your-feature

# 3. PRD 작성
cp prd/feature.md prd/feature-your-name.md

# 4. 커밋 및 PR
git commit -m "feat: add new feature"
git push origin feature/your-feature
```

---

## 📜 License

[MIT License](LICENSE)

---

## 🔗 Links

- [GitHub Repository](https://github.com/loboking/monggle-vibe-coding-rules)
- [Issues](https://github.com/loboking/monggle-vibe-coding-rules/issues)
- [Discussions](https://github.com/loboking/monggle-vibe-coding-rules/discussions)

---

<div align="center">

**Vibe Coding Rules v2.4**

Made with ❤️ by [loboking](https://github.com/loboking)

</div>
