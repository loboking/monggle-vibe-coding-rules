---
name: answer-check
description: AI(자기 자신 포함)가 준 답변·코드·주장이 맞는지 확인할 때 쓴다. 정확성·안전성·완결성·실행 가능성을 읽기 전용으로 검증하고 문제를 파일:라인으로 짚는다. 코드는 고치지 않는다. "이거 맞아?", "검증해줘", "AI 답변 확인", "사실이야?" 등. (구 이름 verify)
allowed-tools: Bash, Read, Grep, Glob, Edit, Write
---

# answer-check

AI 응답 검증

---
allowed-tools: Read, Grep, Glob, Bash, WebFetch, WebSearch, LSP
description: AI 응답 검증 - 정확성/안전성/완결성 (읽기 전용, 수정 없음)
---

# /answer-check - AI 응답 검증 스킬

AI가 준 답변의 정확성, 안전성, 완결성을 검증합니다. **읽기 전용**으로 절대 코드를 수정하지 않습니다.

## 사용법

```bash
/answer-check "AI가 준 답변"         # 전체 검증
/answer-check --code "코드+설명"    # 구현 검증
/answer-check --safety "내용"       # 보안 검증
/answer-check --logic "주장"        # 논리 검증
/answer-check --duo "내용"          # 다중 AI 교차 검증
```

## 검증 카테고리

| 카테고리 | 항목 |
|----------|------|
| **정확성** | 사실 확인, 논리 오류, 모순 |
| **안전성** | 보안 취약점, 위험 코드 |
| **완결성** | 누락, 에지 케이스, 에러 핸들링 |
| **실행성** | 실제 동작 여부, 의존성 |

## 옵션

| 옵션 | 설명 |
|------|------|
| `--code` | 코드 구현 검증 |
| `--safety` | 보안만 집중 검증 |
| `--logic` | 논리/주장 검증 |
| `--duo` | Claude + Gemini 교차 검증 |

## 예시

```bash
# 전체 검증
/answer-check "이 코드로 로그인 기능 구현하라고 했어"

# 코드 검증
/answer-check --code "AI가 작성한 인증 코드 검증"

# 보안 검증
/answer-check --safety "이 SQL 쿼리 안전한지?"

# 교차 검증
/answer-check --duo "이 답변이 정확한지 검증"
```

## 언제 사용

- ✅ AI 답변을 받은 후 검증
- ✅ 구현 코드가 맞는지 확인
- ✅ 보안 취약점 확인
- ✅ 논리적 모순 확인

## 특징

- ⭐ **읽기 전용** (절대 수정 안 함)
- ⭐ 4가지 검증 카테고리
- ⭐ 교차 검증 (--duo)
- ⭐ 구체적인 문제 지적 (줄번호, 파일명)

## 실행

절차는 셸 스크립트에 있다. 저장소 안에 있으면 그걸, 없으면 설치된 것을 쓴다.

```bash
SCRIPT=bin/answer-check.sh
[ -f "$SCRIPT" ] || SCRIPT="$HOME/.monggle/bin/answer-check.sh"
bash "$SCRIPT"   # 사용자가 준 인자를 그대로 덧붙인다
```

출력을 읽고 결과를 사용자에게 정리해 보고한다. 스크립트가 없으면 그 사실을 알리고 멈춘다.
