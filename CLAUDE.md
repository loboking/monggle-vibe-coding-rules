# Vibe Coding Rules v3.5.0

> **Last Updated:** 2026-04-17
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

## 🤖 자동 스킬 실행 시스템 (의도 기반)

**핵심 원칙**: 사용자의 입력에서 **의도(intent)**를 파악하여 자동으로 적절한 스킬을 실행합니다. 키워드 매칭이 아니라 **의미 이해**가 핵심입니다.

### 의도 분석 및 스킬 매핑

사용자의 어떤 표현이든 **의도**를 파악하세요:

#### 🔍 Debug 카테고리

| 사용자 의도 | 자동 실행 스킬 | 예시 (다양한 표현) |
|-----------|--------------|------------------|
| **"버그가 나"** | `debug-master` | "버그", "오류", "안돼", "에러", "error", "broken", "작동 안해", "고장" |
| **"왜 이러지?"** | `debug-master` | "왜 안돼?", "이유", "원인", "why", "고장난 것 같아", "문제 발생" |
| **"느려"** | `bottleneck` | "느려", "느림", "최적화", "병목", "slow", "lag", "성능", "터짐" |
| **"메모리 문제"** | `debug-master` | "메모리", "RAM", "누수", "memory leak", "oom", "메모리 부족" |
| **"프론트 오류"** | `front-bugfix` | "프론트", "js 오류", "react 버그", "클릭 안돼", "화면 문제" |
| **"스타일 오류"** | `css-bugfix` | "css", "스타일", "레이아웃", "디자인", "깨짐", "정렬" |

#### ✅ QA 카테고리

| 사용자 의도 | 자동 실행 스킬 | 예시 (다양한 표현) |
|-----------|--------------|------------------|
| **"작동 확인"** | `/qa` | "작동해?", "되나요?", "테스트", "작동 확인", "working?", "동작 확인" |
| **"점검해줘"** | `/qa` | "점검", "확인해봐", "검사", "check", "inspect", "테스트해봐" |
| **"보고서만"** | `/qa --report` | "보고서만", "리포트", "수정하지 마", "보고만", "report only" |
| **"빠른 테스트"** | `/qa --quick` | "빠르게 확인", "훑어봐", "quick test", "스모크 테스트" |

#### 👁️ Review 카테고리

| 사용자 의도 | 자동 실행 스킬 | 예시 (다양한 표현) |
|-----------|--------------|------------------|
| **"코드 검토"** | `review` | "리뷰해줘", "검토해봐", "코드 봐줘", "Review this", "Check code", "피드백줘" |
| **"품질 체크"** | `code-reviewer` | "품질", "코드 품질", "quality", "best practice", "코드 컨벤션" |
| **"구조 검토"** | `architecture-designer` | "아키텍처", "설계", "구조", "architecture", "설계 검토" |

#### 🛠️ 기타 스킬

