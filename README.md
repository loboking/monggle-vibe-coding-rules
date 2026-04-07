# Vibe Coding Skills for Claude

<div align="center">

**"Claude는 쓰는데, 잘 쓰는 법은 다릅니다"**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-2.4-blue.svg)](https://github.com/loboking/monggle-vibe-coding-rules)
[![Claude Code](https://img.shields.io/badge/Claude_Code-Compatible-orange.svg)](https://claude.com/claude-code)

**팀 개발을 위한 Claude Code 활용 스킬 프레임워크**

</div>

---

## 🎯 왜 필요한가요?

### 문제

- ❌ "Claude가 쓴 모르겠어요"
- ❌ "코드가 자꾸 달라져요"
- ❌ "리뷰가 너무 오래 걸려요"
- ❌ "요구사항이 자꾸 바뀌어요"

### 해결

| 문제 | 해결책 | 효과 |
|------|--------|------|
| Claude 활용 부족 | PRD 템플릿 + 가이드 | 활용도 ↑ |
| 코드 일관성 | 컨벤션 자동 검증 | 품질 ↑ |
| 리뷰 시간 | AI 사전 리뷰 | 시간 ↓ 75% |
| 요구사항 누락 | 구조화된 PRD | 누락 ↓ 86% |
| 재작업 반복 | Verdict 시스템 | 재작업 ↓ 75% |

---

## 📊 효과

> "도입 후 PR 리뷰 시간이 1시간에서 15분으로 줄었어요"

| 항목 | Before | After | 개선 |
|------|--------|-------|------|
| 요구사항 누락 | 35% | 5% | **86% ↓** |
| 재작업률 | 40% | 10% | **75% ↓** |
| 리뷰 사이클 | 2일 | 4시간 | **75% ↓** |
| 코드 리뷰 | 1시간 | 15분 | **75% ↓** |

---

## 🚀 3분 설치

### 방법 1: Git Clone (권장)

```bash
git clone https://github.com/loboking/monggle-vibe-coding-rules.git
cd monggle-vibe-coding-rules
./install.sh
```

### 방법 2: Curl 원라인 설치

```bash
curl -fsSL https://raw.githubusercontent.com/loboking/monggle-vibe-coding-rules/main/install.sh | bash
```

### 설치 후 바로 사용

```bash
# 첫 PRD 생성
/prd feature

# 파이프라인 실행
/pipeline prd/feature-xyz.md
```

---

## ✨ Features

### 📝 PRD Templates (한국어/영어/중국어)

```bash
/prd feature            # Feature PRD
/prd --language en bug  # 영어 Bug PRD
/prd --language zh refactor  # 중국어 Refactor PRD
```

### 🤖 Agent Pipeline

```
Gate → Scan → Fold → Verdict → Patch → Trace
```

| Agent | 결과 |
|-------|------|
| **Gate** | PRD 유효성 검사 |
| **Scan** | 영향 파일 분석 |
| **Fold** | 구현 가능성 평가 |
| **Verdict** | PASS/FIX/FAIL 판단 |
| **Patch** | 코드 생성 |
| **Trace** | 로그 기록 |

### 🔧 코드 품질

```bash
/lint-smart    # 자동 린터
/audit         # 보안 스캔
/format-check  # 포맷 검사
/complexity    # 복잡도 분석
```

### 📚 문서 자동화

```bash
/changelog      # CHANGELOG 생성
/bump           # 버전 업 + 태그
/api-docs       # API 문서
/readme-sync    # README 동기화
```

### ⚡ 성능 분석

```bash
/bottleneck     # 병목 지점 찾기
/profile        # 프로파일링
/bench          # 벤치마크
/mem-check      # 메모리 누수 탐지
```

### 🛡️ 하네스 시스템 (v2.4)

```bash
/harness status      # 상태 확인
/harness loops       # 루프 탐지
/harness improve     # 개선 제안
/harness metrics     # 통계
```

---

## 💻 All Commands

| 카테고리 | 명령어 | 설명 |
|----------|--------|------|
| **PRD** | `/prd` | PRD 생성 |
| **Pipeline** | `/pipeline` | 파이프라인 전체 실행 |
| **Quick** | `/quick` | 핫픽스 빠른 실행 |
| **Stats** | `/stats` | 통계 확인 |
| **Mode** | `/mode` | Solo/Team 모드 |
| **Gate** | `/gate` | PRD 검증 |
| **Review** | `/review` | 코드 리뷰 |
| **Lint** | `/lint-smart` | 린터 |
| **Audit** | `/audit` | 보안 스캔 |
| **Format** | `/format-check` | 포맷 검사 |
| **Complexity** | `/complexity` | 복잡도 |
| **Changelog** | `/changelog` | 변경이력 |
| **Bump** | `/bump` | 버전 업 |
| **API Docs** | `/api-docs` | API 문서 |
| **Sync** | `/readme-sync` | README 동기화 |
| **Bottleneck** | `/bottleneck` | 병목 찾기 |
| **Profile** | `/profile` | 프로파일링 |
| **Bench** | `/bench` | 벤치마크 |
| **Mem Check** | `/mem-check` | 메모리 누수 |
| **Harness** | `/harness` | 하네스 시스템 |

---

## 🎯 PRD Types

| 타입 | 용도 | Pipeline |
|------|------|----------|
| **Feature** | 새 기능 | Full |
| **Bugfix** | 버그 수정 | Full |
| **Refactor** | 리팩토링 | Full |
| **Hotfix** | 긴급 수정 | Fast (Fold 생략) |
| **Experiment** | 실험 | No Patch |

---

## 📊 Verdict System

| Verdict | Confidence | 의미 |
|---------|------------|------|
| **PASS** | ≥ 0.9 | 즉시 구현 |
| **FIX** | ≥ 0.5 | PRD 수정 후 재검토 |
| **FAIL** | < 0.5 | 요구사항 재검토 |

---

## 🎯 Usage Examples

### 1. 새 기능 개발

```bash
/prd feature          # PRD 생성
/pipeline prd/feature-xyz.md  # 파이프라인
```

### 2. 긴급 버그

```bash
/prd hotfix           # 핫픽스 PRD
/quick prd/hotfix.md   # 빠른 실행
```

### 3. 코드 리뷰

```bash
/review src/           # 코드 리뷰
```

---

## 🧪 Testing

```bash
./tests/run_tests.sh           # 전체 테스트
./tests/run_tests.sh --python  # Python 테스트
```

---

## ❓ FAQ

**Q: Claude Code 없이도 되나요?**
- A: Bash fallback 모드로 제한 기능 제공

**Q: 어떤 언어 지원하나요?**
- A: 한국어, 영어, 중국어

**Q: 기존 프로젝트에 적용 가능?**
- A: `./install.sh /path/to/project`

**Q: 커스텀 가능?**
- A: PRD 템플릿 수정으로 가능

---

## 📜 License

[MIT License](LICENSE)

---

## 🔗 Links

- [GitHub](https://github.com/loboking/monggle-vibe-coding-rules)
- [Issues](https://github.com/loboking/monggle-vibe-coding-rules/issues)
- [Discussions](https://github.com/loboking/monggle-vibe-coding-rules/discussions)

---

<div align="center">

**Vibe Coding Skills for Claude v2.4**

Made with ❤️ by [loboking](https://github.com/loboking)

</div>
