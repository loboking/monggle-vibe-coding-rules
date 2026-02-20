# Hotfix PRD Template

> 긴급 버그 수정을 위한 경량 PRD 템플릿입니다.
> 일반적인 버그 수정은 `prd/bug.md`를 사용하세요.

---

## Front Matter

```yaml
---
feature_name: ""               # 수정 이름 (예: 로그인 오류 긴급 수정)
feature_type: "hotfix"         # 타입: hotfix (고정)
priority: "high"               # 항상 high
severity: ""                   # 심각도: critical | high | medium
issue_url: ""                  # 이슈 트래커 URL (선택)
assignee: ""                   # 담당자
estimated_minutes: ""          # 예상 소요 시간 (분 단위)
tags: ["hotfix", "urgent"]     # 태그
---
```

---

## 필수 섹션

### 1. Issue (문제)

긴급 수정이 필요한 문제를 간단히 설명하세요.

**예시:**
```
프로덕션 환경에서 사용자 로그인 시 500 에러가 발생하여
모든 사용자가 서비스를 이용할 수 없습니다.
```

### 2. Quick Fix (빠른 수정)

핵심 수정 내용을 간단히 설명하세요.

**예시:**
```
Null 참조 체크 누락으로 인한 예외 발생.
user 객체의 None 체크를 추가하여 예외 방지.
```

**코드 변경:**
```python
# Before
def login(email):
    return user.token  # user가 None이면 에러

# After
def login(email):
    if not user:
        raise InvalidCredentialsError()
    return user.token
```

### 3. Testing (테스트)

빠른 테스트 방법을 설명하세요.

- **수정 전**: (예: 유효하지 않은 이메일로 로그인 시도 → 500 에러)
- **수정 후**: (예: 유효하지 않은 이메일로 로그인 시도 → 401 에러)

---

## 선택 섹션

### 4. Root Cause (근본 원인)

문제의 근본 원인 분석 (필요한 경우).

```
최근 리팩토링에서 user 객체 생성 로직이 변경되었으나,
login 함수에서 Null 체크를 추가하지 않음.
```

### 5. Prevention (재발 방지)

향후 재발 방지 대책 (필요한 경우).

```
- 함수 시작 부분에 인자 유효성 검사 추가
- 단위 테스트에 None 입력 케이스 추가
```

---

## 사용 가이드

1. 이 템플릿을 `prd/` 폴더에 복사하세요.
2. Front Matter의 필수 필드를 채우세요.
3. 필수 섹션(1-3)을 빠르게 작성하세요 (5분 내외).
4. `/quick` 명령어로 파이프라인을 실행하세요.

---

## 사용 시나리오

**Hotfix 사용이 적합한 경우:**
- 프로덕션 서비스 중단
- 데이터 손실 위험
- 보안 취약점 노출
- 사용자 경험에 치명적인 영향

**Hotfix 사용이 부적절한 경우:**
- 일반적인 버그 (→ `prd/bug.md` 사용)
- 새로운 기능 추가 (→ `prd/feature.md` 사용)
- 리팩토링 (→ `prd/refactor.md` 사용)

---

## 파이프라인 차이점

**일반 PRD vs Hotfix:**

| 단계 | 일반 PRD | Hotfix |
|------|----------|--------|
| Gate | 전체 섹션 검증 | 최소 섹션만 검증 |
| Scan | 전체 영향 분석 | 영향 범위 빠르게 확인 |
| Fold | 실행 가능성 평가 | **SKIP** (시간 절약) |
| Verdict | PASS/FIX/FAIL | PASS/FIX/FAIL |
| Patch | 구현 (최대 5회 반복) | 구현 (최대 2회 반복) |
| Trace | 전체 로그 | 핵심 로그만 |

---

## 예시

```yaml
---
feature_name: "로그인 500 에러 긴급 수정"
feature_type: "hotfix"
priority: "high"
severity: "critical"
issue_url: "https://github.com/xxx/issues/123"
assignee: "john"
estimated_minutes: "15"
tags: ["hotfix", "urgent", "production"]
---

# 로그인 500 에러 긴급 수정

## Issue

프로덕션 환경에서 유효하지 않은 이메일로 로그인 시도 시
서버가 500 Internal Server Error를 반환합니다.
현재 모든 사용자가 영향을 받고 있습니다.

## Quick Fix

`login()` 함수에서 `user` 객체가 None일 경우 처리가 누락되었습니다.

**변경 위치:** `app/auth.py:45`

**Before:**
```python
def login(email: str, password: str) -> str:
    user = db.get_user(email)
    return user.token  # None → 500 Error
```

**After:**
```python
def login(email: str, password: str) -> str:
    user = db.get_user(email)
    if not user:
        raise InvalidCredentialsError("Invalid email or password")
    return user.token
```

**예상 소요 시간:** 15분
- 코드 수정: 5분
- 테스트: 5분
- 배포: 5분

## Testing

### 사전 테스트
```bash
# 유효하지 않은 이메일로 로그인 시도
curl -X POST /api/login -d '{"email": "invalid@test.com", "password": "wrong"}'
# 기대: 500 Internal Server Error (현재)
```

### 사후 테스트
```bash
# 동일 요청
curl -X POST /api/login -d '{"email": "invalid@test.com", "password": "wrong"}'
# 기대: 401 Unauthorized, {"error": "Invalid email or password"}
```

### 추가 테스트
- 유효한 이메일/비밀번호: 정상 로그인 (200 OK)
- 빈 이메일: 400 Bad Request
- SQL Injection 시도: 400 Bad Request
```

---

## 주의사항

1. **Hotfix는 긴급 상황에만 사용**
2. **최소한의 변경만 수행**
3. **테스트는 필수** (심각한 버그를 만들지 않도록)
4. **Hotfix 후 정식 PRD 작성 권장** (근본 원인 분석 및 재발 방지)
5. **코드 리뷰 우회 가능** (긴급 상황)
6. **배포 후 모니터링 필수**
