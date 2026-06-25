#!/usr/bin/env python3
"""brain-web scan — Brain/Memory/작업히스토리를 훑어 단일 JSON으로 묶는다.
의존성 0 (표준 라이브러리만). 결과: data.json (HTML이 fetch).

노드 종류:
  - neuron   : ~/.claude/brain/neurons/<cat>/*.md  (frontmatter id/type/tags/links/emotional_weight)
  - memory   : ~/.claude/projects/<proj>/memory/*.md (frontmatter name/description/metadata.type, 본문 [[링크]])
엣지:
  - synapse  : ~/.claude/brain/synapses/index.json (source/target/weight)
  - mem_link : memory 본문의 [[name]] → 같은 name 노드
타임라인:
  - brain/<project>.md, neuron created 날짜
"""
import json, os, re, glob, sys
from pathlib import Path

HOME = Path.home()
BRAIN = HOME / ".claude" / "brain"
PROJECTS = HOME / ".claude" / "projects"

def proj_name(raw):
    """경로 인코딩된 프로젝트 키 → 읽는 이름 (JS projName과 동일 규칙)."""
    if not raw:
        return ""
    s = str(raw).lstrip("-")
    for pat in (r"^Users-[^-]+-AndroidStudioProjects-", r"^Users-[^-]+-Documents-",
                r"^Users-[^-]+-", r"^Volumes-.*-Media-", r"^Volumes-[^-]+-",
                r"^private-tmp-", r"^tmp-"):
        if re.match(pat, s):
            s = re.sub(pat, "", s)
            break
    return s or raw

def parse_frontmatter(text):
    """--- ... --- 블록을 얕게 파싱. 값은 문자열/리스트만 다룸."""
    fm, body = {}, text
    if text.startswith("---"):
        # 종료 구분자는 '줄 전체가 ---' 인 곳. 본문 수평선(---)에 오탐하지 않게.
        end = text.find("\n---\n", 3)
        if end == -1 and text.rstrip().endswith("\n---"):
            end = text.rstrip().rfind("\n---")
        if end != -1:
            raw = text[3:end].strip("\n")
            body = text[end+4:].lstrip("\n")
            cur_key = None
            for line in raw.split("\n"):
                if not line.strip():
                    continue
                m = re.match(r"^(\w[\w-]*):\s*(.*)$", line)
                if m and not line.startswith(" "):
                    k, v = m.group(1), m.group(2).strip()
                    cur_key = k
                    if v.startswith("[") and v.endswith("]"):
                        items = [x.strip().strip('"\'') for x in v[1:-1].split(",") if x.strip()]
                        fm[k] = items
                    elif v:
                        fm[k] = v.strip('"\'')
                    else:
                        fm[k] = {}
                elif line.startswith(" ") and cur_key:
                    # 블록 시퀀스(  - item) → 리스트
                    seq = re.match(r"^\s+-\s+(.*)$", line)
                    if seq:
                        if not isinstance(fm.get(cur_key), list):
                            fm[cur_key] = []  # 빈 {} 였으면 list로 전환
                        fm[cur_key].append(seq.group(1).strip().strip('"\''))
                    else:
                        # 중첩 매핑(  key: val) → dict
                        mm = re.match(r"^\s+(\w[\w-]*):\s*(.*)$", line)
                        if mm:
                            if not isinstance(fm.get(cur_key), dict):
                                fm[cur_key] = {}
                            fm[cur_key][mm.group(1)] = mm.group(2).strip().strip('"\'')
    return fm, body

def short(s, n=160):
    s = re.sub(r"\s+", " ", s).strip()
    return s[:n] + ("…" if len(s) > n else "")

