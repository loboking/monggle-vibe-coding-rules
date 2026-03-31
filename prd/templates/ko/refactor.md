# Refactor PRD Template

> 코드 리팩토링 작업을 할 때 사용하는 템플릿입니다.

---

## 🔵 Front Matter

```yaml
---
refactor_id: ""               # 리팩토링 ID (선택)
refactor_name: ""             # 리팩토링 이름 (예: 인증 모듈 리팩토링)
refactor_type: "refactor"     # 타입: refactor (고정)
scope: ""                    # 범위: module, function, architecture
complexity: ""                # 복잡도: low, medium, high
priority: ""                  # 우선순위: P0, P1, P2, P3
assignee: ""                   # 담당자 (선택)
estimated_hours: ""            # 예상 작업 시간 (선택)
risk_level: ""                 # 위험도: low, medium, high
---
```

---

## 📋 필수 섹션

### 1. Current Issues (현재 문제점)

현재 코드의 문제점을 설명하세요.

**예시:**
```
현재 인증 모듈은 다음과 같은 문제가 있습니다:
1. 단일 책임 원칙 위반: UserService가 인증, 권한, 세션을 모두 담당
2. 테스트 어려움: 모든 기능이 하나의 클래스에 몰려 있어 테스트가 어려움
3. 확장성 부족: 새로운 인증 방식을 추가하려면 UserService를 수정해야 함
```

### 2. Proposed Changes (제안 변경 사항)

구체적인 리팩토링 방안을 설명하세요.

#### 새로운 구조
- [구조 1]
- [구조 2]

#### 기대 효과
- [효과 1]
- [효과 2]

#### 수정 대상 파일
- `src/auth/service.py`: [수정 내용]
- `src/auth/repository.py`: [신규]
- `src/auth/schema.py`: [신규]

### 3. Impact (영향 분석)

리팩토링이 시스템에 미치는 영향을 분석하세요.

#### 호환성
- **기존 API**: (예: 기존 API 인터페이스 유지)
- **데이터베이스**: (예: 스키마 변경 없음)
- **외부 의존성**: (예: 새로운 라이브러리 추가)

#### 잠재 위험
- [위험 1]: (예: 리팩토링 중 일시적 기능 장애 가능)
- [위험 2]: (예: 테스트 커버리지 일시적 저하)

### 4. Testing (테스트 계획)

리팩토링 후 기능 동등성을 보장하기 위한 테스트 계획을 설명하세요.

#### 테스트 전략
- [테스트 전략 1]
- [테스트 전략 2]

#### 기능 동등성 테스트
- [테스트 항목 1]
- [테스트 항목 2]

#### 성능 테스트
- [성능 테스트 항목 1]
- [성능 테스트 항목 2]

---

## 📝 선택 섹션

### 5. Migration Plan (마이그레이션 계획)

기존 코드를 새로운 구조로 안전하게 전환하는 계획을 설명하세요.

- **Phase 1**: [단계 1]
- **Phase 2**: [단계 2]
- **Phase 3**: [단계 3]

### 6. Rollback Plan (롤백 계획

문제 발생 시 기존 코드로 복구하는 계획을 설명하세요.

- (예: Git 브랜치 사용하여 롤백)

### 7. Success Criteria (성공 기준)

리팩토링이 성공적으로 완료되었는지 판단할 기준을 명시하세요.

- [ ] [기준 1]
- [ ] [기준 2]
- [ ] [기준 3]

---

## 사용 가이드

1. 이 템플릿을 `prd/` 폴더에 복사하세요.
2. Front Matter의 필수 필드를 채우세요.
3. 필수 섹션(1-4)을 작성하세요.
4. 선택 섹션(5-7)은 필요에 따라 작성하세요.
5. 파일을 저장하고 Agent 파이프라인을 실행하세요.

---

## 예시

```yaml
---
refactor_id: "AUTH-REFACTOR-001"
refactor_name: "인증 모듈 리팩토링"
refactor_type: "refactor"
scope: "module"
complexity: "high"
priority: "P1"
assignee: "john"
estimated_hours: "16"
risk_level: "medium"
---

# 인증 모듈 리팩토링

## Current Issues

현재 인증 모듈은 다음과 같은 문제가 있습니다:
1. 단일 책임 원칙 위반: UserService가 인증, 권한, 세션을 모두 담당
2. 테스트 어려움: 모든 기능이 하나의 클래스에 몰려 있어 테스트가 어려움
3. 확장성 부족: 새로운 인증 방식을 추가하려면 UserService를 수정해야 함

## Proposed Changes

### 새로운 구조
- `AuthService`: 인증 로직 (로그인, 로그아웃)
- `PermissionService`: 권한 체크
- `SessionService`: 세션 관리
- `UserRepository`: 데이터베이스 접근

### 기대 효과
- 단일 책임 원칙 준수
- 각 서비스를 독립적으로 테스트 가능
- 새로운 인증 방식 추가 시 해당 Service만 수정

### 수정 대상 파일
- `src/auth/service.py`: 3개 클래스로 분리
- `src/auth/repository.py`: DB 접근 로직 분리
- `tests/test_auth.py`: 각 서비스별 테스트 작성

## Impact

### 호환성
- **기존 API**: API 인터페이스 유지
- **데이터베이스**: 스키마 변경 없음
- **외부 의존성**: 의존성 없음

### 잠재 위험
- 리팩토링 중 일시적 기능 장애 가능
- 테스트 커버리지 일시적 저하
- Git 병합 충돌 가능성

## Testing

### 테스트 전략
- 파이프라인 기반 점진적 리팩토링
- 각 Phase별 기능 동등성 테스트

### 기능 동등성 테스트
- 모든 기존 테스트 통과
- 새로운 테스트 추가 (서비스 분리 테스트)

### 성능 테스트
- 리팩토링 전후 성능 비교
- 목표: 성능 저하 5% 이내
```
