---
name: brain-web
description: Brain(뉴런·시냅스)·Memory(의미검색)·작업 히스토리를 로컬 웹에서 시각적으로 본다. 기억 노드를 force-directed 그래프로 그려 유기성(연결)을 보여주고, 노드 클릭 시 내용·태그·감정가중치를 패널에 표시하며, type별 필터·검색·타임라인을 제공한다. "기억 시각화", "brain 그래프 보여줘", "내 기억 어떻게 연결됐어" 등에서 동작.
---

# brain-web — 기억 시각화 로컬 웹

Brain/Memory에 쌓인 기억과 그 **유기성(연결 그래프)**을 브라우저에서 본다.
빌드 도구 없음. 셸이 데이터를 스캔해 JSON 1장을 만들고, 단일 HTML이 그린다.

## 실행

```bash
bash ~/.claude/skills/brain-web/serve.sh        # 스캔 → 서버 → 브라우저 자동 오픈 (포트 8077)
bash ~/.claude/skills/brain-web/serve.sh 9000   # 포트 지정
```

데이터만 새로 만들고 싶으면:
```bash
python3 ~/.claude/skills/brain-web/scan.py
```

## 구성 (3파일, 의존성 0)

| 파일 | 역할 |
|------|------|
| `scan.py` | `~/.claude/brain/`(뉴런·시냅스), `~/.claude/projects/*/memory/`(의미검색)를 훑어 `data.json` 생성. 표준 라이브러리만. |
| `index.html` | vis-network(CDN)로 force-directed 그래프. 노드 클릭 패널 + 종류/엣지 필터 + 검색 + 타임라인. |
| `serve.sh` | 스캔 → `python -m http.server` → 브라우저 오픈. |

## 시각화하는 것

- **노드** — 뉴런(🔵 dot, 카테고리별)·기억(🟠 diamond, type별). 크기 = 감정가중치.
- **엣지(유기성)** — 시냅스(brain/synapses), 기억 링크(memory 본문 `[[name]]`), 뉴런 links.
- **패널** — 노드 클릭 시 제목·type·프로젝트·태그·감정가중치·본문 미리보기.
- **타임라인** — Brain 프로젝트 작업내역 날짜순.
- **필터/검색** — 종류·엣지별 on/off, 라벨·태그·설명 검색.

## 동작 원리 메모

- Brain 데이터는 평문 md/json(암호화 아님)이라 직접 파싱한다.
- dangling 엣지(노드 없는 연결)는 scan.py가 제거한다.
- `file://`로 직접 열면 CORS로 data.json fetch가 막히니 **반드시 http 서버로** 띄운다(serve.sh가 처리).

## 한계 (정직하게)

- 현재 memory 그래프와 brain 그래프는 **별개 군집**이다(서로 잇는 엣지 규칙 없음). 교차 연결은 다음 단계.
- 타임라인은 Brain 프로젝트 md의 "마지막 업데이트"만 읽는다. git/뉴런 created 통합은 추후.
</content>
