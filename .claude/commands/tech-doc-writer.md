---
allowed-tools: Read, Grep, Glob, Bash, Edit, Write, LSP, WebFetch, WebSearch
description: 기술 문서 작성 - README, API 문서, 가이드, 아키텍처 문서
model: sonnet
---

Args: "$ARGUMENTS"

## 0. Help System

If args match `--help`, `-h` alone, or empty:

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📝 /tech-doc-writer 사용 가이드

용도: 명확하고 포괄적인 기술 문서 작성

사용법:
  /tech-doc-writer <문서 타입>         # 문서 생성
  /tech-doc-writer readme              # README 생성
  /tech-doc-writer api                 # API 문서
  /tech-doc-writer --update <파일>     # 기존 문서 업데이트

  /tech-doc-writer -h <요청>           # haiku (빠른 작성)
  /tech-doc-writer -s <요청>           # sonnet (기본값)
  /tech-doc-writer -o <요청>           # opus (상세 문서)

문서 유형:
  readme        프로젝트 README
  api           API 문서 (OpenAPI/Swagger)
  guide         사용자 가이드
  architecture  아키텍처 문서
  deployment    배포 가이드
  troubleshoot  트러블슈팅 가이드
  changelog     변경 이력
  contributing  기여 가이드
  spec          기술 스펙
  all           위 모든 문서

옵션:
  --update         기존 문서 업데이트
  --template <id>  특정 템플릿 사용
  --lang           언어 선택 (ko/en/auto)
  --format         출력 형식 (md/html/pdf)

예시:
  /tech-doc-writer readme
  /tech-doc-writer api "인증 엔드포인트"
  /tech-doc-writer --update docs/architecture.md
  /tech-doc-writer -o guide "설치 가이드"

언제 사용:
  ✅ 새 프로젝트 문서화
  ✅ API 문서 생성
  ✅ 코드 변경 후 문서 업데이트
  ✅ 배포/설정 가이드 작성
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 1. Parse Options

- Model: `-h` (haiku) | `-s` (sonnet) | `-o` (opus) | default: sonnet
- Doc Type: readme | api | guide | architecture | deployment | troubleshoot | changelog | contributing | spec | all
- Options: `--update` | `--template <id>` | `--lang <ko|en|auto>` | `--format`

## 1.5. Project Analysis

분석 전에 프로젝트 구조를 파악합니다.

Use Glob/Grep/LSP to detect:
- **Project type**: package.json (Node), requirements.txt (Python), go.mod (Go), pom.xml (Java) 등
- **Framework**: React, Next.js, Flask, Spring Boot 등
- **API style**: REST, GraphQL, gRPC
- **Existing docs**: README.md, docs/ 폴더 존재 여부
- **Code structure (LSP 기반)**: LSP로 함수/클래스/심볼 정의를 추출하여 정확한 시그니처 확보 (Grep fallback 가능)

## 2. Documentation Principles

1. **독자 파악**: 초보자/중급/전문가에 맞춤
2. **명확 간결**: 모호함 제거, 정확한 용어
3. **일관된 용어**: 전체 문서에서 동일 용어
4. **논리적 구조**: 개요 → 상세 → 예제 → 참조
5. **시각 자료**: 다이어그램, 스크린샷, 코드 예제
6. **실행 가능**: 단계별 지침, 작동하는 예제

## 3. Document Templates

### README Template
```markdown
# [프로젝트명]

[한 줄 설명]

## Features
- [주요 기능 1]
- [주요 기능 2]

## Installation
[설치 단계]

## Usage
[빠른 시작 예제]

## Configuration
[설정 옵션]

## API Reference
[API 개요 또는 링크]

## Contributing
[기여 가이드 링크]

## License
[라이선스]
```

### API Documentation Template
```markdown
## [엔드포인트명]

`METHOD /path/to/resource`

[설명]

### Request
**Headers**
| Name | Type | Required | Description |
|------|------|----------|-------------|

**Parameters**
| Name | Type | Required | Description |
|------|------|----------|-------------|

**Body**
```json
{
  "field": "value"
}
```

### Response
**Success (200)**
```json
{
  "result": "..."
}
```

**Error (4xx/5xx)**
```json
{
  "error": "..."
}
```

### Example
```bash
curl -X METHOD https://api.example.com/path
```
```

### Architecture Document Template
```markdown
# 아키텍처 문서

## 개요
[시스템 목적 및 범위]

## 구조
```
src/
├── presentation/
├── domain/
├── data/
└── di/
```

## 컴포넌트
### [컴포넌트 1]
- 역할: [...]
- 의존성: [...]

## 데이터 흐름
[다이어그램]

## 기술 결정
| 결정 | 선택 | 이유 |
|------|------|------|
```

### Guide Template
```markdown
# [가이드 제목]

## 개요
- **목적**: [이 가이드의 목적]
- **대상**: [독자]
- **소요 시간**: [예상 시간]
- **사전 요구사항**: [필요 지식/도구]

## 단계

### 1. [첫 번째 단계]
[상세 설명]

```bash
# 명령어
```

**확인**: [성공 여부 확인 방법]

### 2. [두 번째 단계]
...

## 트러블슈팅
| 문제 | 해결책 |
|------|--------|

## 다음 단계
[관련 문서 링크]
```

