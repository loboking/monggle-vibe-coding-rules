All claims fully verified against live code and data. Confirmed: the global `~/.claude/brain/brain-core.sh` uses a completely different format (`short_<epoch>_<hex>.json`, separate `.json` files, hippocampus/cortex dirs) versus the project version (`paste -sd ','` bug at lines 197/285, central `index.json`), and `brain.sh` sources the project version. SessionStart hooks confirmed NOT registered (only detect-project, docs-on-session-start, update-claude-md). Now writing the report.

# Brain 시스템 vs 하네스 — 시스템 분석 리포트

> 작성: 시스템 분석 책임자 | 근거: 실제 코드 + 런타임 데이터 직접 실행 검증
> 핵심 진단: **둘 다 "쓰기는 되는데 읽기/피드백이 닫히지 않은" 반쪽 시스템.** Brain 은 검색이 완전 고장, Harness 는 분석 루프가 단절.

---

## 1. 한눈에 보기

| 시스템 | 한 줄 정의 | 작동 수준 |
|--------|-----------|----------|
| **Brain** | 생체모방(neuron/synapse/감정/망각) 구조의 **장기 지식 기억** 시스템 | 🟡 **partial → 사실상 broken** (쓰기 O, 핵심 검색 X) |
| **Harness** | 스킬 실행을 추적하는 **self-improvement / observability** 도구 | 🟡 **partial** (쓰기 O, 분석 피드백 루프 X) |

한 줄 요약: **Brain 은 "기억은 적는데 못 꺼내고", Harness 는 "기록은 쌓는데 분석기가 다른 폴더를 본다."**

---

## 2. Brain 은 실제로 어떻게 작동하는가

`brain-core.sh`(프로젝트판)는 SPEC 의 **일부만** 실동작하는 부분 구현이다. 영역별 실태:

| 영역 | SPEC 의도 | 실제 구현 상태 | 근거 |
|------|----------|---------------|------|
| **neurons** | 장기기억 단위 (.md + frontmatter) | ✅ **실동작** — 파일 생성·인덱스 등록 | 런타임에 뉴런 3개 존재 (decision×2, conversation×1) |
| **synapses** | 뉴런 간 가중 연결 | 🟡 **수동만** — `brain_create_synapse` 직접 호출 시만 생성. 자동연결(`link_to_related`) **미구현** | 런타임 `index.json`의 `.synapses` = `{}` (0개) |
| **amygdala** | 감정가중치 | ✅ **실동작** — `emotional_weights.json` 정적 5단계 매핑 부여 | decision 뉴런 `emotional_weight: 0.7` 확인 |
| **hippocampus** | 단기 세션기억 | ✅ **실동작** — 세션 파일 append | — |
| **cortex** | 핫캐시 | ❌ **stub** — `init` 시 placeholder 1회 생성만, 갱신 로직 전무 | 코드에 접근빈도 갱신 없음 |
| **망각곡선** | retention 감쇠 | ✅ **실동작** — `brain_calc_retention`(bc 기반) 계산됨 | — |
| **prediction error / dopamine / 간격반복** | 학습 메커니즘 | ❌ **전혀 미구현** — `prediction_error`는 항상 `0.0` 박제 | SPEC 에만 존재 |

**컨셉뿐인 것:** 시냅스 자동연결, consolidation 중요도 분석(`brain_consolidate_session`은 `# TODO` 주석만, 세션 통째 덤프), cortex 핫캐시, 예측오류 학습, 간격반복 — 전부 **SPEC.md 에만 있고 코드 없음.**

---

## 3. Harness 는 무엇을 하는가

`harness-tracker.sh`가 스킬 실행을 추적한다. `skill-harness-wrapper.sh`를 source 한 스킬(**debug/fix/lint-smart/smart-qa/format-check/review = 6개만**)이 `trap EXIT`로 종료 시 자동 기록.

측정 메트릭 (**실제 데이터 쌓이는 중**):
- **에이전트 성공률** — debug 14회(성공13/실패1), smart-qa-read 7회, format-check 5회, lint-smart 5회 등 라이브 누적 (`last_run: 2026-06-16`)
- **doom-loop 탐지** — 파일 수정 횟수 임계 5회
- **change-size 경고** — >10파일 또는 >200라인 시 경고
- **guide/sensor 4분면 분류** — 정의는 됨, **카운트는 전부 0 (죽은 코드)**
- **improvement 분석** — `auto_improvement.py`가 로그를 읽어 `improvement-suggestions.json` 생성

---

## 4. Brain vs Harness 비교표

