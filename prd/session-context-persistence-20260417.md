---
type: "feature"
feature_type: "feature"
title: "세션 간 컨텍스트 유지 시스템"
created_at: "2026-04-17 14:30:00"
status: "draft"
---

# 세션 간 컨텍스트 유지 시스템

## 목표

Claude Code 세션 간에 작업 컨텍스트를 자동으로 저장하고 복구하여, 사용자가 이전 작업을 쉽게 이어갈 수 있는 시스템을 구축한다.

**핵심**: 마지막 작업의 시작점부터 전체 대화 내용을 저장하여 "왜 이렇게 짰는지" 맥락을 유지한다.

## 배경

### 현재 문제

```
사용자 시나리오:

1. 작업 시작
   > "로그인 기능 만들어줘"
   > (구현 중...)
   > auth.ts:120 수정 중
   > LoginForm.tsx 추가

2. 세션 종료 (clear 또는 터미널 종료)
   > ❌ 모든 컨텍스트 손실
   > ❌ "왜 이렇게 짰지?" 알 수 없음
   > ❌ "어떤 과정으로 결정했지?" 상실

3. 다시 시작
   > "아 뭐 하고 있었지?"
   > "어디서부터 해야하지?"
   > ❌ 맥락 상실, 시간 낭비
```

### 기존 시스템 한계

- **auto memory**: 사용자 정보/피드백/프로젝트 정보 저장 ✅
- **세션 컨텍스트**: 세션 간 작업 중단 상태 미지원 ❌

### 필요성

| 사용자 니즈 | 빈도 | 영향도 |
|------------|------|--------|
| "작업 중이었던 거 기억 안 남" | 매일 | 높음 |
| "어떤 파일 수정 중이었지?" | 자주 | 높음 |
| **"왜 이렇게 짰지?" 맥락 상실** | 항상 | **매우 높음** |
| "예전에 뭐 했는지 찾기" | 종종 | 중간 |
| "컨텍스트 전환 비용" | 항상 | 높음 |

---

## 요구사항

### 1. 저장 시점 정의 (중요)

**"마지막 작업의 시작점"** 기준

| 기준 | 설명 | 예시 |
|------|------|------|
| **마지막 커밋** | 가장 최근 git commit 이후 | 커밋 후 작업 시작 |
| **명시적 시작** | 사용자가 `/start-task` 실행 | 명확한 작업 단위 |
| **자동 감지** | 새로운 주제/파일 작업 감지 | 주제 변경 시 |

**기본 동작**: 마지막 커밋 이후부터 저장

```bash
# 예시
13:00  git commit: "feat: Add auth base"
13:05  나: "로그인 기능 만들어줘"     ← 저장 시작점 ✅
13:06  Claude: "네, auth.ts 만들게요"
13:10  나: "JWT 추가해줘"
13:15  Claude: "추가했어요"
13:20  나: "근데 에러나"
13:25  (세션 종료)

저장되는 것:
  - 13:05~13:25의 전체 대화
  - 요약
```

---

### 2. 세션 자동 저장

**트리거**: 세션 종료 시 (hook)

**저장 정보**:
```bash
~/.claude/session/current/
├── files.txt              # 수정 중인 파일 목록 (git status)
├── last-commit.txt        # 마지막 커밋 메시지
├── conversation.log       # 전체 대화 내용 ← 중요!
├── summary.md             # 요약 (자동 생성)
├── memo.md                # 사용자 수동 메모
├── timestamp              # 마지막 활동 시간
└── task-start.txt         # 작업 시작 시점
```

**conversation.log 형식**:
```markdown
# Conversation Log - Started at 13:05

## User (13:05)
로그인 기능 만들어줘

## Assistant (13:06)
네, auth.ts를 만들게요.

[File: src/auth.ts - Created]
export class Auth {
  login() { ... }
}

## User (13:10)
JWT 추가해줘

## Assistant (13:15)
추가했어요.

[File: src/auth.ts - Modified]
import jwt from 'jsonwebtoken';

## User (13:20)
근데 에러나

...
```

