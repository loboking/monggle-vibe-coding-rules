# Vibe Coding Skills for Claude

<div align="center">

**"Claude는 쓰는데, 잘 쓰는 법은 다릅니다"**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-2.6.0-blue.svg)](https://github.com/loboking/monggle-vibe-coding-rules)
[![Claude Code](https://img.shields.io/badge/Claude_Code-Compatible-orange.svg)](https://claude.com/claude-code)

**Claude Code를 더 잘 쓰기 위한 스킬 모음**

[한국어](README.md) | [English](README_EN.md)

</div>

---

## 📖 이 프로젝트는 무엇인가요?

개발자가 Claude Code를 사용할 때 **더 좋은 결과를 얻을 수 있도록 돕는 스킬 모음**입니다.

- **📋 PRD 템플릿**: 구조화된 요구사항 정의 (한국어/영어/중국어/일본어)
- **🤖 Agent Pipeline**: PRD 기반 자동 코드 생성 워크플로우
- **🔍 코드 품질 도구**: 린트, 보안 스캔, 복잡도 분석
- **📚 문서 자동화**: CHANGELOG, API 문서 자동 생성
- **🔄 Git 협업 스킬**: 안전한 Git 동기화 및 충돌 해결

> **솔직한 고백**: 이것은 팀 협업 도구가 아닙니다. 개발자 개인이 Claude를 더 잘 쓰기 위한 방법론입니다.
>
> 하지만 v2.5부터 Git 협업 스킬이 추가되어 팀 개발도 가능합니다!

---

## 🎯 왜 필요한가요?

### 흔한 문제

| 문제 | 원인 |
|------|------|
| "Claude가 쓴 코드를 모르겠어요" | 요구사항이 불명확해서 매번 다른 코드 |
| "코드가 자꾸 달라져요" | 컨벤션 없이 일관성 부족 |
| "리뷰가 너무 오래 걸려요" | 기본 품질 검증이 부족 |
| "Git 충돌이 자꾸 생겨요" | 동기화 타이밍을 맞추기 어려움 |

### 제공하는 도구

| 도구 | 역할 |
|------|------|
| **구조화된 PRD** | 필수 항목 누락 방지 |
| **코드 품질 도구** | 프로젝트 자동 감지 후 적절한 도구 실행 |
| **AI 사전 리뷰** | 커밋 전 자동 검증 |
| **Verdict 시스템** | PRD 품질 판단 (PASS/FIX/FAIL) |
| **Git 협업 스킬** | 안전한 동기화 및 충돌 해결 |

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

## 🎬 0. 초기 설정 (최초 1회)

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

## 🔄 작업 모드별 동작

**Solo 모드** (기본값):
- PRD 없이도 자유롭게 코드 수정 가능
- 빠른 프로토타이핑에 적합

**Team 모드**:
- PRD가 필수! PRD 없으면 자동 생성 프롬프트
- 체계된 협업 프로세스 보장

모드 변경:
```bash
/mode solo              # Solo 모드로 변경
/mode team              # Team 모드로 변경
```

---

## 📝 핵심 기능

### 0. 🤖 의도 기반 스킬 실행 (v2.6)

사용자의 자연어 입력에서 **의도(Intent)**를 파악하여 자동으로 적절한 스킬을 실행합니다. 키워드 매칭이 아니라 **의미 이해**가 핵심입니다.

**특징:**
- ✅ 다국어 지원 (한국어, 영어)
- ✅ 다양한 표현 자동 인식
- ✅ 문맥 기반 의도 파악

**예시:**
```
사용자: "너무 느려" → 자동 실행: /bottleneck
사용자: "보안 문제 없나?" → 자동 실행: /audit
사용자: "기획 좀 세워줘" → 자동 실행: /prd
사용자: "코드 올릴게" → 자동 실행: /push-safe
```

**지원 의도:**
| 의도 | 스킬 |
|-----|------|
| 계획 수립 | `/prd` |
| 구조 검토 | `/arch-review` |
| 성능 문제 | `/bottleneck`, `/profile`, `/bench` |
| 보안 점검 | `/audit` |
| 코드 검토 | `/review` |
| Git 동기화 | `/push-safe`, `/update` |

---

### 1. PRD 생성 (다국어 지원)

대화형 질문을 통해 구조화된 PRD를 작성합니다.

```bash
/prd                     # 대화형 PRD 생성
/prd feature             # 새 기능 PRD
/prd bug                 # 버그 수정 PRD
/prd api                 # API 설계 PRD
/prd --language en       # 영어 PRD
/prd --language ko       # 한국어 PRD
```

**지원 타입**: `feature`, `bug`, `refactor`, `hotfix`, `experiment`, `api`, `migration`, `ml`, `devops`

**지원 언어**:
- `--language ko` - 한국어 (기본값)
- `--language en` - 영어
- `--language zh` - 중국어
- `--language ja` - 일본어

---

### 2. Agent Pipeline

PRD가 작성되면 다음 단계를 자동으로 실행합니다:

```
Gate(검증) → Scan(분석) → Fold(평가) → Verdict(판단) → Patch(구현) → Trace(기록)
```

```bash
/pipeline prd/feature-xyz.md     # 전체 파이프라인 실행
/quick prd/hotfix.md             # 빠른 실행 (Gate/Fold 생략)
```

**Verdict 시스템**:
- **PASS** (>= 0.9): 구현 진행
- **FIX** (>= 0.5): PRD 개선 필요
- **FAIL** (< 0.5): 처음부터 작성

---

### 3. 코드 품질 도구

프로젝트 자동 감지 후 적절한 도구를 실행합니다.

```bash
/lint-smart      # 프로젝트 자동 감지 후 린터 실행
/audit           # 보안 취약점 스캔
/format-check    # 코드 포맷 검사만
/complexity      # 복잡도 분석
```

---

### 4. 문서 자동화

Git 로그과 코드에서 문서를 자동 생성합니다.

```bash
/changelog       # Git 로그 → CHANGELOG.md
/bump            # 버전 업 + Git 태그
/api-docs        # Docstring → API 문서
/readme-sync     # README 동기화
```

---

### 5. 성능 분석

코드 성능을 분석하고 병목을 찾습니다.

```bash
/bottleneck      # 병목 지점 분석
/profile         # 프로파일링
/bench           # 벤치마크 실행/비교
/mem-check       # 메모리 누수 탐지
```

---

### 6. Git 협업 스킬 (v2.5) 🆕

팀 개발을 위한 안전한 Git 동기화 및 충돌 해결

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
1. git checkout --theirs src/auth.ts  → 원본 유지
2. git checkout --ours src/auth.ts    → 내 변경 유지
3. 수동으로 src/auth.ts 수정          → 둘 다 합치기
```

---

### 7. 작업 관리 스킬 (v2.6) 🆕

```bash
/save-point              # 현재 작업 상태 저장
/save-point list         # 저장된 상태 목록
/save-point resume       # 최근 상태 복구

/arch-review             # 아키텍처/설계 리뷰
/arch-review <prd-file>  # PRD 파일 리뷰

/weekly-recap            # 주간 회고
/weekly-recap --team     # 팀원별 분석
```

**저장되는 정보 (`/save-point`)**:
- Git 상태 (브랜치, 수정된 파일, 커밋)
- 완료/진행 중/남은 작업
- 중요한 결정 사항
- 관련 PRD/이슈 링크

**아키텍처 리뷰 항목 (`/arch-review`)**:
- 컴포넌트 분리 & 의존성
- 데이터 흐름
- 엣지 케이스 (네트워크 실패, 동시성 등)
- 테스트 커버리지
- 성능 & 보안

---

### 8. 하네스 시스템 (v2.4)

Pipeline 실행 후 자동으로 작동합니다. (백그라운드)

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

### 워크플로우
| 명령어 | 설명 |
|--------|------|
| `/init` | 초기 설정 (최초 1회) |
| `/prd` | PRD 생성 (대화형) |
| `/pipeline` | 전체 파이프라인 실행 |
| `/quick` | 빠른 실행 (Hotfix) |
| `/gate` | PRD 검증 |

### Git 협업 (v2.5)
| 명령어 | 설명 |
|--------|------|
| **`./update`** | Git 동기화 (안전) |
| **`./push-safe`** | 안전한 push + PR |
| `/git-guardian` | Secrets 스캔 + 커밋 |

### 코드 품질
| 명령어 | 설명 |
|--------|------|
| `/lint-smart` | 자동 린터 |
| `/audit` | 보안 스캔 |
| `/format-check` | 포맷 검사 |
| `/complexity` | 복잡도 분석 |
| `/review` | AI 코드 리뷰 |

### 문서화
| 명령어 | 설명 |
|--------|------|
| `/changelog` | CHANGELOG 생성 |
| `/bump` | 버전 업 + 태그 |
| `/api-docs` | API 문서 |
| `/readme-sync` | README 동기화 |

### 성능 분석
| 명령어 | 설명 |
|--------|------|
| `/bottleneck` | 병목 찾기 |
| `/profile` | 프로파일링 |
| `/bench` | 벤치마크 |
| `/mem-check` | 메모리 누수 |

### 작업 관리 (v2.6) 🆕
| 명령어 | 설명 |
|--------|------|
| `/save-point` | 작업 상태 저장/복구 (세이브포인트) |
| `/arch-review` | 아키텍처 리뷰 |
| `/weekly-recap` | 주간 회고 |

### 시스템
| 명령어 | 설명 |
|--------|------|
| `/stats` | 통계 확인 |
| `/mode` | 모드 변경 |
| `/harness` | 하네스 시스템 |

---

## 🧪 테스트

```bash
./tests/run_tests.sh           # 전체 테스트 (Python + bats)
./tests/run_tests.sh --python  # Python 테스트만
./tests/run_tests.sh --bats    # bats 테스트만
```

**테스트 커버리지**:
- Python unittest: 35개 테스트
- bats-core: 34개 테스트
- 총 69개 테스트 케이스

---

## ❓ FAQ

**Q: Claude Code가 없어도 되나요?**
- A: Bash fallback 모드로 제한 기능 제공되지만, Claude Code와 함께 사용할 때 최적의 성능을 발휘합니다.

**Q: 어떤 언어를 지원하나요?**
- A: PRD 생성은 **한국어, 영어, 중국어, 일본어**를 지원합니다. 코드 분석은 Python, JavaScript, TypeScript, Go, Java, Ruby, Rust 등을 지원합니다.

**Q: 기존 프로젝트에 적용 가능한가요?**
- A: 네, `./install.sh /path/to/project`로 기존 프로젝트에 설치할 수 있습니다.

**Q: 팀에서 함께 쓸 수 있나요?**
- A: 네! v2.5부터 Git 협업 스킬이 추가되어 팀 개발이 가능합니다:
  - `/update`로 원격 저장소 안전 동기화
  - `/push-safe`로 충돌 방지 전송
  - GitHub/GitLab/Bitbucket PR 자동 생성
  - 각 팀원이 설치 후 Git 워크플로우 사용 가능

**Q: PRD는 언제 작성하나요?**
- A: 복잡한 개발 작업 시작 전에 작성하는 것을 권장합니다. 간단한 수정이나 질문은 PRD 없이 자유롭게 대화 가능합니다.

---

## 🔄 업데이트

### 1. 현재 버전 확인

```bash
cat VERSION  # 또는 README 상단 배지 확인
```

### 2. 최신 버전 확인

**GitHub Release 확인:**
```bash
# 브라우저에서
https://github.com/loboking/monggle-vibe-coding-rules/releases
```

**또는 Git 태그 확인:**
```bash
git fetch origin --tags
git tag -l | tail -5  # 최근 5개 태그
```

### 3. 업데이트 방법

#### 방법 A: Git Clone (설치된 경우)

```bash
# 프로젝트 디렉토리로 이동
cd monggle-vibe-coding-rules

# 변경사항 확인 (선택사항)
git fetch origin
git log HEAD..origin/main --oneline  # 새로운 커밋 확인

# 업데이트
git pull origin main

# 재설치 (필요시)
./install.sh
```

#### 방법 B: Curl 원라인

```bash
# 전체 재설치
curl -fsSL https://raw.githubusercontent.com/loboking/monggle-vibe-coding-rules/main/install.sh | bash
```

> **💡 팁**: 설정 파일(`.claude/config/user.conf`)은 보존되므로 안심하고 업데이트하세요!

### 4. 업데이트 후 확인

```bash
# 버전 확인
cat VERSION

# 스킬 동작 테스트
/stats  # 통계 확인
```

### 5. 변경사항 확인

```bash
# 최근 5개 커밋
git log --oneline -5

# 최근 10개 커밋 상세
git log -10 --pretty=format:"%h - %s (%ar)" --author="loboking"

# 릴리스 노트 확인
# https://github.com/loboking/monggle-vibe-coding-rules/blob/main/CHANGELOG.md
```

### ⚠️ 업데이트 주의사항

- **설정 파일 보존**: `.claude/config/user.conf`는 자동으로 백업됩니다
- **PRD 파일 보존**: `prd/` 디렉토리는 영향받지 않습니다
- **로그 초기화**: `logs/` 디렉토리는 초기화될 수 있습니다
- **충돌 방지**: 작업 중인 파일은 커밋 후 업데이트하세요

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

**Vibe Coding Skills for Claude v2.6.0**

Made with ❤️ by [loboking](https://github.com/loboking)

</div>
