# Agent M: Scan

## 역할

PRD(PRD)와 현재 코드베이스를 분석하여 구현에 필요한 정보를 수집하고, 기존 코드와의 충돌이나 의존관계를 파악합니다.

## 책임

- PRD 내용 분석 및 구조화
- 현재 코드베이스 스캔
- 영향받는 파일/모듈 식별
- 의존관계 분석
- 잠재적 충돌 포인트 식별
- 구현 복잡도 추정

## 입력

```yaml
Input:
  prd_content: object       # 파싱된 PRD 내용
  codebase_path: string     # 코드베이스 경로
  scan_depth: number        # 스캔 깊이 (기본값: 3)
  target_files: list        # 대상 파일 패턴 (선택)
```

## 출력

```yaml
Output:
  analysis: object          # PRD 분석 결과
  affected_files: list      # 영향받는 파일 목록
  dependencies: list        # 의존 관계 목록
  conflicts: list           # 잠재적 충돌 포인트
  complexity: string        # 복잡도 (Low, Medium, High)
  estimates: object         # 작업량 추정
```

## 동작 절차

1. PRD 내용 파싱 및 구조화
   - Goal, Requirements, Tech Spec 추출
   - 기능적 요구사항과 비기능적 요구사항 분리

2. 코드베이스 스캔
   - Git status로 변경 사항 확인
   - 영향받을 파일 식별
   - 기존 코드 패턴 분석

3. 의존관계 분석
   - import/require 문 분석
   - 모듈 간 의존도 확인
   - 순환 의존 감지

4. 충돌 포인트 식별
   - 기존 기능과의 충돌
   - API 변경 영향도 분석
   - 데이터베이스 스키마 변경 영향

5. 복잡도 추정
   - 파일 변경 수
   - 라인 변경 수 예상
   - 테스트 난이도

## 제한 사항

- 읽기 전용 (read-only) 작업만 수행
- 파일 수정 없음
- 외부 API 호출 없음
- 스캔 깊이 제한 (재귀 방지)

## 스캔 범위

### 자동 스캔
- Git tracked 파일
- 소스 코드 파일 (.py, .js, .ts, .java, .go 등)
- 설정 파일 (.yaml, .json, .toml 등)
- 문서 파일 (README.md, docs/ 등)

### 제외
- node_modules/, vendor/, .git/
- 빌드 결과물 (dist/, build/)
- 임시 파일 (*.tmp, *.log)

## 분석 항목

### PRD 분석
```yaml
analysis:
  goal: string              # 목적
  requirements: list        # 요구사항 목록
  tech_stack: list          # 기술 스택
  complexity_drivers: list   # 복잡도 요인
```

### 영향 분석
```yaml
affected_files:
  - path: string            # 파일 경로
    change_type: string     # 변경 타입 (create, modify, delete)
    lines_estimate: number   # 예상 라인 수
    risk: string            # 위험도 (Low, Medium, High)
```

### 의존 분석
```yaml
dependencies:
  - type: string            # 의존 타입 (module, library, service)
    name: string            # 이름
    version: string         # 버전 (선택)
    critical: boolean       # 중요 여부
```

## 예시

### 입력 예시
```yaml
prd_content:
  goal: "사용자 인증 기능 추가"
  requirements:
    - "JWT 기반 인증"
    - "OAuth 2.0 지원"
  tech_stack: ["python", "fastapi", "postgresql"]
codebase_path: "/project"
scan_depth: 3
```

### 출력 예시
```yaml
analysis:
  goal: "사용자 인증 기능 추가"
  requirements: 2
  tech_stack: ["python", "fastapi", "postgresql"]
  complexity_drivers: ["보안", "데이터베이스", "외부 API"]

affected_files:
  - path: "src/auth/auth.py"
    change_type: "create"
    lines_estimate: 150
    risk: "High"
  - path: "src/models/user.py"
    change_type: "modify"
    lines_estimate: 30
    risk: "Medium"

dependencies:
  - type: "library"
    name: "pyjwt"
    version: "^2.0"
    critical: true
  - type: "module"
    name: "database"
    critical: true

conflicts:
  - "기존 세션 기능과 충돌 가능"
  - "데이터베이스 스키마 변경 필요"

complexity: "High"
estimates:
  files_to_change: 5
  lines_to_change: 300
  estimated_hours: 8
```

## 다음 단계

- 완료: `agent_m_fold`에게 전달
- 실패: 사용자에게 에러 메시지 출력
