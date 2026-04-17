# PRD: Vibe Coding Rules v3.0 고도화 개발

> **PRD Type:** feature
> **Created:** 2026-04-17
> **Status:** ✅ Completed
> **Priority:** P0
> **Completed:** 2026-04-17

---

## 1. 개요

### 1.1 목적

현재 Vibe Coding Rules v2.4의 핵심 엔진을 고도화하여 AI 기반 코딩 워크플로우의 완성도를 높입니다.

### 1.2 배경

- 현재 v2.4는 기본 파이프라인과 루프 감지가 구현되어 있으나, 실무 사용 시 불편함이 존재
- 사용자 피드백: 충돌 해결이 어렵다, TDD 강제가 약하다, 요구사항 수집이 불편하다

---

## 2. 개발 항목별 상세 명세

### 2.1 ① 사전 인터뷰 및 브레인스토밍 모드 (Requirement Gathering)

#### 현재 상태
- `/prd` 명령어로 PRD 생성
- 템플릿 기반 질문

#### 개선 필요 사항
| 항목 | 현재 | 목표 |
|------|------|------|
| 요구사항 수집 | 정적 템플릿 | 핑퐁 대화 기반 |
| 제약사항 추출 | 수동 입력 | 자동 추출 |
| 문서화 | 일반 마크다운 | Nano Banana 컨셉 시각화 |

#### 구현 내용

**2.1.1 핑퐁 대화 시스템**
```bash
/brainstorm [topic]
```

- 사용자의 자유로운 아이디어를 구조화된 질문으로 변환
- 질문-답변 반복하여 요구사항 명확화
- 완료 시 PRD 자동 생성

**2.1.2 제약사항 자동 추출**
- 대화 내용에서 키워드 추출
- 예: "Pure 알고리즘", "O(n)", "메모리 상한 1GB"

**2.1.3 Nano Banana 컨셉 적용**
- 문서화를 시각적 구조로 표현
- ASCII 다이어그램, 테이블, 코드 블록 활용

---

### 2.2 ② TDD 기반 에이전트 파이프라인 (Implementation)

