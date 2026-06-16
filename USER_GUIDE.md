# Vibe Coding Rules v3.0.0 사용 가이드

> **빠르게 시작하는 5분 가이드**

---

## 📦 설치

```bash
git clone https://github.com/loboking/monggle-vibe-coding-rules.git
cd monggle-vibe-coding-rules
./install.sh
```

또는 원라인:
```bash
curl -fsSL https://raw.githubusercontent.com/loboking/monggle-vibe-coding-rules/main/install.sh | bash
```

---

## 🚀 5분 핵심 가이드

### 기억할 것 (11개)

```
/monggle        # 1. 명령어 목록
/debug          # 2. 버그 찾기
/test           # 3. 작동 확인
/review         # 4. 코드 검토
/msg            # 5. 대화모드
/init           # 6. 초기 설정
/prd            # 7. 기획서
/pipeline       # 8. 자동 구현
/stats          # 9. 통계
/mode           # 10. 모드 변경
/brain          # 11. 기억 관리 (자동)
```

---

## 🔄 통합 명령어 (핵심)

### `/debug` - 디버깅

```bash
/debug              # 일반 디버깅
/debug --web        # 프론트엔드 (JS, React)
/debug --css        # CSS 스타일
/debug --perf       # 성능 병목
/debug --mem        # 메모리 누수
```

### `/test` - QA 테스트

```bash
/test               # 전체 QA (수정 포함)
/test --report      # 보고서만 (수정 없음)
/test --quick       # 빠른 테스트 (30초)
```

### `/review` - 리뷰

```bash
/review             # PR diff 리뷰
/review --code      # 코드 품질 (SOLID, 보안)
/review --arch      # 아키텍처 리뷰
```

### `/msg` - 대화모드

```bash
/msg                # 대화모드 시작
# 내부 명령어: /help, /exit, /brain, /save
```

---

## 🧠 뇌 시스템 (자동)

**세션 시작/종료 시 자동으로 작동합니다:**

| 시점 | 자동 동작 |
|------|----------|
| 세션 시작 | 관련 기억 로드 |
| 스킬 실행 | 관련 태그 검색 |
| 세션 종료 | 중요 결정 저장 |

**수동 사용 (선택):**

```bash
/brain                    # 뇌 통계
/brain query bug          # 버그 관련 검색
/brain recall abc123      # 특정 기억 로드
/brain cleanup            # 오래된 기억 청소
```

---

## 🤖 Monggle 명령어

```bash
/monggle            # 목록 표시

별칭으로도 호출:
/super              # 슈퍼 프롬프트 생성
/duo                # Claude + Gemini 협업
/run                # 스마트 오케스트레이터
/gemini             # Gemini AI 호출
/tech-doc-writer         # 문서 자동 생성
/project-init       # 프로젝트 초기화
/smart-brain        # 토큰 최적화
/product-manager            # 기획서 작성
```

---

## 📋 워크플로우 예시

### 새 기능 개발

```bash
# 1. 초기 설정 (최초 1회)
/init

# 2. 기획서 작성
/prd feature
# → 대화형으로 작성

# 3. 구현
/pipeline prd/feature-xxx.md
# → 자동으로 코드 생성

# 4. 테스트
/test --quick

# 5. 리뷰
/review --code
```

### 버그 수정

```bash
# 1. 디버깅
/debug --web    # 프론트엔드 버그

# 2. 테스트
/test

# 3. 완료되면 뇌가 자동 저장
```

### 대화형 작업

```bash
/msg
# → 자유롭게 대화하며 작업
# → /exit로 종료 시 자동 저장
```

---

## 🔧 모드 변경

```bash
/mode solo          # 자유 모드 (PRD 없이 작업)
/mode team          # 팀 모드 (PRD 필수)
```

---

## 💡 팁

### 오타 교정 (자동)

```bash
/debugg             # → /debug 로 자동 교정
/qaa                # → /qa
/log                # → /changelog
```

### 탭 자동완성

```bash
/stats --[Tab]      # 옵션 표시
/qa --[Tab]         # --report, --quick
```

---

## 📚 더 알아보기

- **전체 명령어**: README.md 참조
- **뇌 시스템**: `.claude/brain/SPEC.md`
- **업데이트**: `/monggle-upgrade` 또는 git pull

---

## ❓ 자주 묻는 질문

**Q: 몇 개를 기억하면 되나요?**
A: 11개만 기억하면 됩니다. 나머지는 자동 완성이나 오타 교정으로.

**Q: /brain은 언제 사용하나요?**
A: 보통 자동으로 작동합니다. 특정 기억을 검색할 때만 수동으로.

**Q: 통합 명령어와 개별 명령어 차이는?**
A: 통합(`/debug`) = 옵션으로 분기, 개별(`/debug-master`) = 직접 호출. 둘 다 작동합니다.

---

**Vibe Coding Rules v3.0.0**