def scan_neurons():
    nodes, edges = [], []
    for path in glob.glob(str(BRAIN / "neurons" / "*" / "*.md")):
        try:
            text = Path(path).read_text(encoding="utf-8", errors="replace")
        except Exception:
            continue
        fm, body = parse_frontmatter(text)
        nid = fm.get("id") or Path(path).stem
        title = ""
        for line in body.split("\n"):
            if line.startswith("# "):
                title = line[2:].strip(); break
        cat = Path(path).parent.name
        try:
            ew = float(fm.get("emotional_weight", 0.5))
        except (ValueError, TypeError):
            ew = 0.5
        nodes.append({
            "id": nid, "kind": "neuron", "category": cat,
            "type": fm.get("type", cat),
            "label": short(title or nid, 40),
            "tags": fm.get("tags", []) if isinstance(fm.get("tags"), list) else [],
            "emotional_weight": ew,
            "created": fm.get("created", ""),
            "last_accessed": fm.get("last_accessed", fm.get("created", "")),
            "access_count": fm.get("access_count", "0"),
            "body": short(body, 400),
        })
        links = fm.get("links", [])
        if isinstance(links, list):
            for tgt in links:
                if tgt:
                    edges.append({"source": nid, "target": tgt, "kind": "link", "weight": 0.5})
    return nodes, edges

def scan_synapses():
    edges = []
    p = BRAIN / "synapses" / "index.json"
    if not p.exists():
        return edges
    try:
        data = json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        return edges
    # 형식 방어: {synapses:{...}} / {synapses:[...]} / 최상위 dict / 최상위 list 모두 수용
    if isinstance(data, dict):
        syn = data.get("synapses", data)
    else:
        syn = data
    items = syn.values() if isinstance(syn, dict) else (syn if isinstance(syn, list) else [])
    for v in items:
        if isinstance(v, dict) and v.get("source") and v.get("target"):
            try:
                w = float(v.get("weight", 0.5))
            except (ValueError, TypeError):
                w = 0.5
            edges.append({
                "source": v["source"], "target": v["target"], "kind": "synapse",
                "weight": w, "activation_count": v.get("activation_count", 0),
            })
    return edges

def scan_memory(proj_filter=None):
    nodes, edges = [], []
    for proj_dir in glob.glob(str(PROJECTS / "*" / "memory")):
        proj = Path(proj_dir).parent.name
        for path in glob.glob(os.path.join(proj_dir, "*.md")):
            base = Path(path).stem
            if base == "MEMORY":
                continue
            try:
                text = Path(path).read_text(encoding="utf-8", errors="replace")
            except Exception:
                continue
            fm, body = parse_frontmatter(text)
            name = fm.get("name", base)
            meta = fm.get("metadata", {}) if isinstance(fm.get("metadata"), dict) else {}
            nid = "mem:" + name
            nodes.append({
                "id": nid, "kind": "memory", "category": meta.get("type", "memory"),
                "type": meta.get("type", "memory"),
                "label": short(name, 40),
                "tags": [], "emotional_weight": 0.6,
                "created": "", "access_count": "0",
                "project": proj,
                "description": fm.get("description", ""),
                "body": short(body, 400),
            })
            for tgt in re.findall(r"\[\[([^\]]+)\]\]", body):
                edges.append({"source": nid, "target": "mem:" + tgt.strip(),
                              "kind": "mem_link", "weight": 0.7})
    return nodes, edges

def scan_timeline():
    items = []
    for path in glob.glob(str(BRAIN / "*.md")):
        name = Path(path).stem
        try:
            text = Path(path).read_text(encoding="utf-8", errors="replace")
        except Exception:
            continue
        m = re.search(r"마지막 업데이트\**:?\s*([\d-]+)", text)
        safe = re.sub(r'[<>&"\']', '', name)  # 파일명에 HTML 특수문자 들어가도 방어
        items.append({"date": m.group(1) if m else "", "label": safe + " 작업내역",
                      "kind": "project_log"})
    return sorted(items, key=lambda x: x["date"], reverse=True)

def _parse_iso(s):
    """ISO8601(Z) → datetime. 실패 시 None."""
    if not s:
        return None
    try:
        from datetime import datetime
        return datetime.strptime(str(s)[:19], "%Y-%m-%dT%H:%M:%S")
    except (ValueError, TypeError):
        return None

