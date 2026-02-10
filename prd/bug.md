# Bug PRD Template

> 버그 수정 작업을 할 때 사용하는 템플릿입니다.

---

## 🔵 Front Matter

```yaml
---
bug_id: ""                    # 버그 ID (선택)
bug_name: ""                 # 버그 이름 (예: 로그인 시 500 에러)
bug_type: ""                 # 타입: bugfix (고정)
severity: ""                  # 심각도: critical, high, medium, low
priority: ""                  # 우선순위: P0, P1, P2, P3
affected_version: ""           # 영향받는 버전 (선택)
environment: ""                # 발생 환경 (선택)
reporter: ""                   # 보고자 (선택)
assignee: ""                   # 담당자 (선택)
estimated_hours: ""            # 예상 작업 시간 (선택)
---
```

---

## 📋 필수 섹션

### 1. Issue Description (이슈 설명)

발생한 문제를 상세히 설명하세요.

**예시:**
```
사용자가 로그인 버튼을 클릭했을 때,
HTTP 500 Internal Server Error가 발생하고 로그인되지 않습니다.
에러 로그에는 "AttributeError: 'NoneType' object has no attribute 'user'"가 표시됩니다.
```

### 2. Root Cause (원인 분석)

문제의 근본 원인을 분석하세요.

**예시:**
```
User 모델에서 `email` 필드가 NULL인 사용자가 DB에 존재합니다.
로그인 로직이 `user.email`을 참조할 때 NoneType 에러가 발생합니다.
원인: 회원가입 시 이메일 검증 로직이 누락되어 NULL 값이 저장됨.
```

### 3. Fix Plan (수정 계획)

구체적인 수정 방안을 설명하세요.

#### 해결 방법
- [해결 방법 1]
- [해결 방법 2]

#### 수정 대상 파일
- `src/auth/login.py`: [수정 내용]
- `src/models/user.py`: [수정 내용]
- `tests/test_auth.py`: [테스트 추가]

### 4. Testing (테스트 계획)

수정 후 재발 방지를 위한 테스트 계획을 설명하세요.

#### 재발 방지 테스트
- [테스트 항목 1]
- [테스트 항목 2]

#### 회귀 테스트
- [기존 기능 테스트 1]
- [기존 기능 테스트 2]

---

## 📝 선택 섹션

### 5. Impact Analysis (영향 분석)

수정이 시스템 다른 부분에 미치는 영향을 분석하세요.

- **영향받는 모듈**: (예: 인증 모듈, 세션 관리)
- **데이터 변경**: (예: 사용자 데이터 마이그레이션 필요)
- **API 변경**: (예: 로그인 API 응답 변경)

### 6. Temporary Workaround (임시 조치)

영구적인 수정 전까지 사용할 임시 조치가 있다면 설명하세요.

- (예: 에러 로그를 추가하고, 수동으로 NULL 이메일을 수정)

### 7. Prevention (예방 방책)

재발 방지를 위한 예방책을 설명하세요.

- [예방책 1]
- [예방책 2]

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
bug_id: "AUTH-500"
bug_name: "로그인 시 500 에러"
bug_type: "bugfix"
severity: "high"
priority: "P1"
affected_version: "v1.2.0"
environment: "production"
reporter: "jane"
assignee: "john"
estimated_hours: "4"
---

# 로그인 시 500 에러

## Issue Description

사용자가 로그인 버튼을 클릭했을 때,
HTTP 500 Internal Server Error가 발생하고 로그인되지 않습니다.
에러 로그에는 "AttributeError: 'NoneType' object has no attribute 'user'"가 표시됩니다.

## Root Cause

User 모델에서 `email` 필드가 NULL인 사용자가 DB에 존재합니다.
로그인 로직이 `user.email`을 참조할 때 NoneType 에러가 발생합니다.
원인: 회원가입 시 이메일 검증 로직이 누락되어 NULL 값이 저장됨.

## Fix Plan

### 해결 방법
1. 회원가입 시 이메일 검증 로직 추가
2. DB에 NULL 이메일을 가진 사용자 제거 스크립트 작성
3. 로그인 로직에 NULL 체크 추가

### 수정 대상 파일
- `src/auth/register.py`: 이메일 중복 체크 로직 추가
- `scripts/clean_null_users.py`: NULL 이메일 사용자 정리 스크립트
- `src/auth/login.py`: NULL 체크 추가
- `tests/test_auth.py`: NULL 사용자 로그인 시도 테스트 추가

## Testing

### 재발 방지 테스트
- NULL 이메일로 가입 시도
- 중복 이메일로 가입 시도

### 회귀 테스트
- 정상 이메일로 로그인
- 소셜 로그인
```
