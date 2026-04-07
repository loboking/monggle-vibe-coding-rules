# Vibe Coding Skills for Claude

<div align="center">

**"Claude는 쓰는데, 잘 쓰는 법은 다릅니다"**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-2.4-blue.svg)](https://github.com/loboking/monggle-vibe-coding-rules)
[![Claude Code](https://img.shields.io/badge/Claude_Code-Compatible-orange.svg)](https://claude.com/claude-code)

**팀 개발을 위한 Claude Code 활용 스킬 프레임워크**

</div>

---

## 📖 이 프로젝트는 무엇인가요?

**Vibe Coding Skills for Claude**는 팀 개발 환경에서 Claude Code를 효과적으로 활용하기 위한 **명령어 스킬 모음**입니다.

- **PRD 템플릿**: 구조화된 요구사항 정의
- **Agent Pipeline**: PRD 기반 자동 코드 생성 워크플로우
- **코드 품질 도구**: 린트, 보안 스캔, 복잡도 분석
- **문서 자동화**: CHANGELOG, API 문서 자동 생성
- **하네스 시스템**: 무한 루프 방지, 자동 개선 제안

---

## 🎯 왜 필요한가요?

### 흔한 문제들

| 문제 | 원인 |
|------|------|
| "Claude가 쓴 코드를 모르겠어요" | 요구사항이 불명확해서 매번 다른 코드 생성 |
| "코드가 자꾸 달라져요" | 컨벤션이 없어서 일관성 부족 |
| "리뷰가 너무 오래 걸려요" | 기본 품질 검증이 부족 |
| "요구사항이 자꾸 바뀌어요" | 초기 요구사항 정의가 불충분 |

### 제공하는 해결책

| 해결책 | 어떻게 |
|--------|--------|
| **구조화된 PRD** | 템플릿으로 필수 항목 누락 방지 |
| **코드 일관성** | 프로젝트 자동 감지 후 적절한 린터 적용 |
| **사전 리뷰** | AI가 커밋 전에 자동 검증 |
| **명확한 요구사항** | Verdict 시스템으로 PRD 품질 판단 |

---

## 🚀 설치

### Git Clone (권장)

```bash
git clone https://github.com/loboking/monggle-vibe-coding-rules.git
cd monggle-vibe-coding-rules
./install.sh
```

### Curl 원라인 설치

```bash
curl -fsSL https://raw.githubusercontent.com/loboking/monggle-vibe-coding-rules/main/install.sh | bash
```

### 설치 완료 후

```bash
# Claude Code에서 바로 사용
/prd feature
```

---

## 📝 핵심 기능

### 1. PRD 생성

대화형 질문을 통해 구조화된 PRD를 작성합니다.

```bash
/prd feature                    # 새 기능 PRD (대화형)
/prd bug                        # 버그 수정 PRD
/prd refactor                   # 리팩토링 PRD
/prd api                        # API 설계 PRD
```

**지원 타입**: `feature`, `bug`, `refactor`, `hotfix`, `experiment`, `api`, `migration`, `ml`, `devops`

---

### 2. Agent Pipeline

PRD가 작성되면 다음 단계를 자동으로 실행합니다:

```
┌─────────┐    ┌─────────┐    ┌─────────┐    ┌──────────┐    ┌─────────┐    ┌─────────┐
│  Gate   │ →> │  Scan   │ →> │  Fold   │ →> │ Verdict  │ →> │  Patch  │ →> │  Trace  │
│ (검증)  │    │ (분석)  │    │ (평가)  │    │ (판단)   │    │ (구현)  │    │ (기록)  │
└─────────┘    └─────────┘    └─────────┘    └──────────┘    └─────────┘    └─────────┘
```

| 단계 | 설명 |
|:----:|------|
| **Gate** | PRD에 필수 섹션이 모두 있는지 확인 |
| **Scan** | 코드베이스에서 영향 받는 파일 분석 |
| **Fold** | 구현 난이도와 위험도 평가 |
| **Verdict** | PASS(≥0.9) / FIX(≥0.5) / FAIL(<0.5) 판단 |
| **Patch** | PASS인 경우 코드 자동 생성 |
| **Trace** | 실행 로그 저장 및 추적 |

```bash
/pipeline prd/feature-xyz.md     # 전체 파이프라인 실행
/quick prd/hotfix.md             # 핫픽스용 빠른 실행 (Gate/Fold 생략)
```

---

### 3. 코드 품질 도구

프로젝트 타입을 자동 감지하여 적절한 도구를 실행합니다.

```bash
/lint-smart      # 프로젝트 자동 감지 (pylint/eslint/golangci-lint 등)
/audit           # 보안 취약점 스캔 (bandit/semgrep)
/format-check    # 코드 포맷 검사 (black/prettier/gofmt)
/complexity      # 코드 복잡도 분석 (radon/lizard)
```

---

### 4. 문서 자동화

Git 커밋 기록으로 문서를 자동 생성합니다.

```bash
/changelog       # Git 로그 → CHANGELOG.md 생성
/bump            # 버전 업 + Git 태그 생성
/api-docs        # Docstring → API 문서 추출
/readme-sync     # 코드 변경 내용을 README에 동기
```

---

### 5. 성능 분석 도구

```bash
/bottleneck      # 성능 병목 지점 분석
/profile         # 프로파일링 실행
/bench           # 벤치마크 실행 및 비교
/mem-check       # 메모리 누수 탐지
```

---

### 6. 하네스 시스템 (v2.4)

AI가 무한 루프에 빠지는 것을 방지하고 자동 개선을 제안합니다.

```bash
/harness status      # 하네스 상태 확인
/harness loops       # 무한 수정 루프 탐지 현황
/harness improve     # 개선 제안 확인
/harness metrics     # 가이드/센서 통계
```

---

## 💻 전체 명령어 목록

| 카테고리 | 명령어 | 설명 |
|----------|--------|------|
| **PRD** | `/prd` | PRD 생성 (대화형) |
| **Pipeline** | `/pipeline` | 전체 파이프라인 실행 |
| **Quick** | `/quick` | 핫픽스 빠른 실행 |
| **Stats** | `/stats` | 파이프라인 통계 확인 |
| **Mode** | `/mode` | Solo/Team 모드 전환 |
| **Gate** | `/gate` | PRD 유효성 검증 |
| **Review** | `/review` | AI 코드 리뷰 |
| **Lint** | `/lint-smart` | 자동 린터 실행 |
| **Audit** | `/audit` | 보안 취약점 스캔 |
| **Format** | `/format-check` | 코드 포맷 검사 |
| **Complexity** | `/complexity` | 복잡도 분석 |
| **Changelog** | `/changelog` | CHANGELOG 생성 |
| **Bump** | `/bump` | 버전 업 + 태그 |
| **API Docs** | `/api-docs` | API 문서 추출 |
| **Sync** | `/readme-sync` | README 동기화 |
| **Bottleneck** | `/bottleneck` | 병목 지점 찾기 |
| **Profile** | `/profile` | 프로파일링 |
| **Bench** | `/bench` | 벤치마크 |
| **Mem Check** | `/mem-check` | 메모리 누수 탐지 |
| **Harness** | `/harness` | 하네스 시스템 관리 |

---

## 🎯 사용 예시

### 새로운 기능 개발

```bash
# 1. PRD 작성 (대화형)
/prd feature

# 2. 파이프라인 실행
/pipeline prd/feature-user-auth.md

# 결과: Verdict에 따라 자동으로 코드 생성 또는 수정 제안
```

### 긴급 버그 수정

```bash
# 1. 핫픽스 PRD 생성
/prd hotfix

# 2. 빠른 실행 (Gate/Fold 생략)
/quick prd/hotfix-login-fix.md
```

### 코드 품질 검사

```bash
# 자동으로 프로젝트 감지 후 적절한 린터 실행
/lint-smart

# 보안 스캔
/audit

# 복잡도 확인
/complexity src/
```

---

## 📊 Verdict 시스템

PRD 품질을 수치화하여 판단합니다.

| Verdict | Confidence | 의미 | 다음 단계 |
|---------|------------|------|----------|
| **PASS** | ≥ 0.9 | PRD가 충분히 상세함 | 즉시 구현 |
| **FIX** | ≥ 0.5 | 일부 개선 필요 | 수정 후 재검토 |
| **FAIL** | < 0.5 | 요구사항 불충분 | 처음부터 작성 |

---

## 🧪 테스트

```bash
./tests/run_tests.sh           # 전체 테스트
./tests/run_tests.sh --python  # Python 테스트만
```

---

## ❓ FAQ

**Q: Claude Code가 없어도 되나요?**
- A: Bash fallback 모드로 제한 기능 제공되지만, Claude Code와 함께 사용할 때 최적의 성능을 발휘합니다.

**Q: 어떤 언어를 지원하나요?**
- A: PRD 생성은 한국어로 진행됩니다. 코드 분석은 Python, JavaScript, TypeScript, Go, Java 등을 지원합니다.

**Q: 기존 프로젝트에 적용 가능한가요?**
- A: 네, `./install.sh /path/to/project` 명령어로 기존 프로젝트에 설치할 수 있습니다.

**Q: PRD 타입은 어떤 것이 있나요?**
- A: `feature`(새 기능), `bug`(버그 수정), `refactor`(리팩토링), `hotfix`(긴급 수정), `experiment`(실험), `api`(API), `migration`(DB 마이그레이션), `ml`(ML 모델), `devops`(DevOps)가 있습니다.

---

## 📜 License

[MIT License](LICENSE)

---

## 🔗 Links

- [GitHub Repository](https://github.com/loboking/monggle-vibe-coding-rules)
- [Issues](https://github.com/loboking/monggle-vibe-coding-rules/issues)
- [Discussions](https://github.com/loboking/monggle-vibe-coding-rules/discussions)

---

## 🏷️ Keywords

Claude Code, AI 팀 개발, PRD 템플릿, Agent Pipeline, 코드 품질, 자동 리뷰, Vibe Coding, 개발 워크플로우, 협업 도구, 하네스 방법론

---

<div align="center">

**Vibe Coding Skills for Claude v2.4**

Made with ❤️ by [loboking](https://github.com/loboking)

</div>
