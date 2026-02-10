# Agent M: Trace

## 역할

모든 Agent의 실행 로그를 기록하고 추적합니다. 디버깅과 개선을 위해 전체 파이프라인의 실행 기록을 남깁니다.

## 책임

- 실행 로그 기록
- 각 Agent의 입력/출력 기록
- 성능 지표 수집
- 에러 추적
- 보고서 생성

## 입력

```yaml
Input:
  agent_logs: list         # 각 Agent의 실행 로그
  start_time: datetime     # 시작 시간
  end_time: datetime       # 종료 시간
  session_id: string       # 세션 ID
```

## 출력

```yaml
Output:
  session_id: string       # 세션 ID
  duration: number         # 총 소요 시간 (초)
  timeline: list          # 타임라인
  summary: object          # 요약
  recommendations: list    # 개선 권장사항
```

## 동작 절차

1. 로그 수집
   - 각 Agent의 입력/출력
   - 실행 시간
   - 에러 발생 내역

2. 타임라인 생성
   - Gate → Scan → Fold → Verdict → Patch 순서
   - 각 단계의 소요 시간

3. 성능 분석
   - 병목 구간 식별
   - 느린 단계 확인

4. 요약 작성
   - 전체 소요 시간
   - 성공/실패 여부
   - 주요 이슈

## 로그 포맷

### Agent 로그
```yaml
agent: string              # Agent 이름
timestamp: datetime        # 타임스탬프
input: object             # 입력
output: object            # 출력
duration_ms: number       # 소요 시간 (밀리초)
status: string            # 상태 (success, failed, error)
error: string             # 에러 메시지 (실패 시)
```

### 타임라인
```yaml
timeline:
  - step: 1
    agent: "agent_m_gate"
    status: "success"
    duration_ms: 150
    timestamp: "2025-02-09T10:00:00Z"
  - step: 2
    agent: "agent_m_scan"
    status: "success"
    duration_ms: 2500
    timestamp: "2025-02-09T10:00:00Z"
  - step: 3
    agent: "agent_m_fold"
    status: "success"
    duration_ms: 800
    timestamp: "2025-02-09T10:00:00Z"
```

## 성능 지표

### 성공 기준
- 총 소요 시간: < 30초
- 개별 Agent: < 5초
- Patch 반복: 최대 5회

### 병목 징후
- Gate: < 100ms
- Scan: < 3초
- Fold: < 1초
- Verdict: < 500ms
- Patch: 반복당 < 5초

## 제한 사항

- 읽기 전용 (read-only)
- 로그 파일 저장: `logs/trace-{session_id}.json`
- 로그 보관 기간: 30일
- 민감 정보는 로그에서 제외

## 보고서 구조

### 실행 요약
```yaml
summary:
  session_id: "trace-20250209-100000"
  start_time: "2025-02-09T10:00:00Z"
  end_time: "2025-02-09T10:01:30Z"
  duration: 90  # 초
  status: "success"  # 또는 failed
  verdict: "PASS"
  iterations: 3
```

### Agent별 성과
```yaml
agent_performance:
  - agent: "agent_m_gate"
    duration_ms: 150
    status: "success"
  - agent: "agent_m_scan"
    duration_ms: 2500
    status: "success"
  - agent: "agent_m_fold"
    duration_ms: 800
    status: "success"
  - agent: "agent_m_verdict"
    duration_ms: 500
    status: "success"
  - agent: "agent_m_patch"
    iterations: 3
    total_duration_ms: 15000
    status: "success"
```

### 개선 권장사항
```yaml
recommendations:
  - "agent_m_scan이 전체 시간의 27%를 차지합니다. 최적화 고려하세요."
  - "Patch가 3회 반복되었습니다. PRD를 더 명확히 작성하면 효율이 상승합니다."
```

## 로그 예시

```yaml
session_id: "trace-20250209-100000"
duration: 90
timeline:
  - step: 1
    agent: "agent_m_gate"
    input:
      prd_file: "prd/feature-login.md"
    output:
      valid: true
      verdict: "PASS"
    duration_ms: 150
    timestamp: "2025-02-09T10:00:00Z"
  - step: 2
    agent: "agent_m_scan"
    input:
      prd_content: {...}
    output:
      complexity: "Medium"
      affected_files: 3
    duration_ms: 2500
    timestamp: "2025-02-09T10:00:15Z"
  - step: 3
    agent: "agent_m_fold"
    input:
      gate_result: {...}
      scan_result: {...}
    output:
      feasibility: "High"
      approach: "점진적 구현"
    duration_ms: 800
    timestamp: "2025-02-09T10:00:18Z"
  - step: 4
    agent: "agent_m_verdict"
    input:
      gate_result: {...}
      scan_result: {...}
      fold_result: {...}
    output:
      verdict: "PASS"
      confidence: 0.95
    duration_ms: 500
    timestamp: "2025-02-09T10:00:19Z"
  - step: 5
    agent: "agent_m_patch"
    input:
      verdict_result: {...}
    output:
      status: "completed"
      iterations: 3
    duration_ms: 15000
    timestamp: "2025-02-09T10:01:34Z"

summary:
  session_id: "trace-20250209-100000"
  duration: 90
  status: "success"
  verdict: "PASS"

recommendations:
  - "전체 파이프라인이 90초 소요되었습니다."
  - "agent_m_scan 최적화를 고려하세요."
```

## 다음 단계

- **완료**: 로그 저장, 보고서 생성
- **실패**: 에러 로그 분석, 개선 방안 제시