### Contributing Template
```markdown
# 기여 가이드

## 시작하기
[개발 환경 설정]

## 브랜치 전략
[브랜치 네이밍, 워크플로우]

## 커밋 규칙
[커밋 메시지 컨벤션: feat/fix/docs/...]

## PR 절차
[리뷰 요청, 머지 조건]

## 코드 스타일
[린트/포맷 규칙]
```

### CHANGELOG Template
```markdown
# Changelog

## [Unreleased]
### Added
### Changed
### Fixed
### Removed

## [1.0.0] - 2026-01-08
...
```

## 4. Writing Style

- **능동태**: "Click the button" (O) / "The button should be clicked" (X)
- **현재 시제**: "The function returns" (O) / "The function will return" (X)
- **2인칭**: 독자를 "you"로 지칭
- **짧은 문장**: 15-20 단어 이하
- **전문 용어 설명**: 필요시 용어집 제공
- **예제 중심**: 설명보다 보여주기

## 5. Code Example Standards

1. 완전하고 실행 가능한 예제
2. 언어 명시된 구문 강조
3. 복잡한 로직에 주석
4. 코드와 예상 출력 모두 표시
5. 에러 핸들링 예제 포함
6. 버전/의존성 명시

## 6. Content Generation

문서 타입별 생성 절차:
1. **코드 분석**: LSP/Grep/Read로 프로젝트 구조 이해
2. **정보 추출**:
   - 함수/클래스 (API 문서) — LSP 심볼 기반으로 정확한 시그니처 확보
   - 의존성 (Installation)
   - 엔트리 포인트 (Usage)
   - Git 히스토리 (Changelog)
3. **템플릿 적용**: 추출 정보로 템플릿 채우기
4. **예제 추가**: 실제 프로젝트 코드에서 스니펫 포함
5. **검증**: 완전성/링크/참조 유효성 확인

## 7. Language Detection

다음으로 언어 자동 감지:
- 기존 문서 언어
- 코드 주석 언어
- Git 커밋 메시지 언어
- 사용자 `--lang` 옵션 (명시 시 우선)

불확실하면 사용자에게 질문.

## 8. Output Workflow

생성 문서를 미리보기로 제시:
```
## 생성된 문서: README.md

[미리보기 - 처음 30줄]

...

파일 위치: /path/to/README.md
변경사항:
- 신규 생성 / 기존 업데이트
- [섹션별 요약]

---
저장|수정|취소
```

"저장" 선택 시:
- 파일 Write (존재 시 업데이트)
- 기존 파일 있으면 백업
- 성공 보고

## 9. Special Features

### API Documentation from Code (LSP 기반)
LSP로 함수/클래스 시그니처와 docstring을 추출하여 정확한 API 문서 생성:
```python
# Python example
def get_user(user_id: int) -> User:
    """
    Retrieve user by ID.

    Args:
        user_id: The user's unique identifier

    Returns:
        User object

    Raises:
        NotFoundError: If user doesn't exist
    """
    pass
```
→ OpenAPI spec 또는 Markdown으로 추출 (LSP 심볼 → 시그니처/타입, docstring → 설명)

### Git-based Changelog (커밋 분류)
```bash
git log --pretty=format:"%h - %s (%an, %ar)" --date=short
```
→ 커밋을 파싱하여 Conventional Commit prefix로 분류:
- `feat:` → Added
- `fix:` → Fixed
- `docs:`, `refactor:`, `chore:` → Changed
- `BREAKING CHANGE` / `!` → Removed/Breaking
→ CHANGELOG 섹션별로 자동 정리

## 10. Rules

1. **옵션 우선 파싱**: 분석 전에 옵션을 먼저 파싱
2. **코드 분석**: Glob/Grep/LSP으로 프로젝트 이해
3. **프로젝트 타입 감지**: 적절한 템플릿 선택
4. **기존 보존**: 업데이트 시 기존 내용 유지
5. **일관성**: 프로젝트 스타일 따르기
6. **검증**: 링크, 참조 유효성 확인
7. **푸터**: "Generated by /tech-doc-writer" 푸터 추가
8. **다국어**: 한국어/영어 모두 지원, 실제 프로젝트 코드 예제 포함
9. **Token 최적화**: 아래 출력 효율성 가이드 준수

### Token Optimization Rules

1. **출력 효율성**
   - **diff-only**: 변경 부분만 표시, 전체 문서 재출력 금지
   - **참조 형식**: 긴 문서는 섹션별 요약
   - **반복 축약**: 템플릿은 1회만 표시
   - **코드 우선**: 예제 코드로 설명 대체
   - **최소 설명**: 자명한 부분은 주석 불필요

2. **중복 방지**
   - 기존 문서와 중복 내용 제거
   - 이미 설명한 섹션 재설명 금지
   - 요약 → 상세 순서로 점진적 표시

3. **구조화된 출력**
   - 문서 미리보기: 처음 30줄만
   - 변경사항: diff 형식
   - 섹션별 체크리스트
   - 테이블로 구조화

---

## Final Metadata Output

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 실행 정보

스킬: /tech-doc-writer
모델: [haiku|sonnet|opus]
문서 타입: [readme|api|guide|...]
언어: [ko|en]
생성 파일: [경로]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
