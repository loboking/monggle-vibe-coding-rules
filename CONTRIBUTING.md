# Contributing to Vibe Coding Rules

Vibe Coding Rules 프로젝트에 기여해주셔서 감사합니다! 이 문서는 기여 방법을 안내합니다.

---

## 🚀 빠른 시작

### 1. 포크 및 클론

```bash
# 포크 후 클론
git clone https://github.com/YOUR_USERNAME/monggle-vibe-coding-rules.git
cd monggle-vibe-coding-rules

# 원격 저장소 추가
git remote add upstream https://github.com/loboking/monggle-vibe-coding-rules.git
```

### 2. 개발 환경 설정

```bash
# 설치 스크립트 실행
./install.sh

# 개발 브랜치 생성
git checkout -b feature/your-feature-name
```

### 3. 커밋 컨벤션

```
feat: 새로운 기능 추가
fix: 버그 수정
docs: 문서 수정
style: 코드 포맷팅 (로직 변경 없음)
refactor: 리팩토링
test: 테스트 코드 추가/수정
chore: 빌드/설정 관련 변경
```

### 4. PR 생성

```bash
# 변경 사항 푸시
git push origin feature/your-feature-name

# GitHub에서 Pull Request 생성
# PR 제목: [feat] 기능 설명
# PR 내용에 관련 PRD 링크 포함
```

---

## 📋 기여 유형

### 버그 신고

Issue 템플릿을 사용해주세요:

1. **버그 제목**: 명확한 요약
2. **재현 단계**: 단계별 설명
3. **기대 동작**: 무엇이 일어나야 하는지
4. **실제 동작**: 무엇이 일어났는지
5. **환경**: OS, Python 버전 등

### 기능 제안

1. **기능 제목**: 간결한 설명
2. **동기**: 왜 이 기능이 필요한지
3. **제안 동작**: 어떻게 작동해야 하는지
4. **대안**: 고려한 다른 방법

### 문서 개선

- 오타/문법 오류 수정
- 명확하지 않은 설명 개선
- 예시 코드 추가
- 번역 (다국어 지원)

---

## 🎯 PRD 기반 개발 프로세스

이 프로젝트는 **PRD(Product Requirements Document) 기반 개발**을 따릅니다.

### Step 1: PRD 작성

```bash
# 대화형 PRD 생성
./.claude/commands/init.sh feature

# 또는 템플릿 복사
cp prd/feature.md prd/feature-your-feature.md
```

### Step 2: PRD 채우기

필수 섹션:
- **Title**: 기능 제목
- **Problem**: 해결할 문제
- **Requirements**: 기능/비기능 요구사항
- **Edge Cases**: 예외 상황
- **Testing**: 테스트 계획

### Step 3: 파이프라인 실행

```bash
# 전체 파이프라인
./.claude/commands/pipeline.sh prd/feature-your-feature.md

# 또는 긴급 수정
./.claude/commands/quick.sh prd/hotfix-urgent.md
```

### Step 4: PR 생성

PR 제목 형식:
```
[feat] 이메일 로그인 기능 추가
[fix] 로그인 버튼 크래시 수정
[refactor] UserService 리팩토링
[docs] README 한국어 번역
```

PR 내용에 포함:
- 관련 PRD 링크
- 구현 내용 요약
- 테스트 결과
- 스크린샷 (UI 변경의 경우)

---

## ✅ 코드 리뷰 기준

### 통합 기준

- [ ] PRD와 구현이 일치
- [ ] 테스트 커버리지 80% 이상
- [ ] 기존 테스트 통과
- [ ] 코드 스타일 일관성
- [ ] 문서 업데이트 완료

### 보안 체크

- [ ] 하드코딩된 시크릿 없음
- [ ] SQL 인jection 방지
- [ ] 입력 검증 완료
- [ ] 인증/인가 적절

---

## 🧪 테스트

```bash
# 전체 테스트 실행
python3 -m unittest discover tests/

# 특정 테스트
python3 -m unittest tests.test_agents -v

# 커버리지 확인
python3 -m coverage run -m unittest discover tests/
python3 -m coverage report
```

---

## 📁 프로젝트 구조

```
monggle-vibe-coding-rules/
├── .claude/
│   ├── commands/          # 슬래시 명령어
│   ├── hooks/             # 자동화 훅
│   └── config/            # 설정 파일
├── agents/                # 에이전트 구현
├── prd/                   # PRD 템플릿
├── scripts/               # 유틸리티 스크립트
├── rules/                 # 코어 규칙
├── tests/                 # 테스트 코드
├── docs/                  # 문서
├── CLAUDE.md              # Claude Code 규칙
├── README.md              # 프로젝트 설명
└── install.sh             # 설치 스크립트
```

---

## 🤝 협업 모드

### Solo 모드

- 빠른 반복 가능
- PRD 선택적
- 실험 장려

### Team 모드

- PRD 필수
- 품질 보장
- 코드 리뷰 필수

```bash
# 모드 변경
/.claude/commands/mode.sh solo
/.claude/commands/mode.sh team
```

---

## 🎨 스타일 가이드

### Shell Script

- 4칸 들여쓰기
- 함수는 snake_case
- 변수는 UPPER_SNAKE_CASE
- 에러 처리: `set -euo pipefail`

### Python

- PEP 8 준수
- 타입 힌트 사용
- Docstring 포함

### Markdown

- 문장 끝에 마침표
- 헤딩은 ##부터 사용
- 코드 블록에 언어 명시

---

## 🚨 릴리스 프로세스

1. **버전 업**: `./.claude/commands/bump.sh patch|minor|major`
2. **CHANGELOG 업데이트**: `./.claude/commands/changelog.sh`
3. **Git 태그 생성**
4. **GitHub 릴리스 게시**
5. **공지사항 작성**

---

## ❓ 질문 있나요?

- **GitHub Issues**: 버그 신고, 기능 제안
- **Discussions**: 아이디어, 질문
- **Email**: loboking@gmail.com

---

## 📜 라이선스

기여한 코드는 MIT 라이선스로 배포됩니다.

---

## ⭐ 기여자 분들께 감사합니다!

모든 기여는 환영입니다! 작은 오타 수정도 큰 도움이 됩니다.

**함께 만들어가요! 🚀**
