# /pipeline - Agent Pipeline

PRD 기반 전체 파이프라인을 실행합니다: Gate → Scan → Fold → Verdict → Patch → Trace

## Usage

```bash
/pipeline [prd_file] [options]
```

## Pipeline Stages

```
┌─────────┐    ┌─────────┐    ┌─────────┐    ┌──────────┐    ┌─────────┐    ┌─────────┐
│  Gate   │ -> │  Scan   │ -> │  Fold   │ -> │ Verdict  │ -> │  Patch  │ -> │  Trace  │
│  검증   │    │  분석   │    │  평가   │    │   판단   │    │  구현   │    │  기록   │
└─────────┘    └─────────┘    └─────────┘    └──────────┘    └─────────┘    └─────────┘
```

| Stage | Description |
|-------|-------------|
| **Gate** | PRD 유효성 검사 |
| **Scan** | 코드베이스 분석 |
| **Fold** | 요구사항 종합 |
| **Verdict** | 최종 판단 (PASS/FIX/FAIL) |
| **Patch** | 구현 (PASS인 경우) |
| **Trace** | 로깅 |

## Options

| Option | Description |
|--------|-------------|
| `--dry-run` | 실행 계획만 표시 |
| `--verbose` | 상세 로깅 |
| `--retry N` | 실패 시 N회 재시도 |
| `--parallel` | 병렬 실행 (실험적) |

## Examples

```bash
/pipeline prd/feature-xyz.md     # 전체 파이프라인 실행
/pipeline --dry-run prd/bug.md   # 실행 계획만 확인
/pipeline --verbose prd/api.md   # 상세 로그 출력
```

## Verdict System

| Verdict | Confidence | Description |
|---------|------------|-------------|
| **PASS** | >= 0.9 | PRD가 충분히 상세함, 구현 진행 |
| **FIX** | >= 0.5 | PRD 개선 필요, 수정 후 재검증 |
| **FAIL** | < 0.5 | PRD 불충분, 처음부터 작성 |

## Related Commands

- `/prd` - PRD 생성
- `/gate` - PRD 검증만 실행
- `/quick` - 빠른 핫픽스 (Gate/Fold 생략)
- `/stats` - 파이프라인 통계
