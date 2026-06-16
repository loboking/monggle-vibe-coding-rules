# Vibe Coding Rules - 자동 완성 & 오타 교정

## 🚀 설치

### 1. Bash/Zsh 자동 완성

```bash
# ~/.bashrc 또는 ~/.zshrc에 추가
echo 'source ~/.claude/commands/completions-v2.bash' >> ~/.bashrc
source ~/.bashrc
```

### 2. 오타 자동 교정 (래퍼)

```bash
# ~/.bashrc 또는 ~/.zshrc에 추가
echo 'source ~/.claude/commands/wrapper.sh' >> ~/.bashrc
source ~/.bashrc
```

---

## ✨ 기능

### 1. 옵션 자동 완성 (v3.1 확장)

```bash
/smart-qa --[Tab]        # --android, --ios, --web, --mobile, --server, --code, --report
/stats --[Tab]           # --web, --json, --filter-verdict, ...
/qa --[Tab]              # --report, --quick, --format, ...
/prd --[Tab]             # --non-interactive, --output, --language, ...
/prd [Tab]               # feature, bug, refactor, api, migration, ml, devops
/impact --[Tab]          # --diff, --deep, --verbose
/debug --[Tab]           # --web, --css, --perf, --mem, --verbose
/review --[Tab]          # --code, --arch, --diff
/save-point [Tab]        # list, resume, restore, cleanup
/mode [Tab]              # solo, team, manual, semi-auto, auto
```

### 2. 오타 자동 교정

```bash
/qaa                    # → /qa 로 자동 교정 후 실행
/debugg                 # → /debug 로 자동 교정 후 실행
/changlog               # → /changelog 로 자동 교정 후 실행
/stats --verbos         # → --verbose 로 자동 교정
```

### 3. 값 추천

```bash
/stats --filter-verdict [Tab]   # PASS | FIX | FAIL
/prd --language [Tab]           # ko | en | zh | ja
/qa --format [Tab]              # json | text | markdown
/prd [Tab]                      # feature | bug | refactor | hotfix | api | migration | ml | devops
/mode [Tab]                     # solo | team | manual | semi-auto | auto
```

---

## 📋 사용 예시

### Smart QA (v3.1) 🆕

```bash
/smart-qa                   # 자동 감지 + 전체 테스트 + 수정
/smart-qa --android         # Android 프로젝트 테스트
/smart-qa --ios             # iOS 프로젝트 테스트
/smart-qa --web             # Web 프론트엔드 테스트
/smart-qa --mobile          # Mobile (Android + iOS) 테스트
/smart-qa --server          # 서버/백엔드 테스트
/smart-qa --code            # 코드 전체 테스트
/smart-qa --web --report    # Web 보고서만 (수정 없음)
/smart-qa --report          # 자동 감지 + 보고서만 (읽기 전용)
/smart-qa --android --report # Android 보고서
/smart-qa --web --report --json # Web JSON 보고서
```

### QA

```bash
/qa                             # 전체 테스트 + 자동 수정
/qa --report                    # 보고서만 (수정 없음)
/qa --quick                     # 빠른 테스트
/qa --format json               # JSON 출력
/qa src/auth.ts                 # 특정 파일 테스트
/qa debug review                # debug, review 스킬 테스트
/qa [pipeline|stats]            # pipeline, stats 스킬 테스트
```

### Stats

```bash
/stats --web                    # 웹 대시보드
/stats --json --filter-type feature   # 필터링
/stats --filter-verdict PASS    # PASS만
```

### PRD

```bash
/prd feature                    # feature PRD
/prd api --language en          # 영문 API PRD
/prd --list-templates           # 템플릿 목록
/prd migration                  # migration PRD
/prd ml                         # ML PRD
```

### Impact (v3.1) 🆕

```bash
/impact --diff HEAD~1           # diff 기반 분석
/impact --deep                  # 심층 분석 (Agent)
/impact --verbose               # 상세 출력
```

### Debug (v3.1) 🆕

```bash
/debug --web                    # 프론트엔드 디버깅
/debug --css                    # CSS 디버깅
/debug --perf                   # 성능 디버깅
/debug --mem                    # 메모리 디버깅
```

### Pipeline

```bash
/pipeline --dry-run             # 계획만
/pipeline --retry 3             # 3회 재시도
/pipeline --parallel            # 병렬 실행
```

### Mode (v3.1) 🆕

```bash
/mode solo                      # Solo 모드
/mode team                      # Team 모드
/mode manual                    # Manual 모드
/mode semi-auto                 # Semi-auto 모드
```

---

## 🎯 오타 교정 규칙

### 자동 교정되는 패턴

| 입력 | 교정됨 |
|-----|--------|
| `debugg`, `debuger` | `debug` |
| `qaa`, `testt` | `qa` |
| `log`, `logs` | `changelog` |
| `ver`, `version` | `bump` |
| `push`, `gitpush` | `push-safe` |
| `stat`, `stats` | `stats` |
| `lint` | `lint-smart` |
| `idea` | `brainstorm` |
| `save`, `checkpoint` | `save-point` |
| `hotfix`, `fix` | `quick` |
| `impact`, `side-effect` | `impact` (v3.1) |

### 편집 거리 (Levenshtein)

최대 3개의 오타까지 자동 교정:
- `changelog` → `changlog` (1 오타)
- `changelog` → `chagelog` (1 오타)
- `changelog` → `chnagelog` (2 오타)

---

## 🔧 직접 실행

래퍼 없이 직접 실행:

```bash
~/.claude/commands/dispatcher.sh qa --report
~/.claude/commands/dispatcher.sh stats --web
~/.claude/commands/impact.sh --diff HEAD~1
~/.claude/commands/debug.sh --web
~/.claude/commands/smart-qa.sh --android
~/.claude/commands/smart-qa.sh --web --report
~/.claude/commands/docs.sh index
```

---

## 📝 명령어 별칭

| 별칭 | 실제 명령 |
|-----|----------|
| `debug` | `debug-master` |
| `debug-perf` | `bottleneck` |
| `debug-web` | `debug-web` |
| `debug-css` | `debug-css` |
| `debug-m` | `mem-check` |
| `review-code` | `code-reviewer` |
| `review-arch` | `arch-review` |
| `log`, `logs` | `changelog` |
| `ver`, `version` | `bump` |
| `push`, `gitpush` | `push-safe` |
| `stat` | `stats` |
| `lint` | `lint-smart` |
| `idea` | `brainstorm` |
| `save`, `checkpoint` | `save-point` |
| `hotfix`, `fix` | `quick` |
| `docs` | `docs` |
| `readme` | `tech-doc-writer` |
| `impact` | `impact` (v3.1) |
| `smart-qa` | `smart-qa` (v3.1) |
| `smart-qa-read` | `smart-qa --report` |