| 축 | **Brain** | **Harness** |
|----|-----------|-------------|
| **목적** | 사람이 만든 **지식**(결정/패턴/버그/컨텍스트) 기억 | 스킬 **실행 관측** + 자기개선 |
| **대상** | 뉴런(.md) + 시냅스 + 감정가중 | 메트릭(성공/실패/duration/diff크기) |
| **저장** | `~/.claude/brain` (.md + `synapses/index.json` + jq) | `~/.claude/.harness` (JSON/JSONL + jq) |
| **수명** | 고착(consolidation) ↔ 망각(forgetting) | per-run (track_start → track_end) |
| **통합** | wrapper 미경유. debug/test 2개 스킬만 `brain-core` 직접 source | wrapper 경유 6개 스킬 계측 |

→ **가설("Brain=장기기억, Harness=실행추적") 은 코드와 일치.** 다만 두 시스템의 통합은 컨셉이 그리는 것보다 훨씬 느슨하다 (wrapper 는 brain 을 source 하지 않음).

---

## 5. 🔴 왜 지금 잘 안 되는가 — 구체적 원인

### Brain 쪽 (치명)

1. **태그 검색 완전 무력화 — `paste -sd ','` BSD/macOS 버그** (`brain-core.sh:197, 285`)
   직접 실행 검증:
   ```
   $ echo "auth,login" | tr ',' '\n' | sed ... | paste -sd ','
   usage: paste [-s] [-d delimiters] file ...   # exit=1, 출력 없음
   ```
   파일 인자가 없어 실패 → `tags_json`이 항상 `[]`. 결과:
   - (a) **인덱스의 모든 뉴런 tags = `[]`** — 런타임 `index.json`의 뉴런 3개 전부 `"tags": []` 확인 (.md frontmatter 엔 태그 있으나 인덱스 불일치)
   - (b) 검색 태그도 `[]` → jq `[] | inside($t)`는 **항상 true** → **어떤 태그로 검색해도 전체 뉴런 무차별 반환.** 존재하지 않는 `login` 태그에도 전부 출력
   - 수정안: `paste -sd ',' -` (stdin 명시). 검증: `-` 추가 시 정상 `"auth","login"` 출력

2. **시냅스 0개** — 자동연결 미구현 + 사용자가 `/brain link`를 한 번도 호출 안 함. 격리 테스트에선 `brain_create_synapse` 직접 호출 시 정상 생성됨 → **코드 버그가 아니라 빈 데이터.** 단 자동연결이 없어 수동 link 없인 영원히 0

3. **자동 수명주기 훅 미등록** — `brain-session-start.sh`/`brain-session-end.sh`(컨텍스트 로드·고착화·망각)가 `~/.claude/settings.json`에 **등록 안 됨.** 등록된 SessionStart 는 `detect-project.sh`, `docs-on-session-start.sh`뿐. → **망각곡선·고착화·자동 회상이 한 번도 자동 발화하지 않음**

4. **split-brain — 3개의 무관한 `/brain`**
   - `~/.claude/skills/brain/skill.sh` (실제 등록 스킬): brain-core 미사용, 프로젝트명.md 에 메모하는 단순 노트
   - `~/.claude/commands/brain.sh`: 생체모방 brain-core source (단, **프로젝트판** `monggle-vibe-coding-rules/.claude/brain/brain-core.sh`를 BRAIN_ROOT 로 가리킴)
   - `~/.claude/commands/brain.md`: 또 다른 short/long/promote 설계
   - 추가로 글로벌 `~/.claude/brain/brain-core.sh`(19KB)는 **포맷 비호환 재작성본**(`short_<epoch>_<hex>.json`, 개별 .json 시냅스, index 없음). 디스크 실데이터는 구형 `.md + index.json`뿐 → 이 재작성본은 **한 번도 실행된 적 없음**

5. **디렉토리 단/복수 불일치** — `init`은 복수형(`decisions/`, `bugs/`) 생성, `create_neuron`은 단수형(`decision/`)에 저장. 런타임에 빈 복수형과 채워진 단수형 공존 확인. **ID 초단위 충돌**(같은 초+같은 type → 무경고 덮어쓰기)도 존재

### Harness 쪽 (피드백 단절)

6. **분석기 경로 불일치 — 자기개선 루프 단절**
   tracker 는 `~/.claude/.harness`에 쓰는데 `auto_improvement.py:50-52`는 `PROJECT_ROOT/.harness`를 읽음. → 실제 누적 데이터(21객체)와 분석 대상이 **다른 폴더.** 결과: `improvement-suggestions.json`은 `suggestions: [], count: 0` (2026-04-09 stale)

