#!/bin/bash
#
# security.sh - 보안성 검증 전용 스킬 (읽기 전용)
#
# AI 기반 보안 검증: OWASP Top 10, STRIDE, 코드 취약점 분석
# 수정 권한 없이 검토만 수행
#
# Usage:
#   /security "코드 또는 설계"       # 전체 보안 검증
#   /security --owasp "내용"        # OWASP Top 10 기반
#   /security --stride "내용"       # STRIDE 위협 모델링
#   /security --auth "인증 코드"    # 인증/보안 검증
#   /security --sql "쿼리"          # SQL Injection 검증
#

cat << 'SECURITY_EOF'
---
allowed-tools: Read, Grep, Glob, Bash, WebFetch, WebSearch, LSP
description: 보안성 검증 - OWASP Top 10, STRIDE, 취약점 분석 (읽기 전용)
---

Args: "$ARGUMENTS"

## ⚠️ 중요: 읽기 전용 모드

이 스킬은 **보안 검증만 수행**하며, **절대 코드를 수정하지 않습니다**.
- ✅ Read, Grep, Glob, Bash (읽기), LSP (분석)
- ❌ Edit, Write (수정 금지)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔒 /security 사용 가이드

용도: AI 기반 보안 검증 (OWASP Top 10, STRIDE, 취약점 분석)

사용법:
  /security "코드 또는 설계"       # 전체 보안 검증
  /security --owasp "내용"        # OWASP Top 10 기반 검증
  /security --stride "아키텍처"   # STRIDE 위협 모델링
  /security --auth "인증 코드"    # 인증/인가 검증
  /security --sql "쿼리"          # SQL Injection 검증
  /security --xss "입력"          # XSS 검증
  /security --crypto "암호화"     # 암호화 구현 검증

검증 카테고리:
  owasp       OWASP Top 10 (2021)
  stride      STRIDE 위협 모델링
  auth        인증/인가 (Authentication/Authorization)
  injection   Injection (SQL, NoSQL, OS Command, LDAP)
  xss         XSS (Cross-Site Scripting)
  crypto      암호화/해시/키 관리
  data        데이터 보안 (민감 정보, PII)
  api         API 보안

옵션:
  --owasp     OWASP Top 10 기반 검증
  --stride    STRIDE 위협 모델링
  --auth      인증/인가 검증
  --sql       SQL Injection 검증
  --xss       XSS 검증
  --crypto    암호화 구현 검증
  --api       API 보안 검증
  --help      이 도움말

예시:
  /security "이 로그인 코드 안전한지?"
  /security --owasp "이 API 엔드포인트 검증"
  /security --stride "이 아키텍처 위협 분석"
  /security --sql "이 쿼리 SQL Injection 가능?"
  /security --auth "JWT 처리 검증"

언제 사용:
  ✅ 인증/인가 구현 전 보안 검토
  ✅ API 엔드포인트 보안 확인
  ✅ 취약점 점검 (Injection, XSS 등)
  ✅ 암호화 구현 검증
  ✅ 아키텍처 보안 위협 분석

특징:
  ⭐ 읽기 전용 (절대 수정 안 함)
  ⭐ OWASP Top 10 (2021) 기반
  ⭐ STRIDE 위협 모델링
  ⭐ 구체적인 취약점 위치 지정
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 1. Parse Options

### 검증 유형 (기본: 전체)
- `--owasp` - OWASP Top 10 기반
- `--stride` - STRIDE 위협 모델링
- `--auth` - 인증/인가
- `--sql` - SQL Injection
- `--xss` - XSS
- `--crypto` - 암호화/해시
- `--api` - API 보안
- (없음) - 전체 검증

## 2. OWASP Top 10 (2021) 기반 검증

### A01:2021 – Broken Access Control
- IDOR (Insecure Direct Object Reference)
- 권한 우회 가능성
- 세션 관리

### A02:2021 – Cryptographic Failures
- 하드코딩된 키/비밀번호
- 약한 암호화 알고리즘
- HTTPS 미사용

### A03:2021 – Injection
- SQL Injection
- NoSQL Injection
- OS Command Injection
- LDAP Injection

### A04:2021 – Insecure Design
- 안전하지 않은 설계 패턴
- 에지 케이스 누락

### A05:2021 – Security Misconfiguration
- 디폴트 자격증명
- 불필요한 기능 활성화
- 에러 메시지 정보 노출

