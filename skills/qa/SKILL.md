---
name: qa
description: 만든 것이 실제로 동작하는지 확인할 때 쓴다. 프로젝트 종류(Android·iOS·Web·서버)를 자동으로 알아내 테스트·문법·린트·포맷·보안 점검을 돌리고 결과를 보고한다(요청하면 고친다). "작동해?", "테스트 돌려", "점검해줘", "머지 전 확인", "보안 점검", "린트", "보고서만" 등.
allowed-tools: Bash, Read, Edit, Write, Grep, Glob
---

# qa

참고 파일 위치: 저장소 안이면 `skills/qa/references/`, 아니면 `~/.monggle/skills/qa/references/`.

## 1. 기본 실행
```bash
SCRIPT=bin/smart-qa.sh
[ -f "$SCRIPT" ] || SCRIPT="$HOME/.monggle/bin/smart-qa.sh"
bash "$SCRIPT"   # 사용자가 준 인자를 그대로 덧붙인다
```
- 프로젝트 자동 판별: `build.gradle*`·`AndroidManifest.xml` → Android, `*.xcodeproj`·`Podfile` → iOS, `package.json` → Web, `requirements.txt`·`go.mod`·`pom.xml` → 서버
- 옵션: `--android --ios --web --mobile --server --code`, `--report`(수정 없이 보고만), `--quick`(스모크), `--format json|text|markdown`
- 프로젝트 자체 테스트 명령이 있으면 그것을 먼저 돌린다. 스크립트 결과보다 실제 테스트 결과가 우선이다.

## 2. 목적별 절차 (해당할 때만 읽는다)
| 목적 | 참고 파일 |
|---|---|
| 테스트 실행·자동 수정 상세 | `references/code-qa.md`, `references/test.md` |
| 보안 취약점·비밀값 | `references/security.md`, `references/audit.md` |
| 린트·포맷 | `references/lint-smart.md`, `references/format-check.md` |
| 구현 간 속도 비교 | `references/bench.md` |

## 3. 보고서 (생략 금지)
테스트 결과는 보고서로 남긴다. 판단 문구(✅ 진행 / ⚠️ 판단 필요 / ❌ 보류)는 스크립트가 정한다.
```bash
SCRIPT=bin/test-report.sh
[ -f "$SCRIPT" ] || SCRIPT="$HOME/.monggle/bin/test-report.sh"
bash "$SCRIPT" --kind qa [--note <메모 파일>]   # 테스트 명령을 직접 주려면: -- <명령>
```
- 린트·보안 점검 결과가 있으면 메모에 쉬운 말로 넣는다: `- 린트: 경고 3건(src/a.ts) — 동작엔 영향 없음`
- 스크립트의 결론 한 줄과 다음 할 일을 전하고 **"보고서를 열어볼까요?"** 라고 묻는다. 보겠다고 하면 `bash "$SCRIPT" --open-last --kind qa`.
- `--report` 나 "수정하지 마"면 코드를 바꾸지 않는다.