def apply_retention(nodes, now):
    """에빙하우스 망각곡선: R = exp(-Δt_days / S).
    S(기억 강도) = base + access_count*가중 + emotional_weight*가중. 자주/강하게 본 기억일수록 천천히 잊힘."""
    import math
    for n in nodes:
        last = _parse_iso(n.get("last_accessed") or n.get("created"))
        if not last:
            n["retention"] = None
            n["days_since"] = None
            continue
        dt_days = max(0.0, (now - last).total_seconds() / 86400.0)
        try:
            ac = float(n.get("access_count", 0))
        except (ValueError, TypeError):
            ac = 0
        ew = float(n.get("emotional_weight", 0.5) or 0.5)
        S = 2.0 + ac * 3.0 + ew * 5.0          # 강도(일 단위). 기본 2일, 접근·감정에 비례
        n["retention"] = round(math.exp(-dt_days / S), 4)
        n["days_since"] = round(dt_days, 1)
        n["strength"] = round(S, 1)

def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else (Path(__file__).parent / "data.json")
    n_nodes, n_edges = scan_neurons()
    m_nodes, m_edges = scan_memory()
    s_edges = scan_synapses()
    nodes = n_nodes + m_nodes

    # ---- 프로젝트 정규화 + 뉴런 프로젝트 추출 ----
    # memory 노드: project 경로 → 읽는 이름. 동시에 "알려진 프로젝트" 사전 구축.
    known = set()
    for n in m_nodes:
        if n.get("project"):
            pn = proj_name(n["project"])
            n["project_path"] = n["project"]   # 전체 경로 보존(위치 버튼용)
            n["project"] = pn
            known.add(pn)
    # 뉴런 노드: tags 중 "알려진 프로젝트명"과 일치하면 그 프로젝트로. (오추정 방지 — 매칭만 신뢰)
    #  + tags에 'project' 다음에 오는 토큰이 프로젝트명인 brain 관습도 보조로 사용.
    for n in n_nodes:
        tags = n.get("tags", []) or []
        pn = next((t for t in tags if t in known), None)
        if not pn and "project" in tags:
            idx = tags.index("project")
            if idx + 1 < len(tags):
                cand = tags[idx + 1]
                if cand not in ("change","decision","context","todo"):
                    pn = cand
        if pn:
            n["project"] = pn
            known.add(pn)

    # 망각곡선: 스캔 시점 기준 retention 계산 (시간 의존이므로 여기서 고정)
    from datetime import datetime, timezone
    apply_retention(nodes, datetime.now(timezone.utc).replace(tzinfo=None))
    ids = {n["id"] for n in nodes}
    # 존재하는 노드 사이의 엣지만 (dangling 제거)
    all_edges = [e for e in (n_edges + s_edges + m_edges) if e["source"] in ids and e["target"] in ids]
    payload = {
        "nodes": nodes,
        "edges": all_edges,
        "timeline": scan_timeline(),
        "stats": {
            "neurons": len(n_nodes), "memories": len(m_nodes),
            "synapses": len([e for e in all_edges if e["kind"] == "synapse"]),
            "mem_links": len([e for e in all_edges if e["kind"] == "mem_link"]),
            "total_edges": len(all_edges),
            "fading": len([n for n in nodes if (n.get("retention") or 1) < 0.3]),   # 곧 잊힐 기억(위험)
            "vivid": len([n for n in nodes if (n.get("retention") or 0) > 0.7]),     # 생생한 기억
        },
    }
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    s = payload["stats"]
    print(f"✅ {out}")
    print(f"   뉴런 {s['neurons']} · 기억 {s['memories']} · 시냅스 {s['synapses']} · 기억링크 {s['mem_links']} · 총엣지 {s['total_edges']}")

if __name__ == "__main__":
    main()
