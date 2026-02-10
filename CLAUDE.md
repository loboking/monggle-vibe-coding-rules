# Vibe Coding Rules

> 이 프로젝트는 **Agent 기반 Vibe Coding 방법론**을 따릅니다.
> **PRD 없이는 어떠한 개발 요청도 응답하지 않습니다.**

---

## 핵심 원칙

1. **PRD 먼저** - 코딩 전에 반드시 PRD 확인/작성
2. **Agent 파이프라인** - 모든 작업은 Agent 검증을 거쳐야 함
3. **AI가 검증** - 리뷰/검증/판단은 AI가 담당
4. **개발자는 집중** - 구현과 창의성에만 집중
5. **자유로운 실험** - 개인 브랜치에서 마음껏

---

## Agent 파이프라인

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

## PRD 타입

### 1. 프로젝트 PRD (`.project-prd.md`)
프로젝트 시작 시 **1회성**으로 작성합니다.

```bash
# 생성
python3 scripts/init_core.py my-project-prd.md

# 위치
project-root/.project-prd.md
```

**포함 내용:**
- 프로젝트 개요
- 기술 스택 (언어, 프레임워크)
- Git 저장소 설정
- CI/CD 설정

### 2. 작업 PRD (`prd/feature-*.md`, `prd/bug-*.md`, 등)
개별 기능/버그/리팩토링 작업 시 작성합니다.

**생성 방법:**
```bash
# 템플릿 복사
cp prd/feature.md prd/feature-user-auth-20250209.md

# 또는 템플릿 선택
cp prd/bug.md prd/bugfix-login-error-20250209.md
cp prd/refactor.md prd/refactor-auth-module-20250209.md
cp prd/experiment.md prd/experiment-ai-recommend-20250209.md
```

**PRD 타입별 용도:**
| 타입 | 템플릿 | 용도 |
|------|--------|------|
| **Feature** | `prd/feature.md` | 새로운 기능 개발 |
| **Bugfix** | `prd/bug.md` | 버그 수정 |
| **Refactor** | `prd/refactor.md` | 코드 리팩토링 |
| **Experiment** | `prd/experiment.md` | 실험적 기능 시도 |

---

## 금지된 Free Chat

### ❌ PRD 없는 요청 (응답 거부)

```
사용자: "로그인 기능 추가해줘"
AI: "❌ PRD가 없습니다. 먼저 prd/feature-*.md를 작성해주세요."
```

### ✅ PRD 있는 요청 (정상 응답)

```
사용자: "prd/feature-user-auth.md 구현해줘"
AI: "✅ Agent 파이프라인을 시작합니다..."
```

---

## 프로젝트 구조

```
project-root/
├── .project-prd.md          # 프로젝트 PRD (1회성)
├── prd/                     # 작업 PRD 폴더
│   ├── feature-*.md         # 기능 PRD
│   ├── bug-*.md             # 버그 PRD
│   ├── refactor-*.md        # 리팩토링 PRD
│   └── experiment-*.md      # 실험 PRD
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
└── logs/                    # 실행 로그
    └── trace-*.json         # 세션별 추적 로그
```

---

## 개발 워크플로우

### 1. 새 프로젝트 시작
```bash
# 1. 프로젝트 PRD 작성
python3 scripts/init_core.py my-project-prd.md

# 2. Git 초기화 및 CI/CD 설정 (자동)
```

### 2. 새 기능 개발
```bash
# 1. PRD 작성
cp prd/feature.md prd/feature-user-auth.md
# -> PRD 내용 작성

# 2. Agent 파이프라인 실행
# "prd/feature-user-auth.md 구현해줘"

# 3. Agent가 자동으로 처리
# Gate → Scan → Fold → Verdict → Patch → Trace
```

### 3. 버그 수정
```bash
# 1. Bug PRD 작성
cp prd/bug.md prd/bugfix-login-error.md

# 2. 원인 분석 및 수정 계획 작성

# 3. Agent 파이프라인 실행
# "prd/bugfix-login-error.md 수정해줘"
```

---

## 코딩 규칙

### 커밋 메시지
```
type(scope): description

Types: feat, fix, refactor, test, docs, chore
```

### 브랜치 규칙
- 개인 작업: `dev/{user}/{feature}`
- main 직접 Push 금지
- 모든 변경은 PR 통해서만

### PR 규칙
- **PRD 링크 필수**
- PR당 하나의 기능/수정
- CI 통과 후 머지

---

## 테스트 요구사항

| 단계 | 테스트 | 차단 여부 |
|------|--------|----------|
| 개인 브랜치 | TDD, Lint | No |
| PR | Feature, Scenario | Yes |
| Main Merge | Full, Integration | Yes |

---

## 금지 사항

- ❌ **main 직접 Push**
- ❌ **PRD 없이 기능 개발**
- ❌ **테스트 없이 PR 생성**
- ❌ **CI 실패 상태로 머지**
- ❌ **PRD 없는 Free Chat 요청**

---

## Agent 실행 예시

### 성공 사례 (PASS)
```
Gate: ✅ PASS (모든 필수 섹션 존재)
Scan: ✅ 영향 파일 3개, 중복 없음
Fold: ✅ 실행 가능성 High, 점진적 접근 권장
Verdict: ✅ PASS (confidence: 0.95)
Patch: ✅ 3회 반복 후 완료
Trace: ✅ 총 90초 소요, 개선 권장사항 2건
```

### 수정 필요 (FIX)
```
Gate: ⚠️ FIX (Edge Cases 섹션 누락)
Scan: ✅ 영향 분석 완료
Fold: ⚠️ 일부 위험 요소 존재
Verdict: ⚠️ FIX (Edge Cases 추가 후 재검토)
```

### 실패 (FAIL)
```
Gate: ❌ FAIL (필수 섹션 3개 누락)
Verdict: ❌ FAIL (PRD 보완 필요)
```

---

## 최종 선언

> "버그 없는 시스템이 아닌, 실패를 통제하고 반복하지 않는 시스템을 만든다."

---

## 최근 변경 내역

> 이 섹션은 Claude Code hooks에 의해 자동으로 업데이트됩니다.


### 2026-02-09

**변경된 파일 수**: 10개 (Agent 시스템 도입)

```
[생성] agents/agent_m_gate.md
[생성] agents/agent_m_scan.md
[생성] agents/agent_m_fold.md
[생성] agents/agent_m_verdict.md
[생성] agents/agent_m_patch.md
[생성] agents/agent_m_trace.md
[생성] prd/feature.md
[생성] prd/bug.md
[생성] prd/refactor.md
[생성] prd/experiment.md
[수정] rules/verdict_rules.yaml
[수정] rules/patch_policy.md
[수정] CLAUDE.md - Agent 기반 시스템으로 변경
```

---

## 사용 가이드

### PRD 작성 체크리스트
- [ ] Front Matter YAML 완성
- [ ] 필수 섹션 모두 작성
- [ ] Tech Stack 명시
- [ ] Testing 계획 포함
- [ ] Edge Cases 고려

### Agent 파이프라인 실행
- [ ] PRD 파일 경로 확인
- [ ] `prd/{type}-{name}.md` 형식 준수
- [ ] Agent에게 PRD 파일 경로 전달
- [ ] Verdict 결과 확인
- [ ] Patch 로그 확인

---

### 문서
- [Agent 상세 정의](./agents/)
- [PRD 템플릿](./prd/)
- [Verdict 규칙](./rules/verdict_rules.yaml)
- [Patch 정책](./rules/patch_policy.md)
