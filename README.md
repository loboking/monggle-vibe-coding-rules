# Vibe Coding Skills for Claude

<div align="center">

**"Claude는 쓰는데, 잘 쓰는 법은 다릅니다"**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-2.5-blue.svg)](https://github.com/loboking/monggle-vibe-coding-rules)
[![Claude Code](https://img.shields.io/badge/Claude_Code-Compatible-orange.svg)](https://claude.com/claude-code)

**Claude Code를 더 잘 쓰기 위한 스킬 모음**

</div>

---

## 📖 이 프로젝트는 무엇인가요?

개발자가 Claude Code를 사용할 때 **더 좋은 결과를 얻을 수 있도록 돕는 스킬 모음**입니다.

- **PRD 템플릿**: 구조화된 요구사항 정의
- **Agent Pipeline**: PRD 기반 자동 코드 생성 워크플로우
- **코드 품질 도구**: 린트, 보안 스캔, 복잡도 분석
- **문서 자동화**: CHANGELOG, API 문서 자동 생성

> **솔직한 고백**: 이것은 팀 협업 도구가 아닙니다. 개발자 개인이 Claude를 더 잘 쓰기 위한 방법론입니다.

---

## 🎯 왜 필요한가요?

### 흔한 문제

| 문제 | 원인 |
|------|------|
| "Claude가 쓴 코드를 모르겠어요" | 요구사항이 불명확해서 매번 다른 코드 |
| "코드가 자꾸 달라져요" | 컨벤션 없이 일관성 부족 |
| "리뷰가 너무 오래 걸려요" | 기본 품질 검증이 부족 |

### 제공하는 도구

| 도구 | 역할 |
|------|------|
| **구조화된 PRD** | 필수 항목 누락 방지 |
| **코드 품질 도구** | 프로젝트 자동 감지 후 적절한 도구 실행 |
| **AI 사전 리뷰** | 커밋 전 자동 검증 |
| **Verdict 시스템** | PRD 품질 판단 (PASS/FIX/FAIL) |

---

## 🚀 설치

### Git Clone

```bash
git clone https://github.com/loboking/monggle-vibe-coding-rules.git
cd monggle-vibe-coding-rules
./install.sh
```

### Curl 원라인

```bash
curl -fsSL https://raw.githubusercontent.com/loboking/monggle-vibe-coding-rules/main/install.sh | bash
```

---

### 0. 초기 설정 (최초 1회)

처음 시작할 때 기본 환경을 설정합니다.

```bash
/init                    # 초기 설정 워드 실행
/init --reset            # 설정 초기화 후 재설정
```

**설정 항목**:
- 작업 모드 (Solo / Team)
- PRD 언어 (한국어 / English / 中文 / 日本語)
- 기본 AI 모델 (Haiku / Sonnet / Opus)
- 사용자 정보 (이름, 이메일)

설정은 `.claude/config/user.conf`에 저장되며, 이후 모든 스킬이 이 값을 사용합니다.

---

## 📝 핵심 기능

### 1. PRD 생성

대화형 질문을 통해 구조화된 PRD를 작성합니다.

```bash
/prd feature                # 새 기능 PRD (언어 선택 프롬프트)
/prd bug                  # 버그 수정 PRD
/prd api                  # API 설계 PRD
/prd --language en feature  # 영어 PRD (언어 지정)
/prd --language ko bug      # 한국어 PRD
```

**지원 타입**: `feature`, `bug`, `refactor`, `hotfix`, `experiment`, `api`, `migration`, `ml`, `devops`

**언어 옵션**:
- `--language ko` - 한국어 (기본값)
- `--language en` - 영어
- `--language zh` - 중국어
- `--language ja` - 일본어

**언어 선택 프롬프트** (인터랙티브 모드):
- 선택하지 않고 Enter → 영어 기본값
- 1번 → 한국어, 2번 → 영어, 3번 → 중국어, 4번 → 일본어

---

### 2. Agent Pipeline

PRD가 작성되면 다음 단계를 자동으로 실행합니다:

```
Gate(검증) → Scan(분석) → Fold(평가) → Verdict(판단) → Patch(구현) → Trace(기록)
```

```bash
/pipeline prd/feature-xyz.md     # 전체 파이프라인 실행
/quick prd/hotfix.md             # 빠른 실행
```

---

### 3. 코드 품질 도구

```bash
/lint-smart      # 프로젝트 자동 감지 후 린터 실행
/audit           # 보안 취약점 스캔
/format-check    # 코드 포맷 검사
/complexity      # 복잡도 분석
```

---

### 4. 문서 자동화

```bash
/changelog       # Git 로그 → CHANGELOG.md
/bump            # 버전 업 + Git 태그
/api-docs        # Docstring → API 문서
/readme-sync     # README 동기화
```

---

### 5. 성능 분석

```bash
/bottleneck      # 병목 지점 분석
/profile         # 프로파일링
/bench           # 벤치마크
/mem-check       # 메모리 누수 탐지
```

---

### 6. Git 협업 스킬 (v2.5)

**팀 개발을 위한 안전한 Git 동기화 및 충돌 해결**

```bash
./update                 # 또는 ./.claude/commands/update.sh
./push-safe              # 또는 ./.claude/commands/push-safe.sh
```

**특징:**
- ✅ 자동 stash로 작업 안전 저장
- ✅ 충돌 발생 시 자동 rollback
- ✅ GitHub/GitLab/Bitbucket PR 자동 생성
- ✅ 충돌 해결 가이드 제공

**사용 예시:**
```bash
./update                 # 대화형 실행
./update --auto          # 자동 실행
./update --dry-run       # 계획만 확인

./push-safe              # 안전하게 push + PR
./push-safe --no-pr      # PR 생성 없이 push
```

**충돌 해결 가이드:**
```
❌ 충돌 발생: src/auth.ts

🔍 원인 분석:
- 같은 줄(line 15)에서 충돌
- 원본: return true (teamA 수정)
- 내것: return false (나 수정)

💡 해결 방안:
1. /resolve-keep    → 내 변경 유지
2. /resolve-theirs  → 원본 변경 유지
3. /resolve-merge   → 둘 다 합치기
```

---

### 7. 하네스 시스템 (v2.4)

**Pipeline 실행 후 자동으로 작동합니다.** (백그라운드)

```bash
/pipeline prd/feature.md
# → 완료 후 자동으로 개선 제안 표시 (Critical만)
```

| 기능 | 설명 | 자동/수동 |
|------|------|----------|
| **루프 탐지** | 같은 파일 무한 수정 방지 | 자동 |
| **개선 제안** | 통계 분석 후 개선점 제안 | 자동 (Pipeline 후) |
| **`/harness`** | 상태 확인, 수동 진단 | 수동 (디버깅용) |

```bash
/harness status      # 현재 상태 확인 (수동)
/harness loops       # 루프 탐지 현황 (수동)
/harness improve     # 전체 제안 보기 (수동)
```

---

## 💻 전체 명령어

| 명령어 | 설명 |
|--------|------|
| `/init` | 초기 설정 워드 (최초 1회) |
| `/prd` | PRD 생성 (대화형) |
| `/pipeline` | 전체 파이프라인 실행 |
| `/quick` | 빠른 실행 (Hotfix) |
| `/stats` | 통계 확인 |
| `/gate` | PRD 검증 |
| `/review` | AI 코드 리뷰 |
| **`/update`** | **Git 동기화 (v2.5)** |
| **`/push-safe`** | **안전 전송 (v2.5)** |
| `/lint-smart` | 자동 린터 |
| `/audit` | 보안 스캔 |
| `/format-check` | 포맷 검사 |
| `/complexity` | 복잡도 분석 |
| `/changelog` | CHANGELOG 생성 |
| `/bump` | 버전 업 + 태그 |
| `/api-docs` | API 문서 |
| `/readme-sync` | README 동기화 |
| `/bottleneck` | 병목 찾기 |
| `/profile` | 프로파일링 |
| `/bench` | 벤치마크 |
| `/mem-check` | 메모리 누수 |
| `/harness` | 하네스 시스템 |

---

## 🧪 테스트

```bash
./tests/run_tests.sh           # 전체 테스트
./tests/run_tests.sh --python  # Python 테스트
```

---

## ❓ FAQ

**Q: Claude Code가 없어도 되나요?**
- A: Bash fallback 모드로 제한 기능 제공되지만, Claude Code와 함께 사용할 때 최적의 성능을 발휘합니다.

**Q: 어떤 언어를 지원하나요?**
- A: PRD 생성은 한국어로 진행됩니다. 코드 분석은 Python, JavaScript, TypeScript, Go, Java 등을 지원합니다.

**Q: 기존 프로젝트에 적용 가능한가요?**
- A: 네, `./install.sh /path/to/project`로 기존 프로젝트에 설치할 수 있습니다.

**Q: 팀에서 함께 쓸 수 있나요?**
- A: 네! v2.5부터 Git 협업 스킬이 추가되어 팀 개발이 가능합니다:
  - `/update`로 원격 저장소 안전 동기화
  - `/push-safe`로 충돌 방지 전송
  - GitHub/GitLab/Bitbucket PR 자동 생성
  - 각 팀원이 설치 후 Git 워크플로우 사용 가능

---

## 🔄 업데이트

### 최신 버전 확인

```bash
cd monggle-vibe-coding-rules
git pull origin main
./install.sh
```

### Curl로 업데이트

```bash
curl -fsSL https://raw.githubusercontent.com/loboking/monggle-vibe-coding-rules/main/install.sh | bash
```

### 변경사항 확인

```bash
git log --oneline -5
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

**Vibe Coding Skills for Claude v2.5**

Made with ❤️ by [loboking](https://github.com/loboking)

</div>
