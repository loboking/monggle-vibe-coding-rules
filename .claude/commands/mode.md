# /mode - Work Mode Selection

작업 모드를 선택합니다. Solo(혼자) 또는 Team(팀과 함께).

## Usage

```bash
/mode                    # 현재 모드 확인
/mode solo              # Solo 모드로 변경
/mode team              # Team 모드로 변경
```

## Modes

| 모드 | 특징 | 사용 경우 |
|------|------|----------|
| **Solo** | 개인 작업 최적화 | 혼자 개발 |
| **Team** | 팀 협업 고려 | PRD 공유, 코드 리뷰 |

## Configuration

모드 설정은 `.claude/config/mode.conf`에 저장됩니다:

```ini
WORK_MODE=solo
```

또는 `/init` 명령어로 설정할 수 있습니다:

```bash
/init                    # 초기 설정 워드 실행
```

## Impact

모드 설정은 다음에 영향을 줍니다:

- PRD 템플릿 형식
- 코드 리뷰 검토 항목
- 커밋 메시지 템플릿
- 문서화 가이드라인

## Examples

```bash
$ /mode
Current mode: solo

$ /mode team
✅ Switched to team mode
```

## Related Commands

- `/init` - 초기 설정 (모드 포함)
- `/prd` - 현재 모드로 PRD 생성
