# 세션 간 컨텍스트 유지 시스템

> **Phase 1 MVP** - 2026-04-17 구현 완료

## 개요

Claude Code 세션 간에 작업 컨텍스트를 자동으로 저장하고 복구하여, 이전 작업을 쉽게 이어갈 수 있는 시스템입니다.

### 핵심 기능

- **자동 저장**: 세션 종료 시 작업 상태 자동 저장
- **전체 대화 보존**: conversation.log에 전체 대화 내용 저장
- **빠른 복원**: `/last-memory`로 전체 대화 복원
- **스마트 프롬프트**: 세션 시작 시 이전 작업 미리보기

## 파일 구조

```
~/.claude/
├── session/
│   ├── current/                 # 현재 세션 (종료 시 history로 이동)
│   │   ├── files.txt            # 수정 중인 파일 목록
│   │   ├── last-commit.txt      # 마지막 커밋
│   │   ├── conversation.log     # 전체 대화 내용 ← 핵심!
│   │   ├── summary.md           # 요약
│   │   ├── memo.md              # 사용자 메모
│   │   ├── timestamp            # 마지막 활동 시간
│   │   ├── task-start.txt       # 작업 시작 시점
│   │   └── last-active.txt      # 마지막 활동 시간 (읽기용)
│   └── history/                 # 과거 세션
│       ├── 20260417_134747.session/
│       │   ├── files.txt
│       │   ├── last-commit.txt
│       │   ├── conversation.log
│       │   ├── summary.md
│       │   └── ...
│       └── ...
├── hooks/
│   ├── session-start.sh         # 세션 시작 시 실행
│   └── session-end.sh           # 세션 종료 시 실행
└── commands/
    └── last-memory.sh           # /last-memory 명령어
```

## 사용법

### 1. 자동 저장 (세션 종료 시)

세션 종료 시 자동으로 `~/.claude/session/history/`로 저장됩니다.

**저장되는 정보:**
- 수정 중인 파일 목록 (`git status --short`)
- 마지막 커밋 정보
- 전체 대화 내용 (`conversation.log`)
- 작업 요약 (`summary.md`)

### 2. 이전 작업 미리보기 (세션 시작 시)

새 세션 시작 시 자동으로 이전 작업이 표시됩니다.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔍 이전 작업 발견

📍 마지막 작업 (2026-04-17 13:47, 방금 전)

💾 요약:
   커밋: ed4fe09 docs:
   파일: 2개 수정 중
   대화: 10줄

📁 수정 중인 파일 (2개):
   ?? prd/session-context-persistence.md
   M  src/auth.ts

💬 대화 미리보기 (마지막 5줄):
   ## User
   JWT 추가해줘

   ## Assistant
   JWT 기능을 추가하겠습니다

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💡 /last-memory로 전체 대화를 복구할 수 있습니다
```

### 3. 전체 대화 복원

```bash
# 최근 작업 복원
/last-memory

# 특정 세션 복원
/last-memory 20260417_134747
```

**출력 예시:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📍 작업 복원

# 세션 요약 - 2026-04-17 13:47:47

## 작업 개요
- 마지막 커밋: ed4fe09 docs:
- 수정 파일: 2개
- 대화 길이: 10줄

## 작업 내용

### 마지막 대화 미리보기
## User (14:30)
로그인 기능 만들어줘

## Assistant (14:31)
네, 로그인 기능을 구현하겠습니다

...

💬 전체 대화:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Conversation Log - Started at 2026-04-17 14:30

## User (14:30)
로그인 기능 만들어줘

## Assistant (14:31)
네, 로그인 기능을 구현하겠습니다
...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ 대화가 컨텍스트에 로드되었습니다

💡 Claude가 이 대화를 기억하고 있습니다
   이어서 작업을 계속할 수 있습니다
```

## conversation.log 형식

`conversation.log`는 전체 대화 내용을 저장하는 핵심 파일입니다.

```markdown
# Conversation Log - Started at 2026-04-17 14:30

## User (14:30)
로그인 기능 만들어줘

## Assistant (14:31)
네, 로그인 기능을 구현하겠습니다.

[File: src/auth.ts - Created]
export class Auth {
  login() { ... }
}

## User (14:35)
JWT 추가해줘

## Assistant (14:36)
JWT 기능을 추가하겠습니다.

[File: src/auth.ts - Modified]
import jwt from 'jsonwebtoken';

...
```

