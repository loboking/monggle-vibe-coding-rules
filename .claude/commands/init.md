# /init - Initial Setup Wizard

최초 1회 실행하여 기본 환경을 설정합니다. 설정은 `.claude/config/user.conf`에 저장됩니다.

## Usage

```bash
/init           # 초기 설정 실행 (설정 있으면 변경 여부 질문)
/init --reset   # 설정 초기화 후 재설정
```

## Setup Items

| Item | Options | Description |
|------|---------|-------------|
| **작업 모드** | Solo / Team | 혼자 작업 또는 팀과 함께 |
| **PRD 언어** | ko / en / zh / ja | PRD 생성 기본 언어 |
| **기본 모델** | haiku / sonnet / opus | AI 모델 선택 |
| **사용자 정보** | 이름, 이메일 | 선택 사항 |

## Configuration File

```ini
# .claude/config/user.conf
WORK_MODE=solo
PRD_LANGUAGE=ko
DEFAULT_MODEL=sonnet
USER_NAME="Your Name"
USER_EMAIL="your@email.com"
```

## First Run

```bash
$ /init

🎉 Claude Code 초기 설정

이 설정은 한 번만 진행됩니다.

1. 작업 환경
  1) Solo - 혼자 작업
  2) Team - 팀과 함께
선택 (1-2, Enter=1): 1

2. PRD 언어
  1) 한국어 (ko)
  2) English (en)
  3) 中文 (zh)
  4) 日本語 (ja)
선택 (1-4, Enter=1): 1

...
✅ 설정 완료!
```

## Related Commands

- `/prd` - 설정된 언어로 PRD 생성
- `/mode solo` - Solo 모드로 변경
- `/mode team` - Team 모드로 변경