**구현**:
```bash
# .claude/hooks/session-end.sh
#!/bin/bash
SESSION_DIR="$HOME/.claude/session/current"
mkdir -p "$SESSION_DIR"

# 1. 작업 시작 시점 찾기 (마지막 커밋)
LAST_COMMIT_TIME=$(git log -1 --format="%ct" 2>/dev/null || echo "0")
echo "$LAST_COMMIT_TIME" > "$SESSION_DIR/task-start.txt"

# 2. 수정 중인 파일
git status --short > "$SESSION_DIR/files.txt"

# 3. 마지막 커밋
git log -1 --pretty=format:"%h %s" > "$SESSION_DIR/last-commit.txt"

# 4. 타임스탬프
date +%s > "$SESSION_DIR/timestamp"

# 5. 대화 내용 저장 (Claude Code에서 제공하는 API 사용)
# conversation.log는 Claude Code 세션에서 자동으로 저장됨

# 6. 요약 자동 생성
cat > "$SESSION_DIR/summary.md" << EOF
# 세션 요약 - $(date +%Y-%m-%d\ %H:%M)

## 작업 중
- 마지막 커밋: $(cat $SESSION_DIR/last-commit.txt)
- 수정 파일: $(wc -l < $SESSION_DIR/files.txt)개
- 대화 길이: $(wc -l < $SESSION_DIR/conversation.log)줄

## 다음 단계
EOF

# 히스토리로 이동
mv "$SESSION_DIR" "$HOME/.claude/session/history/$(date +%Y%m%d_%H%M%S).session"
```

---

### 3. 세션 시작 시 자동 복구 프롬프트

**트리거**: 세션 시작 시 (hook)

**표시 내용**:
```bash
🔍 이전 작업 발견

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📍 마지막 작업 (어제 14:25, 2시간 전)

💾 요약:
  로그인 기능 구현 중 (auth.ts:120)
  대화: 25턴

💬 대화 미리보기:
  13:05  나: "로그인 기능 만들어줘"
  13:06  Claude: "네, auth.ts 만들게요"
  13:10  나: "JWT 추가해줘"
  ... (전체는 /last-memory로)

📁 수정 중 (4개):
  M  src/auth.ts (+120, -5)
  M  src/components/LoginForm.tsx (+45, -2)
  A  src/middleware/verifyToken.ts

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💡 /last-memory로 전체 대화를 복구할 수 있습니다
```

**구현**:
```bash
# .claude/hooks/session-start.sh
#!/bin/bash
HISTORY_DIR="$HOME/.claude/session/history"

# 최근 세션 찾기
LATEST_SESSION=$(ls -t "$HISTORY_DIR"/*.session 2>/dev/null | head -1)

if [ -n "$LATEST_SESSION" ]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🔍 이전 작업 발견"
  echo ""
  head -20 "$LATEST_SESSION/summary.md"
  echo ""
  echo "💬 대화 일부:"
  head -30 "$LATEST_SESSION/conversation.log" | tail -10
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "💡 /last-memory로 전체 대화를 복구할 수 있습니다"
fi
```

---

### 4. 작업 히스토리 조회 (/history)

**명령어**:
```bash
/history                  # 최근 10개 세션
/history --week           # 최근 7일
/history --auth           # "auth" 관련 필터
/history --files          # 파일별 정리
```

**출력 예시**:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 작업 히스토리 (최근 7일)

ID  날짜        작업                    대화   파일
────────────────────────────────────────────
1   04-17 14:25  로그인 기능 구현        25턴   4개
2   04-17 10:15  DB 마이그레이션        12턴   2개
3   04-16 16:40  버그 수정 #123         8턴    1개
4   04-16 09:20  README 작성            5턴    1개
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💡 /last-memory <ID>로 전체 대화를 볼 수 있습니다
```

---

### 5. 마지막 작업 복원 (/last-memory)

**명령어**:
```bash
/last-memory              # 최근 작업 복원
/last-memory 1            # ID 1 작업 복원
```

**동작**:
```bash
#!/bin/bash
# .claude/commands/last-memory.sh

SESSION_ID="${1:-latest}"  # 기본값: 최근 작업
HISTORY_DIR="$HOME/.claude/session/history"