| 사용자 의도 | 자동 실행 스킬 | 예시 (다양한 표현) |
|-----------|--------------|------------------|
| **"계획을 세워줘"** | `/prd` | "기획서 작성", "PRD 만들어줘", "계획 세워", "Planning", "요구사항 정리" |
| **"보안 점검"** | `/audit` | "보안 점검", "취약점", "Security check", "Audit", "보안 검사" |
| **"복잡도 분석"** | `/complexity` | "복잡해", "복잡도", "너무 어려워", "Complex", "복잡도 분석" |
| **"속도 비교"** | `/bench` | "벤치마크", "성능 비교", "빠른 게 뭐?", "Benchmark", "Compare" |
| **"API 문서"** | `/api-docs` | "API 문서", "API docs", "docstring 변환", "자동 문서화" |
| **"변경 로그"** | `/changelog` | "변경 로그", "CHANGELOG", "커밋 내역 정리", "변경사항 정리" |
| **"버전 업"** | `/bump` | "버전 업", "태그 생성", "release", "배포 준비" |
| **"코드 공유"** | `/push-safe` | "올려", "푸시", "공유", "Push", "동기화", "코드 올리기" |
| **"포맷 점검"** | `/format-check` | "포맷 확인", "lint check", "스타일 검사" |
| **"품질 검사"** | `/lint-smart` | "린트", "코드 품질", "quality check" |
| **"아이디어"** | `/brainstorm` | "아이디어", "브레인스토밍", "생각해", "아이디어링" |
| **"진행 상황"** | `/stats` | "통계", "현황", "status", "진행 상황", "pipeline trace" |
| **"상태 저장"** | `/save-point` | "저장", "세이브", "checkpoint", "상태 저장" |
| **"핫픽스"** | `/quick` | "빨리 수정", "핫픽스", "quick fix" |
| **"PRD 검증"** | `/gate` | "PRD 검증", "gate", "품질 확인" |
| **"파이프라인"** | `/pipeline` | "파이프라인", "전체 실행", "자동화" |
| **"프로파일링"** | `/profile` | "프로파일", "성능 분석", "profiling", "성능 프로파일" |
| **"추적"** | `/trace` | "추적", "트레이스", "trace", "실행 경로" |
| **"코드 동기화"** | `/update` | "코드 가져오기", "동기화", "update", "코드 업데이트" |
| **"초기화"** | `/init` | "설정", "초기화", "setup", "설정 초기화" |
| **"모드 변경"** | `/mode` | "모드 변경", "solo", "team" |

### Claude 실행 프로세스

**1단계: 의도 파악**
- 사용자 입력의 **핵심 의도**를 파악하세요
- 표면적인 단어가 아니라 **무엇을 원하는지** 이해하세요
- 언어(한국어/영어/기타)와 표현 방식은 상관없습니다

**2단계: 스킬 선택**
- 파악된 의도에 해당하는 스킬을 찾으세요
- 여러 스킬이 가능하면 가장 적합한 것을 선택하세요

**3단계: 자동 실행**
- 사용자에게 확인하지 말고 **즉시 실행**하세요
- 실행 전에 간단히 알리세요: "의도: [의도] → /{skill} 실행합니다"

**4단계: 결과 보고**
- 실행 결과를 명확히 보고하세요
- 추가 조치가 필요하면 제안하세요

### 언어 독립적 의도 파악

**핵심**: 같은 의도라면 어떤 언어로든 인식하세요.

| 의도 | 한국어 예시 | 영어 예시 | 다른 표현 |
|-----|-----------|----------|----------|
| "작동 확인" | "작동해?", "되나요?", "확인해" | "Does it work?", "Working?", "Check" | "OK?", "동작?", "작동?" |
| "버그 수정" | "버그", "오류", "안돼" | "Bug", "Error", "Broken" | "고장", "안됨", "fail" |
| "배포" | "배포", "커밋", "푸시" | "Deploy", "Commit", "Push" | "올려", "save", "upload" |

### 예시 시나리오

**시나리오 1: 계획 수립 (한국어)**
```
사용자: "로그인 기능 추가할 건데 기획 좀 세워줘"
Claude 분석: 의도 = "계획 수립 요청"
→ 자동 실행: /prd
→ 결과: PRD 생성 완료.prd/feature-auth-20260417.md
```

**시나리오 2: 코드 검토 (영어)**
```
사용자: "Can you review this code?"
Claude 분석: 의도 = "코드 검토 요청"
→ 자동 실행: /review
→ 결과: Review completed. 3 suggestions found.
```

**시나리오 3: 성능 문제**
```
사용자: "너무 느려"
Claude 분석: 의도 = "성능 문제"
→ 자동 실행: /bottleneck
→ 결과: 병목 지점 분석 완료. DB 쿼리 최적화 제안.
```

**시나리오 4: 보안 점검**
```
사용자: "보안 문제 없나 확인해줘"
Claude 분석: 의도 = "보안 점검 요청"
→ 자동 실행: /audit
→ 결과: 취약점 스캔 완료. 2건 발견.
```