**중요:** conversation.log는 Claude Code 세션에서 자동으로 저장됩니다. (현재 구현에서는 수동으로 생성 필요)

## Hook 동작

### session-start.sh

세션 시작 시 실행됩니다.

1. 최근 세션 검색 (`history/`에서 가장 최근 `.session`)
2. 미리보기 표시 (요약, 파일 목록, 대화 미리보기)
3. `/last-memory` 프롬프트

### session-end.sh

세션 종료 시 실행됩니다.

1. 마지막 커밋 찾기
2. 수정 중인 파일 목록 저장 (`git status --short`)
3. conversation.log 저장 (이미 생성되어 있다고 가정)
4. 요약 생성 (`summary.md`)
5. `current/` → `history/TIMESTAMP.session/`로 이동

## 구현 현황 (Phase 1 MVP)

### 완료된 기능

- [x] 저장소 구조 생성 (`current/`, `history/`)
- [x] session-end.sh Hook 구현
- [x] session-start.sh Hook 구현
- [x] 기본 세션 저장/로드
- [x] conversation.log 저장 지원
- [x] /last-memory 명령어
- [x] 세션 요약 자동 생성
- [x] macOS 호환성 확보

### 제한사항

- conversation.log 자동 생성: Claude Code에서 제공하는 API 필요
- 히스토리 필터링: Phase 2에서 구현 예정
- /start-task, /memo: Phase 2에서 구현 예정

## 사용 예시

### 시나리오 1: 작업 중단 후 복귀

```bash
# 1. 작업 시작
> "로그인 기능 만들어줘"
> (구현 중...)
> auth.ts:120 수정 중
> LoginForm.tsx 추가

# 2. 세션 종료 (터미널 종료 또는 /clear)
# ✅ 자동으로 저장됨

# 3. 다음 날, 새 세션 시작
# 🔍 이전 작업 발견 메시지 자동 표시

# 4. 전체 대화 복원
> /last-memory
# ✅ 전체 대화가 컨텍스트에 로드됨

# 5. 작업 계속
> "어디까지 했지?"
Claude: "auth.ts의 JWT 기능을 추가하고 에러를 해결하던 중이었어요"
```

### 시나리오 2: 특정 세션 복원

```bash
# 여러 세션이 있는 경우
> /last-memory
# 최근 세션 복원

> /last-memory 20260417_134747
# 특정 세션 복원
```

## 기술적 세부사항

### 파일 네이밍

```
세션 ID: YYYYMMDD_HHMMSS.session
예시: 20260417_134747.session
```

### 시간 계산

```bash
# 현재 시간 - 마지막 활동 시간
TIME_DIFF = CURRENT_TS - LAST_ACTIVE_TS

# 1시간 이내: "N분 전"
# 24시간 이내: "N시간 전"
# 그 이상: "N일 전"
```

### 호환성

- **macOS**: BSD 호환 (ls, grep, wc)
- **Linux**: GNU 호환
- **Shell**: bash 3.0+

## 다음 단계 (Phase 2)

- [ ] /history 명령어 (히스토리 목록)
- [ ] /start-task 명령어 (명시적 작업 시작)
- [ ] /memo 명령어 (수동 메모)
- [ ] 히스토리 필터링
- [ ] conversation.log 자동 생성 (Claude Code API)
- [ ] 오래된 세션 자동 정리 (30일 이상)

## 문제 해결

### Q: session-start가 실행되지 않아요

A: Hook이 Claude Code 설정에 등록되어 있는지 확인하세요.

### Q: conversation.log가 없어요

A: 현재는 Claude Code에서 자동으로 생성되지 않습니다. Phase 2에서 API를 통한 자동 생성을 구현할 예정입니다.

### Q: 한글이 깨져서 나와요

A: 터미널 인코딩을 UTF-8로 설정하세요:
```bash
export LANG=ko_KR.UTF-8
```

## 라이선스

MIT License - Monggle Vibe Coding Rules 프로젝트의 일부