7. **JSONL 규약 위반 — pretty-print**
   `harness_log_*`가 `jq -n`(컴팩트 `-c` 미사용)로 append → 객체 하나가 여러 줄. `improvement-log.jsonl`은 **물리 161줄 = 실제 21객체.** `wc -l` 기반 통계(=161)와 `jq -s`(=21)가 같은 화면에서 모순

8. **change 경고 무한 중복** — `git diff HEAD` 누적 기준이라 커밋 전까지 동일 `6 files, 299 lines`가 매 실행 재로깅 (동일 observation 13회 중복). dedup 없음

9. **avg_duration 항상 0** — start/end 모두 초단위 `date +%s`, 스킬이 1초 미만 종료 → 성능 추세 무의미

10. **guide/sensor 분류 = 죽은 코드** — `harness_get_classification` 정의만 되고 **어디서도 호출 안 됨.** `guide-sensor-stats.json` 전부 0 확인

---

## 6. Brain 의 독자적 우위 — 실재 vs 컨셉

Claude Code 내장 memory(`CLAUDE.md`)와 비교:

| 항목 | 내장 memory | Brain 컨셉 | Brain **현실** |
|------|------------|-----------|---------------|
| 컨텍스트 자동 주입 | ✅ 항상 | 훅으로 회상 | ❌ 훅 미등록 → 자동 발화 안 함 |
| 태그/연결 기반 구조화 검색 | ❌ (평문) | ✅ 시냅스 그래프 | ❌ paste 버그로 무차별 반환 |
| 감정가중 우선순위 | ❌ | ✅ amygdala | 🟡 부여는 됨, 검색에 미활용 |
| 망각/고착 자동화 | ❌ | ✅ 망각곡선 | 🟡 계산함수 O, 자동발화 X |

**실재하는 우위:** 감정가중치 부여, 망각곡선 retention 계산, 수동 시냅스 생성·강화(weight clamp), 타입/감정 분포 통계, GNU/BSD date 호환 — 이건 실제 동작 검증됨.

**컨셉뿐인 우위:** 시냅스 그래프 검색, 예측오류 학습, 간격반복, 핫캐시, 자동 회상 — **데이터상 빈 껍데기**(시냅스 0, 태그 0, 자동훅 0).

→ **현 코드 상태에서 Brain 이 내장 memory 보다 나은 점은 사실상 실재하지 않는다.** 개념상 우위는 명확하나 구현이 핵심 경로에서 동작하지 않음.

---

## 7. 한 줄 결론 + 권고

**결론:** 둘 다 설계는 정합적이고 쓰기 경로는 살아있으나, **읽기/피드백 경로가 끊겨 "관측은 되는데 활용이 안 되는" 상태.** Brain 은 1줄 버그로 핵심이 죽었고, Harness 는 경로 분기로 루프가 닫히지 않았다.

**고치면 쓸만한가? — Yes (특히 Harness).** 치명적 결함이 대부분 **소규모 픽스**다.

**우선순위 권고 (변경은 하지 않음, 진단만):**

| 우선 | 대상 | 픽스 | 효과 |
|------|------|------|------|
| 🔴 P0 | Brain | `paste -sd ','` → `paste -sd ',' -` (197, 285행) | 태그 검색 부활 — 단 1자 |
| 🔴 P0 | Harness | `auto_improvement.py` HARNESS_DIR 를 `~/.claude/.harness`로 통일 | 자기개선 루프 연결 |
| 🟠 P1 | Brain | SessionStart/End 훅을 settings.json 에 등록 | 자동 회상·망각·고착 발화 |
| 🟠 P1 | Brain | `/brain` 3중 구현 정리 — 정본 1개 선택 | split-brain 해소 |
| 🟡 P2 | Harness | `jq -c` 적용 + change 경고 dedup | JSONL 정합·노이즈 제거 |
| 🟡 P2 | Brain | 디렉토리 단/복수 통일 + ID 충돌 방지(밀리초/카운터) | 데이터 무음손실 방지 |
| ⚪ P3 | Harness | avg_duration 밀리초화, guide/sensor 분류 연결 | 메트릭 의미 확보 |

**핵심 메시지: Brain 의 사망 원인은 `paste` 한 줄, Harness 의 부진 원인은 폴더 경로 한 줄.** 둘 다 컨셉 폐기가 아니라 배선 수리가 답이다. 다만 Brain 의 학습 메커니즘(예측오류/간격반복/시냅스 자동연결/핫캐시)은 코드가 아예 없으므로, "고친다"는 버그 수정과 **신규 구현**이 섞여 있음을 인지해야 한다.