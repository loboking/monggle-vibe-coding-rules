# /prd - PRD Creator

Interactive PRD (Product Requirements Document) creation command v2.4.

## Usage

```bash
/prd <type> [options]
```

## Types

| Type | Description |
|------|-------------|
| `feature` | 새로운 기능 개발 |
| `bug` | 버그 수정 |
| `refactor` | 리팩토링 |
| `hotfix` | 긴급 핫픽스 (fast-track) |
| `experiment` | 실험적 기능 |
| `api` | API 개발 |
| `migration` | DB 마이그레이션 |
| `ml` | ML 모델 개발 |
| `devops` | DevOps 자동화 |

## Options

| Option | Description |
|--------|-------------|
| `--non-interactive` | 비대화형 모드 (기본값 사용) |
| `--output <path>` | 출력 파일 경로 지정 |
| `--language <lang>` | PRD 언어 (ko, en, zh, ja) |
| `--auto-pipeline` | PRD 생성 후 자동 파이프라인 실행 |
| `--auto-lint` | 파이프라인 완료 후 자동 린트 실행 |

## Examples

```bash
/prd feature                # 새 기능 PRD (언어 선택 프롬프트)
/prd bug                    # 버그 수정 PRD
/prd api                    # API 설계 PRD
/prd --language en feature   # 영어 PRD (언어 지정)
/prd --auto-pipeline bug     # PRD 생성 후 자동 파이프라인
```

## Language Options

- `ko` - 한국어 (기본값)
- `en` - English
- `zh` - 中文
- `ja` - 日本語

## Output

PRD는 `prd/` 디렉토리에 생성됩니다:
```
prd/feature-20260408-143022.md
prd/bug-20260408-150415.md
```

## Related Commands

- `/pipeline` - PRD 기반 파이프라인 실행
- `/gate` - PRD 품질 검증
- `/init` - 초기 설정 (언어 기본값)
