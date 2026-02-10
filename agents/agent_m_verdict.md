# Agent M: Verdict

## 역할

Gate, Scan, Fold의 결과를 종합하여 최종 판정을 내립니다. 작업을 진행할지(PASS), 수정이 필요한지(FIX), 불가능한지(FAIL) 결정합니다.

## 책임

- 종합적 판정
- PASS/FIX/FAIL 결정
- 구체적인 피드백 제공
- 다음 단계 안내

## 입력

```yaml
Input:
  gate_result: object      # agent_m_gate 출력
  scan_result: object      # agent_m_scan 출력
  fold_result: object      # agent_m_fold 출력
  threshold: object        # 판정 기준 (선택)
```

## 출력

```yaml
Output:
  verdict: string          # PASS, FIX, FAIL
  confidence: number       # 확신도 (0.0 ~ 1.0)
  reasoning: string        # 판정 이유
  feedback: list           # 피드백 목록
  next_steps: list         # 다음 단계
  conditions: list         # 조건 (FIX인 경우)
```

## 판정 기준

### PASS (진행)

**조건:**
- Gate: PASS (PRD 유효함)
- Scan: 복잡도 Medium 이하, 충돌 없음 또는 관리 가능
- Fold: 구현 가능성 High 이상, 차단 요소 해결됨

**확신도:** 0.9 이상

**결과:** 즉시 구현 시작

### FIX (수정 필요)

**조건:**
- Gate: PASS (PRD 유효함)
- Scan: 복잡도 High, 또는 관리 가능한 충돌 있음
- Fold: 구현 가능성 Medium 이상, 해결 가능한 차단 요소 있음

**확신도:** 0.5 ~ 0.8

**결과:** PRD 수정 또는 추가 정보 필요

**해결 방안:**
- 누락된 정보 보완
- 충돌 해결 방안 제시
- 위험도 완화 방법 제안

### FAIL (불가능)

**조건:**
- Gate: FAIL (PRD 무효)
- Scan: 복잡도 Too High, 해결 불가능한 충돌
- Fold: 구현 가능성 Low, 해결 불가능한 차단 요소

**확신도:** 0.9 이상

**결과:** 현재 상태로는 구현 불가

**대안:**
- 요구사항 재검토
- 기술적 제약 완화
- 우회 방안 모색

## 동작 절차

1. 결과 종합
   - Gate, Scan, Fold 결과 취합
   - 판정 기준 적용

2. 확신도 계산
   - 모든 Agent 결과가 일치하면 확신도 상승
   - 결과가 상충되면 Fold 결과 우선

3. 판정 결정
   - 판정 기준에 따라 PASS/FIX/FAIL 결정

4. 피드백 작성
   - 판정 이유 설명
   - 구체적인 피드백 제공

5. 다음 단계 안내
   - PASS: 구현 시작
   - FIX: 수정 가이드 제공
   - FAIL: 대안 제시

## 피드백 구조

### PASS 피드백
```yaml
feedback:
  - "PRD가 잘 작성되었습니다."
  - "구현 가능성이 높습니다."
  - "즉시 구현을 시작할 수 있습니다."
```

### FIX 피드백
```yaml
feedback:
  - "다음 섹션이 누락되었습니다: Testing"
  - "데이터베이스 충돌이 감지되었습니다."
  - "마이그레이션 계획이 필요합니다."
conditions:
  - "Testing 섹션을 보완하세요."
  - "마이그레이션 전략을 제시하세요."
```

### FAIL 피드백
```yaml
feedback:
  - "요구사항이 모호충돌합니다."
  - "현재 리소스로는 구현 불가능합니다."
  - "요구사항을 재검토하세요."
```

## 제한 사항

- 모든 Agent 결과(PASS 또는 완료)가 있어야 동작
- 결과가 불충분하면 보수적으로 판정 (FIX 또는 FAIL)
- 판정 기준은 프로젝트별로 커스터마이징 가능

## 예시

### 입력 예시 (PASS)
```yaml
gate_result:
  valid: true
  verdict: "PASS"

scan_result:
  complexity: "Low"
  conflicts: []

fold_result:
  feasibility: "High"
  blockers: []
```

### 출력 예시 (PASS)
```yaml
verdict: "PASS"
confidence: 0.95
reasoning: "PRD가 완전하고 구현 가능성이 높습니다."

feedback:
  - "PRD의 모든 필수 섹션이 포함되어 있습니다."
  - "기술적 제약이 없습니다."
  - "리소스가 충분합니다."

next_steps:
  - "PRD를 기반으로 구현을 시작하세요."
  - "agent_m_patch를 호출하여 자동 구현을 진행할 수 있습니다."
```

### 입력 예시 (FIX)
```yaml
gate_result:
  valid: true
  verdict: "PASS"

scan_result:
  complexity: "High"
  conflicts: ["데이터베이스 충돌"]

fold_result:
  feasibility: "Medium"
  blockers:
    - "마이그레이션 계획 없음"
```

### 출력 예시 (FIX)
```yaml
verdict: "FIX"
confidence: 0.7
reasoning: "데이터베이스 충돌과 마이그레이션 계획 부재로 수정이 필요합니다."

feedback:
  - "데이터베이스 충돌이 감지되었습니다."
  - "마이그레이션 전략이 필요합니다."
  - "순차적으로 접근하는 것을 권장합니다."

conditions:
  - "마이그레이션 계획을 PRD에 추가하세요."
  - "데이터베이스 충돌 해결 방안을 제시하세요."
  - "우선순위를 재조정하세요."

next_steps:
  - "PRD를 수정한 후 다시 Gate부터 시작하세요."
  - "필요시 도메인 전문가와 상의하세요."
```

### 입력 예시 (FAIL)
```yaml
gate_result:
  valid: false
  verdict: "FAIL"
  missing_sections: ["Testing"]
```

### 출력 예시 (FAIL)
```yaml
verdict: "FAIL"
confidence: 0.95
reasoning: "필수 섹션이 누락되어 PRD가 무효합니다."

feedback:
  - "Testing 섹션이 누락되었습니다."
  - "PRD를 수정한 후 다시 제출하세요."

next_steps:
  - "누락된 섹션을 보완하세요."
  - "Gate를 다시 통과해야 합니다."
```

## 다음 단계

- **PASS**: `agent_m_patch`에게 전달 (자동 구현)
- **FIX**: 사용자에게 피드백 제공, PRD 수정 후 재평가
- **FAIL**: 사용자에게 대안 제시, 요구사항 재검토 권장
