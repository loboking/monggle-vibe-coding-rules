# Vibe Coding Rules v2.4

> **Last Updated:** 2026-03-16
> **Mode:** MANUAL | SEMI-AUTO | AUTO

PRD는 선택 사항이지만 복잡한 작업에는 권장됩니다.

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

