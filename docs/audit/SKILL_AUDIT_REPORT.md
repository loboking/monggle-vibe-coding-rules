# 스킬 정리 진단 리포트

> 작성일: 2026-06-16
> 대상: `.claude/commands/` 공식 스킬 71개 (실행 .sh 56 + 에이전트 .md 15)
> ⚠️ **이 리포트는 진단 전용입니다. 실제 삭제·통합은 하지 않았습니다.**

---

## 요약

| 구분 | 개수 | 비고 |
|------|------|------|
| 전체 스킬 | 71 | 실행 56 + 에이전트 15 |
| ✅ 유지 (고유 역할) | ~52 | 그대로 둠 |
| 🟡 통합 후보 | 14 | 역할 겹침 → 대표로 합치기 가능 |
| 🔵 별칭(정상) | 5 | monggle-* 심볼릭 링크 |

정리 시 **71 → 약 57개**로 축소 가능 (약 20% 감소).

---

## 🟡 통합 후보 (역할이 겹치는 그룹)

### 1. 기획/PRD — 3중복 → 2개로
| 스킬 | 역할 | 권고 |
|------|------|------|
| `prd.sh` | PRD 생성 (실행) | ✅ 유지 (실행 진입점) |
| `product-manager.md` | PRD·스토리·로드맵 (에이전트) | ✅ 유지 (전문 에이전트) |
| `planner.md` (=`monggle-planner`) | 기획서·요구사항 (에이전트) | 🟡 `product-manager`와 거의 동일 → **통합** |

**근거:** `planner`와 `product-manager` 설명이 사실상 같은 영역(기획/요구사항). `prd`는 실행 스크립트라 별개로 유지.

---

### 2. 문서 작성 에이전트 — 2중복 → 1개로
| 스킬 | 역할 | 권고 |
|------|------|------|
| `tech-doc-writer.md` | README·API·가이드·아키텍처 | ✅ 유지 (더 포괄적) |
| `doc-writer.md` | README·API·guides | 🟡 `tech-doc-writer`의 부분집합 → **통합** |

**근거:** `doc-writer`가 다루는 범위를 `tech-doc-writer`가 모두 포함.

---

### 3. 디버깅 에이전트 — 2중복 → 1개로
| 스킬 | 역할 | 권고 |
|------|------|------|
| `debug.sh` | 통합 디버깅 (실행) | ✅ 유지 (실행 진입점) |
| `debug-master.md` | 체계적 버그 분석 (과학적 방법론) | ✅ 유지 (대표 에이전트) |
| `precision-debugger.md` | 정밀 디버깅 (재현 어려운 버그) | 🟡 `debug-master`와 역할 중첩 → **통합 검토** |

**근거:** 두 에이전트 모두 "복잡한 버그 심층 분석". 미묘한 차이(방법론 vs 정밀)는 있으나 사용자 입장에선 구분이 모호.

---

### 4. 아이디어 발굴 — 2중복 → 1개로
| 스킬 | 역할 | 권고 |
|------|------|------|
| `idea.sh` | 아이디어 정리·요구사항 수집 | 🟡 `brainstorm`과 **설명·코드 거의 동일** |
| `brainstorm.sh` | 아이디어 정리·요구사항 수집 | ✅ 유지 (대표) |

**근거:** 헤더 설명이 글자까지 동일("아이디어 정리 및 요구사항 수집"). 버그 헌팅 때도 두 파일이 같은 코드 구조로 확인됨(같은 버그가 양쪽에 존재). **사실상 한 스킬의 복제.**

---

### 5. QA — 3개 → 2개로
| 스킬 | 역할 | 권고 |
|------|------|------|
| `smart-qa.sh` | QA 실행 (fix 포함) | ✅ 유지 |
| `smart-qa-read.sh` | QA 결과 읽기 (report only) | ✅ 유지 (읽기 전용 분리) |
| `test.sh` | QA 러너 (smart-qa로 위임) | 🟡 `smart-qa`로 exec하는 **래퍼** → 별칭화 검토 |

**근거:** `test.sh`는 자체 로직 없이 `smart-qa.sh`/`smart-qa-read.sh`를 호출하는 얇은 래퍼.

---

### 6. 코드 리뷰 — 중복 점검 필요
| 스킬 | 역할 | 권고 |
|------|------|------|
| `review.sh` | AI 코드 리뷰 (실행, read-only) | ✅ 유지 |
| `code-reviewer.md` | 코드 리뷰 SOLID/보안/성능 (에이전트) | ✅ 유지 (에이전트) |
| `arch-review.sh` + `arch-review.md` | 아키텍처 리뷰 | ✅ 유지 (별도 영역) |

**근거:** review(코드 품질) vs arch-review(구조)는 영역이 다름. 통합 불필요. 단 `code-reviewer`(에이전트)와 `review`(실행)는 역할 보완 관계라 유지.

---

## 🔵 별칭 (정상 — 건드리지 말 것)

monggle- 접두사는 모두 **심볼릭 링크**라 원본과 동일하게 동작:

| 별칭 | → 원본 |
|------|--------|
| `monggle-planner` | `planner` |
| `monggle-init` | `project-init` |
| `monggle-brain` | `smart-brain` |
| `monggle-super` | `super` |
| `monggle-gemini` | `gemini` |

> 단, `planner` 자체를 통합하면 `monggle-planner` 링크도 함께 정리해야 함.

---

## ✅ 유지 권고 (고유 역할, 통합 불필요)

- **분석/성능:** `bottleneck` `profile` `bench` `complexity` `mem-check` `impact` `trace`
- **보안/품질:** `audit` `security` `lint-smart` `format-check`
- **문서 관리:** `docs-index` `docs-search` `docs-status` `api-docs` `readme-sync` `changelog` `weekly-recap`
- **Git/배포:** `push-safe` `bump` `quick` `fix`
- **파이프라인/팀:** `pipeline` `team` `team-run` `team-status` `mode` `gate` `stats`
- **상태/시스템:** `save-point` `handover` `harness` `brain` `auto-compact`
- **설치/유틸:** `init` `update` `monggle` `monggle-upgrade` `rule-upgrade` `help` `new` `msg` `cleanup-zombies` `setup-gemini` `wrapper` `verify`
- **전문 에이전트:** `architecture-designer` `frontend-designer` `git-guardian` `judge` `super` `gemini` `smart-brain`

---

## 권고 정리안 (실행 시)

| 통합 | 사라질 스킬 | 남길 스킬 |
|------|------------|----------|
| 기획 | `planner` (+`monggle-planner`) | `product-manager`, `prd` |
| 문서작성 | `doc-writer` | `tech-doc-writer` |
| 디버깅 | `precision-debugger` | `debug-master`, `debug` |
| 아이디어 | `idea` | `brainstorm` |
| QA 래퍼 | `test` (별칭화) | `smart-qa`, `smart-qa-read` |

**예상 결과:** 71 → 약 57개

---

## 주의사항

1. **`idea` 통합 시:** 사용자가 `/idea`를 자주 쓴다면 별칭으로 남기는 것이 안전. (이번 정책은 "완전 제거"지만, idea는 사용 빈도 확인 권장)
2. **에이전트 통합(`precision-debugger`, `doc-writer`, `planner`):** CLAUDE.md / intent-routing.md 에 해당 스킬 참조가 있으면 함께 수정 필요.
3. **삭제 전 백업 필수** + git 커밋으로 이력 보존.
