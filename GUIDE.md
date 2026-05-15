# Vibe Coding Skills 사용 가이드

## 📖 목차

1. [빠른 시작](#빠른-시작)
2. [자주 쓰는 명령어](#자주-쓰는-명령어)
3. [카테고리별 명령어](#카테고리별-명령어)
4. [기능 상세 설명](#기능-상세-설명)
5. [문제 해결](#문제-해결)

---

## 🚀 빠른 시작

### 설치

```bash
git clone https://github.com/loboking/monggle-vibe-coding-rules.git
cd monggle-vibe-coding-rules
./install.sh
```

### 초기 설정

```bash
/init                    # 작업 모드, PRD 언어, 사용자 정보 설정
```

---

## 💡 자주 쓰는 명령어

| 명령어 | 설명 | 사용 예시 |
|--------|------|----------|
| `/help` | 전체 명령어 보기 | `/help debug` |
| `/init` | 초기 설정 | `/init --reset` |
| `/prd` | 기획서 생성 | `/prd feature` |
| `/debug` | 디버깅 | `/debug --web` |
| `/qa` | 테스트 | `/qa --report` |
| `/review` | 코드 리뷰 | `/review --code` |
| `/changelog` | 변경 로그 | `/changelog` |
| `/push-safe` | 안전한 Git push | `./push-safe` |
| `/brain` | 뇌 시스템 | `/brain save bug` |
| `/super` | 간단 요청 → 상세 요구사항 | `/super 로그인 추가` |

---

## 📂 카테고리별 명령어

### 🔍 디버그

| 명령어 | 설명 |
|--------|------|
| `/debug` | 통합 디버깅 |
| `/debug --web` | 프론트엔드 디버깅 |
| `/debug --css` | CSS 디버깅 |
| `/debug --perf` | 성능 병목 분석 |
| `/debug --mem` | 메모리 누수 탐지 |
| `/bottleneck` | 성능 병목 찾기 |
| `/mem-check` | 메모리 누수 |

### ✅ QA

| 명령어 | 설명 |
|--------|------|
| `/qa` | QA 테스트 (fix 포함) |
| `/qa --report` | 보고서만 |
| `/qa --quick` | 빠른 테스트 |

### 👁️ 리뷰

| 명령어 | 설명 |
|--------|------|
| `/review` | PR diff 리뷰 |
| `/review --code` | 코드 품질 리뷰 |
| `/review --arch` | 아키텍처 리뷰 |
| `/code-reviewer` | SOLID/보안 검토 |
| `/arch-review` | 아키텍처/설계 리뷰 |

### 📊 분석

| 명령어 | 설명 |
|--------|------|
| `/audit` | 보안 취약점 스캔 |
| `/complexity` | 코드 복잡도 분석 |
| `/impact` | 영향도 분석 |
| `/profile` | 프로파일링 |

### 📝 문서

| 명령어 | 설명 |
|--------|------|
| `/changelog` | Git 로그 → CHANGELOG.md |
| `/bump` | 버전 업 + Git 태그 |
| `/api-docs` | Docstring → API 문서 |
| `/readme-sync` | README 동기화 |

### 🔧 Git

| 명령어 | 설명 |
|--------|------|
| `./update` | 안전한 Git 동기화 |
| `./push-safe` | 안전한 push + PR |
| `/git-guardian` | Secrets 스캔 + 커밋 |

### 💻 개발

| 명령어 | 설명 |
|--------|------|
| `/quick` | 빠른 핫픽스 |
| `/format-check` | 코드 포맷 검사 |
| `/lint-smart` | 프로젝트 자동 감지 후 린터 |

### 🧠 뇌 시스템

| 명령어 | 설명 |
|--------|------|
| `/brain` | 뇌 통계 보기 |
| `/brain save <type>` | 뉴런 수동 저장 |
| `/brain query <tags>` | 태그로 검색 |
| `/brain recall <id>` | 특정 뉴런 로드 |
| `/brain cleanup` | 망각 청소 |

### 🛠️ 유틸리티

| 명령어 | 설명 |
|--------|------|
| `/bench` | 벤치마크 실행/비교 |
| `/brainstorm` | 아이디어 브레인스토밍 |
| `/save-point` | 작업 상태 저장/복구 |
| `/weekly-recap` | 주간 회고 |

### ⚙️ 설정

| 명령어 | 설명 |
|--------|------|
| `/mode solo` | Solo 모드로 변경 |
| `/mode team` | Team 모드로 변경 |
| `/monggle-upgrade` | 업그레이드 체크 및 설치 |

### 🧰 툴킷

| 명령어 | 설명 |
|--------|------|
| `/duo` | Claude + Gemini 협업 |
| `/run` | 작업 복잡도 분석 → 최적 도구 선택 |
| `/super` | 간단 요청 → 상세 요구사항 |
| `/gemini` | Gemini 서브에이전트 호출 |
| `/planner` | 프로젝트 기획서 작성 |
| `/doc-writer` | 프로젝트 문서 자동 생성 |

---

## 🔧 기능 상세 설명

### 1. PRD 생성 (다국어 지원)

```bash
/prd                     # 대화형 PRD 생성
/prd feature             # 새 기능 PRD
/prd bug                 # 버그 수정 PRD
/prd api                 # API 설계 PRD
/prd --language en       # 영어 PRD
```

**지원 타입**: `feature`, `bug`, `refactor`, `hotfix`, `experiment`, `api`, `migration`, `ml`, `devops`

### 2. Agent Pipeline

```
Gate(검증) → Scan(분석) → Fold(평가) → Verdict(판단) → Patch(구현) → Trace(기록)
```

```bash
/pipeline prd/feature-xyz.md     # 전체 파이프라인 실행
/quick prd/hotfix.md             # 빠른 실행 (Gate/Fold 생략)
```

### 3. 오타 자동 교정

```bash
/qaa                    # → /qa
/debugg                 # → /debug
/changlog               # → /changelog
```

### 4. 의도 기반 스킬 실행

```
"너무 느려" → /bottleneck
"보안 문제 없나?" → /audit
"기획 좀 세워줘" → /prd
"코드 올릴게" → /push-safe
```

### 5. 뇌 시스템

**구조:**
- 해마 (Hippocampus): 단기 기억 (24시간)
- 대뇌피질 (Neocortex): 장기 기억
- 시냅스 (Synapses): 뉴런 연결
- 편도체 (Amygdala): 감정 가중치
- 망각 곡선: 오래된 기억 자동 삭제

---

## ❓ 문제 해결

### 스킬이 보이지 않을 때

```bash
cd ~/.claude/commands
./fix-skills.sh
# 또는
cd monggle-vibe-coding-rules
./install.sh
```

### 실행 권한 오류

```bash
chmod +x ~/.claude/commands/*.sh
```

---

## 📜 License

[MIT License](LICENSE)

---

Made with ❤️ by [loboking](https://github.com/loboking)
