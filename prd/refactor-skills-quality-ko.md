# 12개 스킬 코드 품질 개선 리팩토링

```yaml
---
refactor_id: "SKILLS-REFACTOR-001"
refactor_name: "12개 스킬 보안 및 아키텍처 개선"
refactor_type: "refactor"
scope: "architecture"
complexity: "medium"
priority: "P0"
assignee: ""
estimated_hours: "16"
risk_level: "medium"
---
```

---

## 1. Current Issues (현재 문제점)

### 1.1 Critical 보안 취약점

| 파일 | 라인 | 문제 | 심각도 |
|------|------|------|--------|
| `changelog.sh` | 142 | `eval git log` Command Injection | 🔴 Critical |
| `api-docs.sh` | 58-59 | Path Traversal 위험 | 🔴 Critical |
| `audit.sh` | 270-280 | 사용자 입력 검증 부족 | 🟠 High |

### 1.2 안정성 문제

| 파일 | 라인 | 문제 | 영향 |
|------|------|------|------|
| `mem-check.sh` | 507 | `JSON_OUTPUT` 미선언 변수 사용 | JSON 출력 기능 미작동 |
| `readme-sync.sh` | 38 | 함수 정의 전 호출 | `--sections` 플래그 에러 |
| `prd.sh` | 41-47 | 중복 변수 선언 | 코드 품질 저하 |

### 1.3 포터빌리티 문제

| 문제 | 영향 파일 | 설명 |
|------|-----------|------|
| macOS `sed -i` 비호환 | `bump.sh`, `readme-sync.sh` | macOS에서 에러 발생 |
| `set -eo pipefail` | 전체 12개 파일 | `-u` 플래그 누락으로 unset 변수 미감지 |
| 과도한 `\|\| true` 사용 | `lint-smart.sh` 등 | 실제 에러를 마스킹 |

### 1.4 코드 중복

- 12개 파일에 동일한 `case "$project_type"` 패턴 반복
- 각 파일이 독립적으로 프로젝트 타입 감지 로직 구현

---

## 2. Proposed Changes (제안 변경 사항)

### 2.1 Phase 1: 보안 취약점 수정 (우선순위: 최상)

#### changelog.sh - eval 제거

**Before:**
```bash
commits=$(eval git log $git_args 2>/dev/null || true)
```

**After:**
```bash
local git_log_args=()
[[ -n "$from_tag" ]] && git_log_args+=("${from_tag}..${to_tag:-HEAD}")
[[ -n "$since_date" ]] && git_log_args+=("--since=${since_date}")
commits=$(git log --pretty=format:%h\|%s\|%an\|%ad --date=short "${git_log_args[@]}" 2>/dev/null || true)
```

#### api-docs.sh - 경로 검증 추가

**추가:**
```bash
# 경로 검증
if [[ "$OUTPUT_DIR" != "${PROJECT_ROOT}"/* ]]; then
    die "Output directory must be within project root"
fi
```

#### audit.sh - 패턴 이스케이프 추가

```bash
# 고정 문자열 매칭 사용
for pattern in "${patterns[@]}"; do
    matches=$(grep -rF "$pattern" ... || true)  # -F for fixed strings
done
```

### 2.2 Phase 2: 공통 라이브러리 강화

#### 새로운 구조

```
.claude/commands/
├── lib/
│   ├── core.sh         # 에러 처리, 로깅 (기존)
│   ├── platform.sh     # OS별 호환성 (신규)
│   ├── validation.sh   # 입력 검증 (신규)
│   └── git.sh          # 안전한 git 연산 (신규)
├── common.sh           # 메인 진입점
└── *.sh                # 개별 스크립트
```

#### platform.sh - 포터블한 함수들

```bash
# macOS/Linux 호환 sed -i
sed_inplace() {
    local expr="$1"
    local file="$2"
    if [[ "$(uname -s)" == "Darwin" ]]; then
        sed -i '' "$expr" "$file"
    else
        sed -i "$expr" "$file"
    fi
}

# 안전한 git log
safe_git_log() {
    local -n git_args=$1
    git log --pretty=format:'%h|%s|%an|%ad' --date=short "${git_args[@]}"
}
```

#### validation.sh - 입력 검증

```bash
validate_file_path() {
    local path="$1"
    [[ ! "$path" =~ ^/ ]] && die "Absolute path required: $path"
    [[ "$path" =~ \.\. ]] && die "Path traversal detected: $path"
}

validate_threshold() {
    local value="$1"
    [[ ! "$value" =~ ^[0-9]+$ ]] && die "Threshold must be a positive integer"
}
```

### 2.3 Phase 3: 에러 처리 표준화

#### 전체 파일에 적용

```bash
# 모든 스크립트 상단
set -euo pipefail  # -u 추가: unset 변수 에러 처리
```

#### || true 사용 최소화

**Before:**
```bash
pylint **/*.py 2>/dev/null || true
```