**시나리오 5: Git 동기화**
```
사용자: "코드 올릴게"
Claude 분석: 의도 = "Git push/동기화"
→ 자동 실행: /push-safe
→ 결과: 안전하게 push 완료. PR 생성됨.
```

---

## TDD Testing (Option 3: Combined)

통합 TDD 접근법으로 Python unittest와 bats-core를 병행 사용합니다.

### 테스트 구조

```
tests/
├── test_init_core.py      # Python: 프로젝트 초기화 테스트
├── test_agents.py          # Python: 에이전트 테스트
├── test_lib_sh.py          # Python: Bash 라이브러리 테스트 (신규)
├── bash/
│   └── skills.bats         # bats: 스킬 스크립트 테스트 (신규)
└── run_tests.sh            # 통합 테스트 실행기 (신규)
```

### 테스트 실행

```bash
# 전체 테스트 (Python + bats)
./tests/run_tests.sh

# Python 테스트만
./tests/run_tests.sh --python

# bats 테스트만
./tests/run_tests.sh --bats

# 상세 출력
./tests/run_tests.sh --verbose

# 직접 실행
python3 tests/test_lib_sh.py
bats tests/bash/skills.bats
```

### 테스트 커버리지

| 카테고리 | Python | bats | 합계 |
|----------|--------|------|------|
| 라이브러리 | 26 | 14 | 40 |
| P0 보안 | 4 | 4 | 8 |
| P1 아키텍처 | 5 | 5 | 10 |
| 통합/스킬 | - | 15 | 15 |
| **합계** | **35** | **34** | **69** |

### CI/CD 통합

GitHub Actions에서 Linux + macOS 매트릭스로 실행:
- ShellCheck 정적 분석
- Python unittest (test_init_core.py, test_lib_sh.py)
- bats-core (skills.bats)

---

## Current Mode

**MANUAL** 모드로 실행 중입니다.

- `/mode` - 현재 모드 확인
- `/mode solo` - Solo 모드로 변경
- `/mode team` - Team 모드로 변경

---

## Agent Pipeline

### Pipeline Stages

1. **Gate** - PRD 유효성 검사
2. **Scan** - 코드베이스 분석
3. **Fold** - 요구사항 종합
4. **Verdict** - 최종 판단 (PASS/FIX/FAIL)
5. **Patch** - 구현 (PASS인 경우)
6. **Trace** - 로깅

### Pipeline Commands

```bash
/pipeline [prd_file] [options]   # 파이프라인 실행
/pipeline --dry-run              # 실행 계획만 표시
/pipeline --verbose              # 상세 로깅
/pipeline --retry 3              # 실패 시 3회 재시도
/pipeline --parallel             # 병렬 실행 (실험적)
```

---

## Verdict System

| Verdict | Confidence | Description |
|---------|------------|-------------|
| **PASS** | >= 0.9 | PRD가 충분히 상세함, 구현 진행 |
| **FIX** | >= 0.5 | PRD 개선 필요, 수정 후 재검증 |
| **FAIL** | < 0.5 | PRD 불충분, 처음부터 작성 |

---

## PRD System v2.4

### PRD Types

- `feature` - 새로운 기능 개발
- `bug` - 버그 수정
- `refactor` - 리팩토링
- `hotfix` - 긴급 핫픽스 (Fast-track)
- `experiment` - 실험적 기능

**New in v2.4:**
- `api` - API 전용 PRD
- `migration` - DB 마이그레이션 PRD
- `ml` - ML 모델 개발 PRD
- `devops` - DevOps 자동화 PRD

### PRD Commands

```bash
/prd                    # 대화형 PRD 생성
/prd feature            # 특정 타입으로 생성
/prd api                # v2.4: API PRD 생성
/prd --list-templates   # 사용 가능한 템플릿 목록
```

### PRD Validation v2.4