#### 현재 상태
- `/pipeline` 명령어로 6단계 실행
- 테스트 파일: tests/test_*.py, tests/bash/*.bats

#### 개선 필요 사항
| 항목 | 현재 | 목표 |
|------|------|------|
| 테스트 작성 순서 | 구현 후 테스트 가능 | 테스트 우선 강제 |
| SSOT 참조 | 부분 | claude.md 완전 참조 |

#### 구현 내용

**2.2.1 Test-First 강제**

Pipeline `Patch` 단계 수정:
```python
def patch_stage(prd_file):
    # 1. 실패하는 테스트 작성 강제
    test_file = generate_failing_test(prd_file)

    # 2. 테스트 실행 → 반드시 실패 확인
    if not run_test(test_file):
        raise Exception("Test must fail first")

    # 3. 구현 코드 작성
    implement_feature(prd_file)

    # 4. 테스트 실행 → 성공 확인
    if not run_test(test_file):
        raise Exception("Implementation failed")
```

**2.2.2 claude.md SSOT 참조**

모든 코드 생성 시 claude.md 규격 준수 확인:
```python
def validate_against_claude_md(code):
    rules = load_claude_md_rules()

    for rule in rules:
        if not rule.check(code):
            return False, rule.violation_message()

    return True, "OK"
```

**2.2.3 자동 품질 체크**

Patch 완료 후 자동 실행:
- `lint-smart`: 프로젝트 자동 감지 린터
- `complexity`: 복잡도 분석

---

### 2.3 ③ Fail-Fast 및 스마트 롤백 (Self-Healing)

#### 현재 상태
- `.claude/lib/loop_detection.sh`: 루프 감지 라이브러리
- `max_modifications: 5`, `max_consecutive_failures: 3`

#### 개선 필요 사항
| 항목 | 현재 | 목표 |
|------|------|------|
| 루프 감지 | 파일 단위 | PRD 단위 |
| 롤백 | 수동 | 자동 |
| 원인 분석 | 없음 | 자동 보고 |

#### 구현 내용

**2.3.1 PRD 단위 루프 감지**

기존 파일 단위에서 PRD 단위로 확장:
```bash
# .harness/prd-loop-detection.json
{
  "prd_file": "prd/feature-xxx.md",
  "attempts": [
    {"timestamp": "...", "stage": "patch", "result": "failure", "files": ["src/a.py"]},
    {"timestamp": "...", "stage": "patch", "result": "failure", "files": ["src/a.py", "src/b.py"]}
  ],
  "consecutive_failures": 2
}
```

**2.3.2 자동 롤백**

3회 연속 실패 시:
```bash
# 1. 중단
echo "FAIL-FAST: 3 consecutive failures detected"

# 2. 마지막 안정 상태로 롤백
git checkout STABLE_COMMIT

# 3. 실패 분석 보고서 생성
generate_failure_report()
```

**2.3.3 원인 분석 보고서**

`.harness/failure-analysis-{timestamp}.md`:
```markdown
# Failure Analysis Report

## Root Cause
- **Type**: 기획의 모호함
- **Evidence**: 같은 파일을 3회 수정 실패

## Recommendations
1. `/prd --update prd/feature-xxx.md`로 PRD 수정
2. 제약사항 명확화 필요
```

---

### 2.4 ④ 팀 모드: 동기화 및 충돌 해결 (Conflict Resolution)

#### 현재 상태
- `.claude/lib/conflict_helper.sh`: 충돌 해결 도구
- `/update`: Git 동기화 스크립트

#### 개선 필요 사항
| 항목 | 현재 | 목표 |
|------|------|------|
| 작업 전 확인 | 없음 | git fetch 강제 |
| 충돌 해결 | 수동 가이드 | 자동 해결 선택지 |
| 진입 블록 | 없음 | 해결 전 블록 |

#### 구현 내용

**2.4.1 작업 전 강제 확인**

모든 Pipeline 실행 전 `git fetch` 실행:
```bash
# pipeline.sh 추가
pre_pipeline_check() {
    git fetch origin

    if is_behind_origin; then
        echo "⚠️ 원본에 새로운 변경사항이 있습니다."
        echo "   먼저 /update를 실행하세요."
        exit 1
    fi
}
```

**2.4.2 충돌 해결 선택지 제공**

```bash
# 충돌 감지 시
echo "충돌이 발생했습니다. 해결 방법을 선택하세요:"
echo "  1) /auto-fix      - AI가 자동 병합 후 빌드 테스트"
echo "  2) /resolve-keep  - 내 변경 유지"
echo "  3) /resolve-theirs- 원본 변경 유지"
echo "  4) /resolve-merge - 수동 병합 가이드"
```

**2.4.3 해결 전 블록**

```bash
# 충돌 상태 확인
has_conflicts() {
    [ -n "$(git diff --name-only --diff-filter=U)" ]
}

# 충돌 해결 전 다음 단계 진입 차단
until ! has_conflicts; do
    echo "충돌 해결이 필요합니다."
    sleep 5
done
```

---

## 3. 설계 원칙

| 원칙 | 설명 | 적용 범위 |
|------|------|----------|
| **Single Source of Truth** | 모든 코드는 PRD + claude.md 규격 준수 | 전체 |
| **Fail-Fast** | 실패를 빠르게 노출, 에러 위에 코드 쌓지 않음 | 파이프라인 |
| **User Control** | 자동화 제공하되 최종 결정권은 사용자 | 전체 |

---

## 4. 기술 스택

| 영역 | 기술 | 비고 |
|------|------|------|
| 스크립트 | Bash | 기존 유지 |
| PRD 생성 | Python 3.8+ | scripts/prd_creator.py |
| 루프 감지 | Bash + jq | .claude/lib/loop_detection.sh |
| Git 연동 | Git | 충돌 해결 |

---

## 5. 우선순위

### P0 (즉시 구현) - ✅ 완료
1. ✅ 루프 감지 PRD 단위 확장 - 완료
2. ✅ Test-First 강제 - 완료

### P1 (다음 릴리스) - ✅ 완료
3. ✅ 핑퐁 대화 시스템 - 완료
4. ✅ Git 동기화 확인 (팀 모드) - 완료

### P2 (장기) - ✅ 완료
5. ✅ 원인 분석 자동화 - 고도화 완료
6. ✅ 제약사항 자동 추출 - 고도화 완료 (+ 프리토킹 모드)

---

## 6. 성공 기준

| 항목 | 기준 |
|------|------|
| 루프 감지 | 3회 실패 시 100% 중단 |
| TDD 준수 | Patch 단계 100% Test-First |
| 충돌 해결 | 사용자 선택지 4개 제공 |

---

## 7. 파일 구조

```
.claude/
├── commands/
│   ├── brainstorm.sh      # 신규: 핑퐁 대화 모드
│   ├── auto-fix.sh        # 신규: 충돌 자동 해결
│   ├── resolve-keep.sh    # 신규: 내 변경 유지
│   ├── resolve-theirs.sh  # 신규: 원본 변경 유지
│   └── resolve-merge.sh   # 신규: 수동 병합 가이드
├── lib/
│   ├── loop_detection.sh  # 수정: PRD 단위 감지 추가
│   ├── conflict_helper.sh # 수정: 자동 해결 로직 추가
│   └── tdd_enforcer.sh    # 신규: Test-First 강제
└── hooks/
    └── pre-patch.sh       # 신규: Patch 전 테스트 확인

.harness/
├── loop-detection.json    # 수정: PRD 필드 추가
├── prd-loop-detection.json # 신규: PRD 단위 루프 감지
└── failure-analysis-*.md  # 신규: 실패 분석 보고서

prd/
└── templates/
    └── brainstorm.md      # 신규: 브레인스토밍 템플릿
```

---

## 8. 개발 단계

### Phase 1: 루프 감지 고도화
- PRD 단위 루프 감지 추가
- 자동 롤백 구현

### Phase 2: TDD 강제
- Test-First 훅 추가
- claude.md SSOT 검증

### Phase 3: 팀 모드 강화
- 작업 전 확인 강제
- 충돌 해결 선택지 제공

### Phase 4: 브레인스토밍
- 핑퐁 대화 시스템
- 제약사항 자동 추출

---

## 9. 참고 문서

- `.claude/docs/git-collaboration.md`: Git 협업 가이드
- `.harness/HARNESS_ANALYSIS.md`: 하네스 방법론 분석
- `CLAUDE.md`: 프로젝트 규칙

---

## 10. 구현 완료 보고서

### 완료일: 2026-04-17

### 구현 항목

#### ① 핑퐁 대화 시스템 ✅
- **파일**: `.claude/commands/prd.sh`, `.claude/commands/brainstorm.sh`
- **기능**:
  - `--pingpong` 또는 `-p` 옵션으로 핑퐁 모드 진입
  - 자연스러운 질문-답변 형식으로 요구사항 수집
  - 세션 저장: `.claude/.pingpong/current-session.json`
  - 컨텍스트 인식 다음 질문 생성

```bash
/prd --pingpong          # 핑퐁 모드로 PRD 생성
/brainstorm [topic]      # 브레인스토밍 모드
```

#### ② TDD Test-First 강제 ✅
- **파일**: `.claude/lib/tdd_enforcer.sh`
- **기능**:
  - `tdd_pre_patch_hook()` - Patch 전 테스트 확인
  - `tdd_validate_before_patch()` - 테스트 파일 존재 검증
  - 프로젝트 타입 자동 감지 (Python, Node, Java, Go, Rust, Bash)
  - 실패하는 테스트 먼저 작성 원칙 강제

```bash
source .claude/lib/tdd_enforcer.sh
tdd_pre_patch_hook <prd_file>
```

#### ③ PRD 단위 루프 감지 ✅
- **파일**: `.claude/lib/loop_detection.sh`
- **기능**:
  - `loop_check_prd()` - PRD 루프 감지 (3회 연속 실패)
  - `loop_record_prd_attempt()` - 시도 기록
  - `loop_is_prd_in_loop()` - 루프 상태 확인
  - 실패 분석 보고서 자동 생성

```bash
loop_check_prd <prd_file>                    # 루프 체크
loop_record_prd_attempt <prd> <status>      # 기록
loop_generate_failure_report <prd>          # 보고서
```

#### ④ 팀 모드 Git 동기화 확인 ✅
- **파일**: `.claude/commands/pipeline.sh`
- **기능**:
  - `pre_pipeline_git_check()` - Pipeline 실행 전 Git 확인
  - 자동 `git fetch` 실행
  - 뒤처짐 감지 시 진행 차단 및 안내

```bash
# pipeline.sh 내부
pre_pipeline_git_check() {
    git fetch origin
    if is_behind_origin; then
        echo "⚠️ 원본에 새로운 변경사항이 있습니다."
        echo "   먼저 /update를 실행하세요."
        return 1
    fi
}
```

### 통합 확인

모든 기능이 `pipeline.sh`에 통합되어 있습니다:
1. Pipeline 실행 전 Git 동기화 확인
2. PRD 루프 감지 (3회 연속 실패 시 중단)
3. TDD 검증 (Patch 단계 전)

### 사용 예시

```bash
# 1. 핑퐁 모드로 PRD 생성
/prd --pingpong

# 2. Pipeline 실행 (모든 안정장치 작동)
/pipeline prd/feature.md

# 3. 상태 확인
/stats --verbose
```

---

**PRD Version:** 1.2
**Last Updated:** 2026-04-17
**Implementation Status:** ✅ Complete (All P0, P1, P2)

---

## 11. P2 고도화 구현 상세

### ① 원인 분석 자동화 고도화 ✅

**파일**: `.claude/lib/loop_detection.sh`

**추가 기능**:
- `_loop_analyze_patterns()` - 반복 패턴 감지 (파일, 단계)
- `_loop_create_sparkline()` - 시각적 스파크라인 생성
- `_loop_create_timeline()` - 타임라인 생성
- `_loop_classify_root_cause()` - 원인 분류 (기술적 복잡도, 단계 장애물)
- 고도화된 `loop_generate_failure_report()` - 상세 보고서

**보고서 내용**:
```markdown
## 🔍 Failure Analysis Report

### 📊 실패 요약
### 📈 실패 패턴 분석
- 🔁 반복 실패 파일
- 🔄 반복 실패 단계

### 📅 타임라인 (최근 10회)
### 🔬 원인 분류
- 🏗️ 기술적 복잡도
- 🚫 단계별 장애물
- 🔀 복합적 원인

### 💡 권장 조치
```

### ② 제약사항 자동 추출 고도화 + 프리토킹 모드 ✅

**파일**: `.claude/commands/brainstorm.sh`

**제약사항 추출 카테고리**:
- ⚡ 성능: 시간복잡도(O(n)), 지연시간(ms), 처리량(TPS/QPS)
- 💾 메모리: 용량 제한(GB/MB), 효율성
- 🖥️ 플랫폼: 브라우저, 모바일, 반응형, IE
- 🔒 보안: 인증, 암호화, 개인정보(PII), GDPR
- 🎨 디자인: 심플, 미니멀, 다이내믹, 애니메이션
- 📅 기간: 긴급, 우선순위(P0/P1)
- 📊 데이터: 대용량, 실시간

**프리토킹 모드**:
```bash
/brainstorm --free          # 또는 -f
```

- 자연스러운 대화 흐름
- 구조화된 질문 없음
- `/analyze`, `/constraints` 명령어로 분석 가능

**분석 명령어**:
- `/analyze` - 전체 세션 분석
- `/constraints` - 제약사항만 표시

**예시 출력**:
```
╔════════════════════════════════════════════════╗
║     📊 세션 분석 보고서                       ║
╚════════════════════════════════════════════════╝

주제: 로그인 기능
대화 수: 5회

⚡ 성능: 지연시간: 100ms
💾 메모리: 없음
🖥️  플랫폼: 모바일/반응형
🔒 보안: 인증/보안 필요
🎨 디자인: 심플/미니멀
🎯 우선순위: P0
📅 기간: 긴급
📊 데이터: 없음
```
