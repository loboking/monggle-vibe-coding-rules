---
allowed-tools: Read, Grep, Glob, Bash, WebFetch, WebSearch, LSP
description: 보안성 검증 - OWASP Top 10, STRIDE, 취약점 분석 (읽기 전용)
---

# /security - 보안성 검증 전용 스킬

AI 기반 보안 검증: OWASP Top 10, STRIDE 위협 모델링, 코드 취약점 분석. **읽기 전용**으로 절대 코드를 수정하지 않습니다.

## 사용법

```bash
/security "코드 또는 설계"       # 전체 보안 검증
/security --owasp "내용"        # OWASP Top 10 기반
/security --stride "아키텍처"   # STRIDE 위협 모델링
/security --auth "인증 코드"    # 인증/인가 검증
/security --sql "쿼리"          # SQL Injection 검증
/security --xss "입력"          # XSS 검증
/security --crypto "암호화"     # 암호화 구현 검증
```

## 검증 카테고리

| 카테고리 | 설명 |
|----------|------|
| **owasp** | OWASP Top 10 (2021) 기반 |
| **stride** | STRIDE 위협 모델링 |
| **auth** | 인증/인가 |
| **injection** | SQL, NoSQL, OS Command, LDAP Injection |
| **xss** | Cross-Site Scripting |
| **crypto** | 암호화/해시/키 관리 |
| **data** | 데이터 보안 (민감 정보, PII) |
| **api** | API 보안 |

## 옵션

| 옵션 | 설명 |
|------|------|
| `--owasp` | OWASP Top 10 기반 검증 |
| `--stride` | STRIDE 위협 모델링 |
| `--auth` | 인증/인가 검증 |
| `--sql` | SQL Injection 검증 |
| `--xss` | XSS 검증 |
| `--crypto` | 암호화 구현 검증 |
| `--api` | API 보안 검증 |

## 예시

```bash
# 전체 검증
/security "이 로그인 코드 안전한지?"

# OWASP 기반
/security --owasp "이 API 엔드포인트 검증"

# STRIDE 위협 모델링
/security --stride "이 아키텍처 위협 분석"

# SQL Injection 검증
/security --sql "이 쿼리 SQL Injection 가능?"

# 인증 검증
/security --auth "JWT 처리 검증"
```

## 언제 사용

- ✅ 인증/인가 구현 전 보안 검토
- ✅ API 엔드포인트 보안 확인
- ✅ 취약점 점검 (Injection, XSS 등)
- ✅ 암호화 구현 검증
- ✅ 아키텍처 보안 위협 분석

## 특징

- ⭐ **읽기 전용** (절대 수정 안 함)
- ⭐ OWASP Top 10 (2021) 기반
- ⭐ STRIDE 위협 모델링
- ⭐ 구체적인 취약점 위치 지정 (파일:줄번호)