- **자동 수정 제안:** 누락된 섹션에 대한 구체적인 수정 가이드
- **구체적 에러 메시지:** 어떤 부분이 문제인지 명확히 표시
- **자동 백업:** 검증 전에 PRD 자동 백업 (최대 10개)

---

## Statistics v2.4

```bash
/stats                   # 기본 통계
/stats --verbose         # 상세 통계 + 시각화
/stats --web             # 웹 대시보드 생성
/stats --json            # JSON 출력

# 필터링
/stats --filter-verdict PASS
/stats --filter-type feature
/stats --since 2024-01-01
```

### 시각화 기능

- **ASCII 바 차트:** Verdict 분포, PRD 타입 분포
- **스파크라인:** 실행 추이, 에이전트 성능 추이
- **타임라인:** 최근 Verdict 히스토리

---

## Quick Commands

```bash
/quick                   # 빠른 핫픽스 (Gate/Fold 생략)
/review                  # AI Reviewer 실행
/mode solo/team          # 모드 변경
/stats                   # 파이프라인 통계
```

---

## Free Chat Rules

자유로운 대화를 위해 다음 작업은 PRD 없이 진행 가능:

- 설명 요청
- 코드 리뷰
- 문서화
- 간단한 수정

개발 작업은 PRD 작성을 권장합니다.

---

## Configuration Files

| File | Description |
|------|-------------|
| `CLAUDE.md` | 이 파일 |
| `.claude/commands/` | 명령어 스크립트 |
| `.claude/hooks/` | PRD 검증 훅 |
| `.claude/config/` | 모드별 설정 |
| `prd/templates/` | PRD 템플릿 |
| `logs/` | 파이프라인 로그 |

---

## 최근 변경 내역

> 이 섹션은 Claude Code hooks에 의해 자동으로 업데이트됩니다.

### 2026-03-16 - v2.4 Release

**Pipeline Statistics 강화:**
- ASCII 시각화 (바 차트, 스파크라인, 타임라인)
- 로그 필터링 (verdict, PRD type, agent, date)
- 웹 대시보드 (`/stats --web`)
- 에이전트 실행 시간 분석

**PRD 템플릿 확장:**
- API 전용 템플릿 (`/prd api`)
- DB 마이그레이션 템플릿 (`/prd migration`)
- ML 모델 개발 템플릿 (`/prd ml`)
- DevOps 자동화 템플릿 (`/prd devops`)

**에이전트 실행 옵션 강화:**
- `--verbose` 상세 로그
- `--retry N` 자동 재시도
- `--parallel` 병렬 실행 (실험적)

**PRD 검증 개선:**
- 자동 수정 제안
- 구체적인 에러 메시지
- PRD 버전 관리 (자동 백업)

### 2026-03-16

**변경된 파일 수**:

```
[09:21:46] 수정: OceanBleuClaud/src/main/java/com/oceanbleu/cloud/InitClaud.kt
[09:22:16] 수정: OceanBleuClaud/src/main/java/com/oceanbleu/cloud/network/WebBridgePluginManager.kt
```

### 2026-03-31

**변경된 파일 수**: ��

```
[09:49:40] 수정: appium-tests/src/test/kotlin/com/ocean/appium/tests/BaseTest.kt
[09:49:44] 수정: appium-tests/src/test/kotlin/com/ocean/appium/tests/BaseTest.kt
```


### 2026-04-02

**변경된 파일 수**: ��

```
[08:35:04] 수정: app/src/main/java/com/ocean/moacloud/activity/MainActivity.kt
[08:35:15] 수정: OceanBleuClaud/src/main/java/com/oceanbleu/cloud/InitClaud.kt
[08:35:25] 수정: app/src/main/java/com/ocean/moacloud/activity/MainActivity.kt
[08:36:13] 수정: OceanBleuClaud/src/main/java/com/oceanbleu/cloud/InitClaud.kt
[08:36:24] 수정: app/src/main/java/com/ocean/moacloud/activity/MainActivity.kt
[08:36:54] 수정: OceanBleuClaud/src/main/java/com/oceanbleu/cloud/InitClaud.kt
[08:37:30] 수정: app/src/main/java/com/ocean/moacloud/activity/MainActivity.kt
```