**After:**
```bash
if ! pylint **/*.py 2>/dev/null; then
    log_warn "Pylint found issues"
    lint_errors=1
fi
```

### 2.4 Phase 4: 버그 수정

#### mem-check.sh

```bash
# Configuration 섹션에 추가
JSON_OUTPUT=0

# Argument parser에 추가
--json)
    JSON_OUTPUT=1
    shift
    ;;
```

#### readme-sync.sh

```bash
# list_sections 함수 정의를 인자 파싱 전으로 이동 (라인 66 → 라인 20)
```

#### prd.sh

```bash
# 라인 41-47 중복 선언 삭제
```

---

## 3. Impact (영향 분석)

### 3.1 호환성

| 항목 | 영향 |
|------|------|
| **기존 API** | CLI 인터페이스 유지 |
| **사용자** | 사용법 변경 없음 |
| **기존 기능** | 모든 기능 유지, 안정성 향상 |

### 3.2 잠재 위험

| 위험 | 완화 방안 |
|------|----------|
| 리팩토링 중 일시적 기능 장애 | Git 브랜치 사용, 점진적 병합 |
| macOS 호환성 테스트 부족 | CI에서 macOS 테스트 추가 |
| 테스트 커버리지 일시적 저하 | 단위 테스트 먼저 작성 |

---

## 4. Testing (테스트 계획)

### 4.1 테스트 전략

1. **단위 테스트**: lib/ 각 모듈별 테스트
2. **통합 테스트**: 각 스크립트 실행 테스트
3. **정적 분석**: ShellCheck 전파 통과
4. **포터빌리티**: Linux + macOS CI 테스트

### 4.2 기능 동등성 테스트

| 항목 | 테스트 방법 |
|------|------------|
| PRD 생성 | `/prd feature` 실행 후 파일 확인 |
| Changelog 생성 | `/changelog` 실행 후 출력 확인 |
| Lint 실행 | `/lint-smart` 실행 후 에러 코드 확인 |
| 각 스크립트 도움말 | `--help` 플래그 동작 확인 |

### 4.3 보안 테스트

| 항목 | 테스트 방법 |
|------|------------|
| Command Injection | 악의적인 인자 전달 시 차단 확인 |
| Path Traversal | `../` 포함 경로 거부 확인 |
| eval 사용 | ShellCheck SC2048 룰 통과 확인 |

---

## 5. Migration Plan (마이그레이션 계획)

### Week 1: Critical 수정

```bash
Day 1-2: 보안 취약점 수정
  - changelog.sh eval 제거
  - api-docs.sh 경로 검증
  - audit.sh 패턴 이스케이프

Day 3-4: 버그 수정
  - mem-check.sh JSON_OUTPUT 추가
  - readme-sync.sh 함수 순서 수정
  - prd.sh 중복 제거

Day 5: lib/ 구조 생성
  - platform.sh, validation.sh, git.sh 작성
```

### Week 2: 표준화 및 테스트

```bash
Day 1-2: 에러 처리 표준화
  - set -euo pipefail로 통일
  - || true 사용 최소화

Day 3-4: 단위 테스트 작성
  - lib/ 함수들 테스트
  - 핵심 스크립트 테스트

Day 5: CI 통합
  - ShellCheck CI 추가
  - macOS/Linux matrix 테스트
```

---

## 6. Rollback Plan (롤백 계획)

- 각 Phase별 Git 브랜치 생성
- 문제 발생 시 `git revert` 또는 브랜치 삭제
- 원본 코드는 `main` 브랜치에 보존

---

## 7. Success Criteria (성공 기준)

### 보안

- [ ] ShellCheck SC2048 (eval) 0건
- [ ] ShellCheck SC2086 (quote) 0건
- [ ] 입력 검증覆盖率 100%

### 안정성

- [ ] set -euo pipefail 적용 100%
- [ ] || true 사용 < 5개
- [ ] 단위 테스트 통과율 100%

### 포터빌리티

- [ ] macOS CI 통과
- [ ] Linux CI 통과
- [ ] sed_inplace 함수 테스트 통과

### 코드 품질

- [ ] 코드 중복 < 10%
- [ ] 함수 문서화 100%
- [ ] 복잡도 점수 감소

---

## 8. 예상 작업 시간

| 단계 | 작업 | 시간 |
|------|------|------|
| 1 | 보안 취약점 수정 | 4시간 |
| 2 | 버그 수정 | 2시간 |
| 3 | lib/ 구조 작성 | 4시간 |
| 4 | 에러 처리 표준화 | 3시간 |
| 5 | 단위 테스트 작성 | 4시간 |
| 6 | CI 통합 | 2시간 |
| **합계** | | **19시간** |

---

## 9. 참고 자료

- [Bash Scripting Best Practices](https://github.com/alexandreborba/bash-script-best-practices)
- [ShellCheck Wiki](https://www.shellcheck.net/wiki/)
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
