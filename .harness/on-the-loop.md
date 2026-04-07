# On the Loop: 하네스 개선 가이드

## 개념

> "On the Loop" vs "In the Loop"
> - **In the Loop**: 매번 출력을 검토하고 수정 (AI가 하던 일을 대신)
> - **On the Loop**: 하네스 자체를 개선 (AI가 더 잘할 수 있도록)

## 원칙

1. **결과 수정 > 출력 수정**: AI 결과가 틀리면 원인을 찾아 하네스에 반영
2. **패턴 발견**: 반복되는 실수는 가이드/센서 부족 신호
3. **�진적 개선**: 한 번에 모든 것을 고치려 하지 말고

## Guides + Sensors 점검

### Computational Guides (결정론적, 행동 전)
- [ ] 린터/포매터 설정 충분?
- [ ] 템플릿이 모든 edge case 커버?
- [ ] 타입 검사 strict 모드?

### Inferential Guides (AI 기반, 행동 전)
- [ ] PRD Validation이 충분한 피드백?
- [ ] Pipeline Gate가 올바른 질문?
- [ ] Verdict confidence threshold 적절?

### Computational Sensors (결정론적, 행동 후)
- [ ] 테스트 커버리지 충분?
- [ ] CI에서 잡히는 것들이 있나?
- [ ] 포맷 검증이 걸러내나?

### Inferential Sensors (AI 기반, 행동 후)
- [ ] /stats 추세를 확인?
- [ ] 실패 패턴 분석?
- [ ] LLM-as-judge 활용?

## Doom Loop 감지 시

### 징후
- 같은 파일을 3번 이상 수정
- 동일 에러가 반복
- 성공률이 50% 미만

### 조치
1. `loop-detection.json` 확인
2. 해당 파일/작업 패턴 분석
3. 가이드 또는 센서 추가
4. `improvement-log.jsonl`에 기록

## 개선 제안 형식

```json
{
  "timestamp": "ISO 8601",
  "type": "guide_addition|sensor_addition|threshold_tune",
  "agent": "pipeline|review|etc",
  "severity": "critical|major|minor|info",
  "observation": "관찰된 문제",
  "recommendation": "구체적 제안",
  "expected_impact": "기대 효과"
}
```

## 예시

### Case 1: 반복되는 버그 수정
```
Observation: utils.py에서 같은 함수를 3번 수정
Recommendation: 단위 테스트 추가 (Computational Sensor)
Impact: 사이클 타임 감소, 재발 방지
```

### Case 2: PRD가 자주 거부됨
```
Observation: Verdict FIX가 60% 이상
Recommendation: PRD 템플릿에 예시 추가 (Inferential Guide)
Impact: 초기 품질 향상, 재작업 감소
```

### Case 3: 린터가 잡지 못하는 스타일
```
Observation: 코드 리뷰에서 동일 스타일 문제 지적
Recommendation: 커스텀 린트 규칙 추가 (Computational Guide)
Impact: 일관성 향상, 리뷰 부하 감소
```