### A06:2021 – Vulnerable and Outdated Components
- 오래된 라이브러리
- 알려진 취약점

### A07:2021 – Identification and Authentication Failures
- 약한 비밀번호 정책
- 세션 고정
- 자격증명 노출

### A08:2021 – Software and Data Integrity Failures
- 무결성 검증 없는 업데이트
- CI/CD 파이프라인

### A09:2021 – Security Logging and Monitoring Failures
- 로깅 부족
- 침입 탐지 미흡

### A10:2021 – Server-Side Request Forgery (SSRF)
- SSRF 취약점

## 3. STRIDE 위협 모델링

| 위협 | 설명 | 검증 항목 |
|------|------|-----------|
| **S**poofing | 위조 | 인증, ID 확인 |
| **T**ampering | 변조 | 데이터 무결성 |
| **R**epudiation | 부인 | 로깅, 감사 추적 |
| **I**nformation Disclosure | 정보 노출 | 민감 데이터 보호 |
| **D**enial of Service | 서비스 거부 | 리소스 제한 |
| **E**levation of Privilege | 권한 상승 | 권한 검사 |

## 4. Output Format

```markdown
🔒 Security Verification Report

## 검증 대상
[요약]

## 1️⃣ OWASP Top 10 (2021) 기반 검증

| 항목 | 위험도 | 결과 | 설명 |
|------|--------|------|------|
| A01 Access Control | [🔴🟠🟡⚪] | [...] | [...] |
| A02 Cryptographic | [🔴🟠🟡⚪] | [...] | [...] |
| A03 Injection | [🔴🟠🟡⚪] | [...] | [...] |
| A04 Insecure Design | [🔴🟠🟡⚪] | [...] | [...] |
| A05 Misconfig | [🔴🟠🟡⚪] | [...] | [...] |
| A06 Outdated Components | [🔴🟠🟡⚪] | [...] | [...] |
| A07 Auth Failures | [🔴🟠🟡⚪] | [...] | [...] |
| A08 Integrity Failures | [🔴🟠🟡⚪] | [...] | [...] |
| A09 Logging Failures | [🔴🟠🟡⚪] | [...] | [...] |
| A10 SSRF | [🔴🟠🟡⚪] | [...] | [...] |

[위험도]
🔴 Critical - 즉시 수정 필요
🟠 High - 우선 수정 권장
🟡 Medium - 조만간 수정
⚪ Low - 권장 사항

## 2️⃣ 발견된 취약점

### 🔴 Critical
- [취약점]
  - 위치: 파일:줄번호
  - 설명: [...]
  - 영향: [...]

### 🟠 High
- [...]

## 3️⃣ STRIDE 위협 분석 (--stride 옵션 시)

| 위협 | 위험도 | 완화 방안 |
|------|--------|----------|
| Spoofing | [🔴🟠🟡⚪] | [...] |
| Tampering | [🔴🟠🟡⚪] | [...] |
| Repudiation | [🔴🟠🟡⚪] | [...] |
| Info Disclosure | [🔴🟠🟡⚪] | [...] |
| DoS | [🔴🟠🟡⚪] | [...] |
| Elevation | [🔴🟠🟡⚪] | [...] |

## 4️⃣ 종합 보안 등급
[A/B/C/D/F]

## 5️⃣ 권장사항 (우선순위별)
1. [즉시 수정] [...]
2. [우선 수정] [...]
3. [조만간] [...]

⚠️ **참고**: 이 검토는 읽기 전용입니다. 실제 적용 전에 전문가 검토가 권장됩니다.
```

## 5. Rules

### 필수 규칙
1. **읽기 전용 강제** (Edit, Write 금지)
2. **OWASP Top 10 (2021) 기반**
3. **구체적인 취약점 위치** (파일:줄번호)
4. **위험도 등급** (Critical/High/Medium/Low)

### 금지 사항
- ❌ 코드 수정 (Edit, Write 사용 금지)
- ❌ 막연한 경고 ("보안에 주의하세요" X)
- ❌ 근거 없는 취약점 지적

---

## Final Metadata Output

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 실행 정보

스킬: /security
모드: 읽기 전용 (보안 검증 전용)
프레임워크: [OWASP Top 10 / STRIDE]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SECURITY_EOF