### 2026-04-07

**변경된 파일 수**: ��

```
[10:19:04] 수정: OceanBleuClaud/src/main/java/com/oceanbleu/cloud/network/WebBridgePluginManager.kt
[10:19:21] 수정: OceanBleuClaud/src/main/java/com/oceanbleu/cloud/network/WebBridgePluginManager.kt
```


### 2026-04-09

**변경된 파일 수**: ��

```
[13:13:10] 수정: core/pedometer-api/src/main/AndroidManifest.xml
[13:13:10] 수정: core/pedometer-core/src/main/AndroidManifest.xml
[13:13:16] 수정: features/pedometer-aos/src/main/AndroidManifest.xml
[13:13:16] 수정: features/pedometer-lgu/src/main/AndroidManifest.xml
[13:13:16] 수정: features/pedometer-sk/src/main/AndroidManifest.xml
[13:13:19] 수정: libraries/pedometer-aos-lib/src/main/AndroidManifest.xml
[13:13:19] 수정: libraries/pedometer-lgu-lib/src/main/AndroidManifest.xml
[13:13:19] 수정: libraries/pedometer-sk-lib/src/main/AndroidManifest.xml
[13:13:25] 수정: samples/sample-aos/src/main/AndroidManifest.xml
[13:13:25] 수정: samples/sample-lgu/src/main/AndroidManifest.xml
[13:13:25] 수정: samples/sample-sk/src/main/AndroidManifest.xml
[13:13:33] 수정: samples/sample-aos/src/main/java/com/oceanbleu/pedometer/sample/aos/MainActivity.kt
[13:13:33] 수정: samples/sample-lgu/src/main/java/com/oceanbleu/pedometer/sample/lgu/MainActivity.kt
[13:13:33] 수정: samples/sample-sk/src/main/java/com/oceanbleu/stepcount/sample/sk/MainActivity.kt
[13:13:35] 수정: samples/sample-aos/src/main/res/values/strings.xml
[13:13:35] 수정: samples/sample-lgu/src/main/res/values/strings.xml
[13:13:35] 수정: samples/sample-sk/src/main/res/values/strings.xml
[13:13:45] 수정: samples/sample-aos/src/main/res/layout/activity_main.xml
[13:13:45] 수정: samples/sample-lgu/src/main/res/layout/activity_main.xml
[13:13:45] 수정: samples/sample-sk/src/main/res/layout/activity_main.xml
[13:16:17] 수정: samples/sample-aos/src/main/AndroidManifest.xml
[13:16:22] 수정: samples/sample-lgu/src/main/AndroidManifest.xml
[13:16:22] 수정: samples/sample-sk/src/main/AndroidManifest.xml
[13:16:51] 수정: features/pedometer-sk/src/main/AndroidManifest.xml
[13:16:58] 수정: features/pedometer-aos/src/main/AndroidManifest.xml
[13:16:58] 수정: features/pedometer-lgu/src/main/AndroidManifest.xml
```


### 2026-04-13

**변경된 파일 수**: ��

```
[16:59:39] 수정: OceanBleuClaud/src/main/java/com/oceanbleu/cloud/network/WebBridgePluginManager.kt
[17:00:23] 수정: OceanBleuClaud/src/main/java/com/oceanbleu/cloud/network/WebBridgePluginManager.kt
```


### 2026-04-22

**변경된 파일 수**: ��

```
[16:39:03] 수정: app/build.gradle
[16:40:23] 수정: app/build.gradle
[16:40:28] 수정: app/build.gradle
[16:45:42] 수정: app/build.gradle
```


### 2026-04-27

**변경된 파일 수**: ��

```
[12:42:52] 수정: app/src/main/java/com/ocean/moacloud/ApplicationClass.kt
```


### 2026-05-11

**변경된 파일 수**: ��

```
[13:54:59] 수정: OceanBleuClaud/src/main/java/com/oceanbleu/cloud/auth/OneDriveAuthManager.kt
[13:55:03] 수정: OceanBleuClaud/src/main/java/com/oceanbleu/cloud/auth/OneDriveAuthManager.kt
[13:55:28] 수정: OceanBleuClaud/src/main/java/com/oceanbleu/cloud/auth/OneDriveAuthManager.kt
[13:55:56] 수정: OceanBleuClaud/src/test/java/com/oceanbleu/cloud/auth/OneDriveAuthManagerTest.kt
[13:56:04] 수정: OceanBleuClaud/src/test/java/com/oceanbleu/cloud/auth/OneDriveAuthManagerTest.kt
[13:56:09] 수정: OceanBleuClaud/src/main/java/com/oceanbleu/cloud/auth/OneDriveAuthManager.kt
```


### 2026-05-13

**변경된 파일 수**: ��

```
[09:06:09] 수정: OceanBleuClaud/src/main/java/com/oceanbleu/cloud/network/WebBridgePluginManager.kt
[09:07:22] 수정: OceanBleuClaud/src/main/java/com/oceanbleu/cloud/network/WebBridgePluginManager.kt
[09:07:39] 수정: OceanBleuClaud/src/main/java/com/oceanbleu/cloud/network/WebBridgePluginManager.kt
[09:08:03] 수정: OceanBleuClaud/src/main/java/com/oceanbleu/cloud/InitClaud.kt
[09:08:48] 수정: OceanBleuClaud/src/main/java/com/oceanbleu/cloud/InitClaud.kt
[09:09:33] 수정: OceanBleuClaud/src/main/java/com/oceanbleu/cloud/act/viewmodel/CloudViewModel.kt
[09:09:43] 수정: OceanBleuClaud/src/main/java/com/oceanbleu/cloud/InitClaud.kt
[09:11:02] 수정: OceanBleuClaud/src/test/java/com/oceanbleu/cloud/network/WebBridgePluginManagerSearchTest.kt
[09:11:26] 수정: OceanBleuClaud/src/test/java/com/oceanbleu/cloud/network/WebBridgePluginManagerSearchTest.kt
[09:11:51] 수정: OceanBleuClaud/src/test/java/com/oceanbleu/cloud/network/WebBridgePluginManagerSearchTest.kt
[09:12:12] 수정: OceanBleuClaud/src/test/java/com/oceanbleu/cloud/network/WebBridgePluginManagerSearchTest.kt
[09:12:20] 수정: OceanBleuClaud/src/test/java/com/oceanbleu/cloud/network/WebBridgePluginManagerSearchTest.kt
[09:12:32] 수정: OceanBleuClaud/src/test/java/com/oceanbleu/cloud/network/WebBridgePluginManagerSearchTest.kt
[09:12:52] 수정: OceanBleuClaud/src/test/java/com/oceanbleu/cloud/network/WebBridgePluginManagerSearchTest.kt
[09:13:00] 수정: OceanBleuClaud/src/test/java/com/oceanbleu/cloud/network/WebBridgePluginManagerSearchTest.kt
[09:13:09] 수정: OceanBleuClaud/src/test/java/com/oceanbleu/cloud/network/WebBridgePluginManagerSearchTest.kt
```


### 2026-05-14

**변경된 파일 수**: ��

```
[09:17:53] 수정: OceanBleuClaud/src/main/java/com/oceanbleu/cloud/permission/PermissionManager.kt
[09:18:45] 수정: OceanBleuClaud/src/main/java/com/oceanbleu/cloud/network/WebBridgePluginManager.kt
```


### 2026-05-15

**변경된 파일 수**: ��

```
[09:35:53] 수정: OceanBleuClaud/src/main/java/com/oceanbleu/cloud/Config.kt
```


### 2026-05-18

**변경된 파일 수**: ��

```
[12:34:36] 수정: OceanBleuClaud/src/main/java/com/oceanbleu/cloud/network/WebBridgePluginManager.kt
```


### 2026-05-19

**변경된 파일 수**: ��

```
[13:56:32] 수정: OceanBleuClaud/src/main/java/com/oceanbleu/cloud/network/WebBridgePluginManager.kt
```


### 2026-05-20

**변경된 파일 수**: ��

```
[15:30:32] 수정: app/src/main/java/co/kr/oceanbleu/safephone/activity/LostModeActivity.kt
[15:30:55] 수정: app/src/main/java/co/kr/oceanbleu/safephone/activity/LostModeActivity.kt
```


### 2026-06-16

**변경된 파일 수**: ��

```
[13:30:53] 수정: OceanBleuClaud/src/main/java/com/oceanbleu/cloud/cloud/provider/webhard/WebHardProvider.kt
[13:31:07] 수정: OceanBleuClaud/src/main/java/com/oceanbleu/cloud/cloud/provider/webhard/WebHardProvider.kt
[13:31:29] 수정: OceanBleuClaud/src/main/java/com/oceanbleu/cloud/cloud/provider/webhard/WebHardProvider.kt
[13:31:36] 수정: OceanBleuClaud/src/main/java/com/oceanbleu/cloud/cloud/provider/webhard/WebHardProvider.kt
[13:31:38] 수정: OceanBleuClaud/src/main/java/com/oceanbleu/cloud/cloud/provider/webhard/WebHardProvider.kt
```


### 2026-06-17

**변경된 파일 수**: ��

```
[12:14:57] 수정: OceanBleuClaud/src/main/java/com/oceanbleu/cloud/network/WebBridgePluginManager.kt
[12:15:12] 수정: OceanBleuClaud/src/main/java/com/oceanbleu/cloud/network/WebBridgePluginManager.kt
[12:15:41] 수정: OceanBleuClaud/src/main/java/com/oceanbleu/cloud/network/WebBridgePluginManager.kt
```


### 2026-06-24

**변경된 파일 수**: ��

```
[09:07:34] 수정: apps/android/app/src/main/java/kr/co/doubledsoft/topdrawer/data/DataSource.kt
[09:07:43] 수정: apps/android/app/src/main/java/kr/co/doubledsoft/topdrawer/data/CacheManager.kt
[09:08:04] 수정: apps/android/app/src/main/java/kr/co/doubledsoft/topdrawer/ui/AppViewModel.kt
```


### 2026-06-25

**변경된 파일 수**: ��

```
[14:34:32] 수정: OceanBleuClaud/src/main/java/com/oceanbleu/cloud/picker/PickerCustomTab.kt
```


### 2026-06-26

**변경된 파일 수**: ��

```
[09:59:05] 수정: apps/android/app/src/main/java/kr/co/doubledsoft/topdrawer/ui/AppScreen.kt
[10:00:14] 수정: apps/android/app/src/main/java/kr/co/doubledsoft/topdrawer/ui/AppViewModel.kt
```


### 2026-06-30

**변경된 파일 수**: 

```
[09:51:07] 수정: apps/android/app/src/main/java/kr/co/doubledsoft/topdrawer/data/Trash.kt
[09:51:18] 수정: apps/android/app/src/main/java/kr/co/doubledsoft/topdrawer/ui/AppViewModel.kt
[09:51:32] 수정: apps/android/app/src/main/java/kr/co/doubledsoft/topdrawer/ui/AppViewModel.kt
[09:51:51] 수정: apps/android/app/src/main/java/kr/co/doubledsoft/topdrawer/sync/Merge.kt
[09:52:12] 수정: apps/android/app/src/main/java/kr/co/doubledsoft/topdrawer/ui/AppViewModel.kt
```

