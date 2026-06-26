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

모드 설정은 프로젝트 루트의 `monggle.config.yaml`에 저장됩니다 (git 추적 → 팀 공유):

```yaml
mode: team
prd_required: true   # team이면 자동 true
```

### Team 모드의 실제 강제 (PRD Gate)

`team` 모드에서는 **PRD 없이 코드 파일(Write/Edit)을 만들 수 없습니다.**
`prd-gate.sh`(PreToolUse 훅)가 이를 강제합니다:

- `prd/`에 유효한 PRD(요구사항·수용기준 섹션 포함)가 없으면 코드 Write/Edit를 **차단**
- 예외(통과): `.md` 문서, `prd/`·`docs/`·`.claude/` 경로, 설정/JSON/YAML
- 우회: `/quick`(핫픽스), `BRAIN_PRD_GATE=off`(이번만), `/mode solo`(전환)

> `solo` 모드는 게이트가 비활성 — 자유롭게 작업.

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
