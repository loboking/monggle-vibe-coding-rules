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

def parse_frontmatter(text):
    """--- ... --- 블록을 얕게 파싱. 값은 문자열/리스트만 다룸."""
    fm, body = {}, text
    if text.startswith("---"):
        end = text.find("\n---", 3)
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
                elif line.startswith(" ") and cur_key and isinstance(fm.get(cur_key), dict):
                    mm = re.match(r"^\s+(\w[\w-]*):\s*(.*)$", line)
                    if mm:
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
    syn = data.get("synapses", data) if isinstance(data, dict) else {}
    for v in syn.values():
        if isinstance(v, dict) and v.get("source") and v.get("target"):
            edges.append({
                "source": v["source"], "target": v["target"], "kind": "synapse",
                "weight": float(v.get("weight", 0.5)),
                "activation_count": v.get("activation_count", 0),
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
        items.append({"date": m.group(1) if m else "", "label": name + " 작업내역",
                      "kind": "project_log"})
    return sorted(items, key=lambda x: x["date"], reverse=True)

def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else (Path(__file__).parent / "data.json")
    n_nodes, n_edges = scan_neurons()
    m_nodes, m_edges = scan_memory()
    s_edges = scan_synapses()
    nodes = n_nodes + m_nodes
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
        },
    }
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    s = payload["stats"]
    print(f"✅ {out}")
    print(f"   뉴런 {s['neurons']} · 기억 {s['memories']} · 시냅스 {s['synapses']} · 기억링크 {s['mem_links']} · 총엣지 {s['total_edges']}")

if __name__ == "__main__":
    main()
