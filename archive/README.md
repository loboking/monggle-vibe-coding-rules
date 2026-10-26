# archive — 보관된 스킬·스크립트

2026-10-26 스킬 축소(`prd/refactor-20261026-skill-consolidation.md`)로 옮긴 것들이다. **지운 게 아니다.**

- `skills/` 내장 기능과 겹치거나(review·init·stats …), 쓰인 기록이 없거나, 동작하지 않던 스킬
- `bin/` 보관 스킬 전용 스크립트(msg·wrapper·team-run …)
- `lib/conflict_helper.sh`, `tests/` git 에 커밋되지 않은 채 사라진 협업 스크립트(git_helper·pr_helper·update)를 전제로 한 테스트
- `update` 루트 바로가기(없는 파일을 가리키던 것)

흡수된 스킬의 절차는 `skills/<입구>/references/` 로 갔다(impact → fix, prd → spec 등).

복구: `git mv archive/skills/<이름> skills/<이름>` 후 `./install.sh`.
관찰 기간(2026-11-09까지)이 끝나면 사용자가 삭제 여부를 정한다.