if [ "$SESSION_ID" = "latest" ]; then
  SESSION=$(ls -t "$HISTORY_DIR"/*.session 2>/dev/null | head -1)
else
  SESSION="$HISTORY_DIR/$(ls "$HISTORY_DIR" | grep "^$SESSION_ID" | head -1)"
fi

if [ ! -d "$SESSION" ]; then
  echo "❌ 세션을 찾을 수 없습니다"
  exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📍 작업 복원"
echo ""

# 요약 표시
cat "$SESSION/summary.md"
echo ""

# 전체 대화 표시
echo "💬 전체 대화:"
cat "$SESSION/conversation.log"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 대화가 컨텍스트에 로드되었습니다"
echo ""
echo "💡 Claude가 이 대화를 기억하고 있습니다"
echo "   이어서 작업을 계속할 수 있습니다"
```

**사용 예시**:
```bash
/last-memory
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📍 작업 복원

💾 요약:
  로그인 기능 구현 중 (auth.ts:120)
  대화: 25턴

💬 전체 대화:
  13:05  나: "로그인 기능 만들어줘"

  Claude: "네, auth.ts를 만들게요"
  [File: src/auth.ts - Created]
  export class Auth {
    login() { ... }
  }

  13:10  나: "JWT 추가해줘"

  Claude: "추가했어요"
  [File: src/auth.ts - Modified]
  import jwt from 'jsonwebtoken';

  13:20  나: "근데 에러나"
  ... (전체 25턴)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Claude: "아! JWT 추가하고 에러 났었군요"
      "에러 내용을 다시 한 번 말씀해주시겠어요?"
```

---

### 6. 작업 시작 명시 (/start-task)

**명령어**:
```bash
/start-task "로그인 기능 구현"
```

**동작**:
```bash
# 현재 시점을 "작업 시작점"으로 명시
echo "$(date +%s)" > ~/.claude/session/current/task-start.txt
echo "로그인 기능 구현" > ~/.claude/session/current/task-name.txt
```

**사용 예시**:
```bash
# 작업 시작
/start-task "로그인 기능 구현"
✅ 작업 시작점이 설정되었습니다

# 작업 중
나: "auth.ts 만들어줘"
Claude: "네"
...

# 세션 종료 시
이 시점부터 전체 대화 저장 ✅
```

---

### 7. 수동 메모 (/memo)

**명령어**:
```bash
/memo "토큰 검증 로직 완성 필요"
/memo --list              # 메모 목록
/memo --clear             # 메모 삭제
```

**저장**:
```markdown
<!-- current/memo.md -->
## 메모

- [ ] 토큰 검증 로직 완성 필요
- [ ] 리프레시 토큰 구현
- [x] 로그인 API 완료
```

---

## 아키텍처

### 파일 구조

```
~/.claude/
├── session/
│   ├── current/                 # 현재 세션 (종료 시 history로 이동)
│   │   ├── files.txt
│   │   ├── last-commit.txt
│   │   ├── conversation.log    # 전체 대화 ← 핵심!
│   │   ├── summary.md
│   │   ├── memo.md
│   │   ├── timestamp
│   │   ├── task-start.txt      # 작업 시작 시점
│   │   └── task-name.txt       # 작업 이름
│   └── history/                 # 과거 세션
│       ├── 20260417_142522.session/
│       │   ├── files.txt
│       │   ├── last-commit.txt
│       │   ├── conversation.log
│       │   ├── summary.md
│       │   └── ...
│       ├── 20260417_101543.session/
│       └── index.json           # 검색용 인덱스
├── hooks/
│   ├── session-start.sh         # 세션 시작 시 실행
│   └── session-end.sh           # 세션 종료 시 실행
└── commands/
    ├── history.sh               # /history
    ├── last-memory.sh           # /last-memory ← 핵심!
    ├── start-task.sh            # /start-task
    └── memo.sh                  # /memo
```

### 데이터 흐름

```
┌─────────────┐
│ 세션 종료   │
└──────┬──────┘
       │
       ↓
┌─────────────────────────┐
│ session-end.sh Hook     │
│ 1. 마지막 커밋 찾기      │
│ 2. 대화 내용 저장        │ ← 핵심!
│ 3. 파일 요약 생성        │
│ 4. history/로 이동       │
└─────────────────────────┘
       │
       ↓
┌─────────────────────────┐
│ 저장소                  │
│ conversation.log        │ ← 전체 대화
│ summary.md              │ ← 요약
└─────────────────────────┘
       │
       ↓
┌─────────────┐
│ 세션 시작   │
└──────┬──────┘
       │
       ↓
┌─────────────────────────┐
│ session-start.sh Hook   │
│ 1. 최근 세션 검색       │
│ 2. 미리보기 표시        │
│ 3. 복구 프롬프트        │
└─────────────────────────┘
       │
       ↓
┌─────────────┐
│ 사용자      │
│ /last-memory│
└──────┬──────┘
       │
       ↓
┌─────────────────────────┐
│ conversation.log 로드   │ ← 전체 대화 복원
│ Claude가 맥락 이해      │
└─────────────────────────┘
```

---

## 엣지 케이스

### 기술 케이스

1. **대화가 너무 긴 경우** (>1000턴)
   - 최근 500턴만 저장
   - 사용자에게 경고

2. **Git 저장소가 아닌 경우**
   - 작업 시작 시점을 첫 메시지로 설정

3. **작업 시작 시점을 찾을 수 없음**
   - 사용자에게 `/start-task` 권장

### 실패 케이스

1. **conversation.log 손실**
   - 요약만이라도 복구
   - 사용자에게 알림

2. **저장 공간 부족**
   - 오래된 세션 자동 삭제
   - 30일 이상된 세션 정리

### 보안 케이스

1. **민감 정보 포함**
   - .env 파일 내용 제외
   - API 토큰 마스킹

---

## 성공 기준

### 기능적 요구사항

| 기능 | 필수/선택 | 기준 |
|------|----------|------|
| 자동 저장 | 필수 | 세션 종료 시 100% 저장 |
| **대화 전체 저장** | **필수** | **작업 시작점부터 전체** |
| /last-memory | 필수 | 전체 대화 복원 |
| /history | 필수 | 최근 10개 표시 |
| /start-task | 선택 | 명시적 시작점 설정 |
| /memo | 선택 | 간단한 메모 저장 |

### 비기능적 요구사항

| 항목 | 기준 |
|------|------|
| 저장 속도 | <1초 |
| 복구 속도 | <3초 (대화 크기에 따라) |
| 저장 공간 | 세션당 <1MB (대화 포함) |
| 호환성 | 모든 Claude Code 세션 |

### 사용자 경험

```
성공 지표:
1. /last-memory로 5초 내에 전체 맥락 복원
2. "왜 이렇게 짰지?" 10초 내에 파악
3. 이전 결정 사유 이해 가능
```

---

## 구현 단계

### Phase 1: MVP (당장 구현)

- [ ] session-end.sh Hook 구현
- [ ] session-start.sh Hook 구현
- [ ] 저장소 구조 생성
- [ ] 기본 세션 저장/로드
- [ ] **conversation.log 저장**

**목표**: "전체 대화 저장 가능"

---

### Phase 2: 완성 (1-2일)

- [ ] /last-memory 명령어
- [ ] /history 명령어
- [ ] /start-task 명령어
- [ ] /memo 명령어
- [ ] 필터 기능

**목표**: "명령어로 작업 쉽게 복원"

---

### Phase 3: 안정화 (1주)

- [ ] 에러 처리 강화
- [ ] 대화 크기 제한
- [ ] 히스토리 자동 정리
- [ ] 사용자 피드백 반영
- [ ] 성능 최적화

**목표**: "프로덕션 레디"

---

## 구현하지 않을 것

| 아이디어 | 이유 |
|---------|------|
| AI 기반 요약 | conversation.log로 충분 |
| 벡터 DB 검색 | 과도한 엔지니어링 |
| 클라우드 동기화 | 프라이버시 우려 |
| GUI 인터페이스 | CLI 툴임 |

---

## 참고 자료

- 기존 Memory 시스템: `~/.claude/projects/*/memory/`
- Git Hook 문서
- Claude Code Hooks 문서
- Claude Code Conversation API
