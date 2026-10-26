# Monggle Agent Kit — 작업 규칙

> 이 파일이 규칙의 유일한 원본이다. CLAUDE.md·GEMINI.md 는 이 파일을 가리키기만 한다.
> 적용 대상: Claude Code, Codex CLI, OpenCode, Gemini CLI
> **Mode**: MANUAL | SEMI-AUTO | AUTO

PRD는 선택 사항이지만 복잡한 작업에는 권장됩니다.

---

## 💾 토큰 절약 규칙

### 출력 최적화
- **diff-only**: 변경 부분만 출력 (전체 파일 재출력 금지)
- **참조 우선**: 코드 재출력 대신 `파일명:라인번호` 형식 사용
- **중복 축약**: 반복 패턴은 "... (N more similar)" 형태로 축약

### 코드 우선주의
- 긴 설명 대신 **실행 가능한 코드** 우선
- 주석은 복잡한 로직에만 최소화
- 문서는 README/docs에 분리 (코드 파일 내 X)

### 재작업 방지
한번에 정확한 구현으로 수정 왕복 최소화:
- [ ] 보안 체크 (injection, hardcoded secrets)
- [ ] 에러 처리 (edge cases, null safety)
- [ ] 성능 검토 (N+1 쿼리, 무한 루프)
- [ ] 타입 안전성 (TypeScript strict, Python type hints)

### 금지 패턴
- ❌ 요청 없는 기능 추가/삭제
- ❌ 과도한 console.log/print (디버깅 후 제거)
- ❌ 미사용 import/변수 (린터 경고 방치)

---

## 🤖 스킬 (사용자는 이름을 몰라도 된다)

사용자는 "고쳐줘", "작동해?", "올려줘"처럼 말한다. **의도를 보고 아래 입구 스킬을 고른다.** 확인하지 말고 바로 쓰되, 시작할 때 한 줄로 알린다: `의도: <의도> → <스킬>`.
세부 절차는 각 스킬의 `references/` 에 있고, 고른 뒤 필요한 것만 읽는다.

| 의도 | 스킬 | 안에 든 절차 |
|---|---|---|
| 버그·오류·느림·메모리·리팩토링·"수정하면 어디 영향?" | `fix` | 영향 범위 → 증상별 절차(debug·bottleneck·mem-check·profile·refactor) → 최소 수정 → 관련 테스트 실행 |
| 작동 확인·테스트·점검·보안·린트·"보고서만" | `qa` | 프로젝트 자동 판별, 테스트·보안·린트·포맷 |
| 새 기능·위험한 변경 전 기획·PRD·스펙·아이디어 | `spec` | 가벼운 스펙(목표·완료 조건·안 할 것·영향 파일), 필요 시 계획·작업 분해 |
| 커밋·푸시·PR | `push-safe` | 커밋 메시지 승인 → rebase → 비밀값 검사 → push → (팀 모드) PR |
| "이 답 맞아?"·검증 | `answer-check` | 읽기 전용 검증 (구 `verify`) |
| 설계·구현·리뷰가 다 필요한 큰 일, 팀원 채용 | `team` | AI 팀(페르소나 서브에이전트), 팀장 도현이 분배 |
| 혼자/여럿이 개발 전환 | `mode` | solo/team |
| 기억 저장·회상 | `brain` | 훅이 자동으로 돈다. 훅이 없는 도구에서만 직접 |

- 작은 일에 `team`·`spec` 을 쓰지 않는다(비용·마찰).
- 보관된 옛 스킬은 `archive/skills/` 에 있다. 사용자가 옛 이름(예: `/impact`, `/debug`)을 말하면 위 표의 입구 스킬로 처리한다.


## TDD Testing (Option 3: Combined)

통합 TDD 접근법으로 Python unittest와 bats-core를 병행 사용합니다.

### 테스트 구조

```
tests/
├── test_lib_sh.py            # Python: Bash 라이브러리
├── bash/
│   ├── skills.bats           # bin/ 스크립트·라이브러리·보안 패턴
│   ├── push-safe.bats        # 임시 원격으로 push·rebase·충돌·비밀값
│   └── brain_harness.bats    # brain MCP·훅, 하네스, 설치본, 스킬 구조
└── run_tests.sh              # 통합 실행기 (--python, --bats, --verbose)
```

테스트는 임시 HOME 에서 돈다. 실제 도구 설정(`CODEX_HOME` 등)을 쓰는 코드는 테스트에서 그 변수를 비운다.

---

## Mode

- `solo`(기본): 스펙은 선택.
- `team`: 사람 여러 명이 같은 저장소에서 개발. push-safe 가 main 이 아닌 브랜치에서 PR 을 만든다.
  위험한 변경(여러 파일·API·DB·인증·새 기능)에는 `spec` 을 먼저 쓴다. 재설계 중: `prd/feature-20261026-team-mode-redesign.md`
- 확인·전환: `/mode`, `/mode solo`, `/mode team`

---


## Free Chat Rules

자유로운 대화를 위해 다음 작업은 PRD 없이 진행 가능:

- 설명 요청
- 코드 리뷰
- 문서화
- 간단한 수정

위험한 변경(여러 파일·API·DB·인증·새 기능)은 `spec` 을 먼저 쓴다.

---

## Configuration Files

| File | Description |
|------|-------------|
| `AGENTS.md` | 이 파일(규칙 원본) |
| `bin/` | 셸 스크립트(도구 공용) |
| `skills/` | 스킬 원본 |
| `.claude/hooks/` | PRD 검증 훅 |
| `.claude/config/` | 모드별 설정 |
| `prd/templates/` | PRD 템플릿 |
| `logs/` | 파이프라인 로그 |

---

## 최근 변경 내역

변경 이력은 `CHANGELOG.md`에 있다. 이 파일은 매 세션 컨텍스트에 통째로 올라가므로, 날짜별 파일 목록 같은 건 넣지 않는다.
