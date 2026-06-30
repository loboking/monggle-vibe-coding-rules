#!/usr/bin/env python3
"""ensure_skill_frontmatter — 스킬 SKILL.md의 frontmatter(name/description)를 보장한다.

업그레이드/설치 후 자동 호출되어, 새로 받은 스킬이 frontmatter 없이 들어와도
자동으로 보정한다. 멱등(여러 번 돌려도 안전), 표준 라이브러리만 사용.

규칙:
  - SKILL.md가 '---' frontmatter로 시작하지 않으면:
      디렉토리명을 name, '# 제목' 다음 첫 비어있지 않은 줄을 description으로 삽입.
  - 이미 frontmatter가 있으면 건드리지 않는다(사람이 다듬은 description 보존).
  - 외부 플러그인(~/.claude/plugins/**)은 대상에서 제외 — 우리 스킬만.

대상 루트:
  - ~/.claude/skills
  - (인자로 추가 경로 전달 가능: 프로젝트 .claude/skills 등)

사용:
  python3 ensure_skill_frontmatter.py            # 검사+보정
  python3 ensure_skill_frontmatter.py --check     # 보정 없이 누락만 리포트(종료코드 1=누락있음)
  python3 ensure_skill_frontmatter.py /path/to/skills  # 추가 루트
"""
import sys, re
from pathlib import Path

def yaml_clean(s: str) -> str:
    s = s.strip().replace('"', "'")
    s = s.replace("**", "").replace("`", "").replace("__", "")  # 마크다운 강조 제거
    s = re.sub(r"\s+", " ", s).strip()
    return s

def build_frontmatter(d: Path) -> str:
    text = (d / "SKILL.md").read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines()
    title, desc = d.name, ""
    for i, ln in enumerate(lines):
        if ln.startswith("#"):
            title = ln.lstrip("# ").strip() or d.name
            for nxt in lines[i + 1:]:
                if nxt.strip():
                    desc = nxt.strip()
                    break
            break
    if not desc:
        desc = f"{d.name} 스킬"
    return f"---\nname: {d.name}\ndescription: {yaml_clean(desc)}\n---\n\n", text

def collect_roots(extra):
    roots = [Path.home() / ".claude" / "skills"]
    for p in extra:
        roots.append(Path(p))
    return [r for r in roots if r.exists()]

def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    check_only = "--check" in sys.argv
    roots = collect_roots(args)

    fixed, missing = [], []
    for root in roots:
        # 외부 플러그인 경로는 제외
        if "plugins" in root.parts:
            continue
        for d in sorted(root.iterdir()):
            if not d.is_dir():
                continue
            f = d / "SKILL.md"
            if not f.exists():
                continue
            text = f.read_text(encoding="utf-8", errors="replace")
            if text.lstrip().startswith("---"):
                continue  # 이미 정상
            missing.append(d.name)
            if not check_only:
                fm, original = build_frontmatter(d)
                # .bak이 없을 때만 백업(최초 보정본 보존)
                bak = f.with_suffix(".md.bak")
                if not bak.exists():
                    bak.write_text(original, encoding="utf-8")
                f.write_text(fm + original, encoding="utf-8")
                fixed.append(d.name)

    if check_only:
        if missing:
            print(f"[ensure-frontmatter] 누락 {len(missing)}개: {', '.join(missing)}")
            sys.exit(1)
        print("[ensure-frontmatter] 모든 스킬 frontmatter 정상")
        sys.exit(0)
    else:
        if fixed:
            print(f"[ensure-frontmatter] {len(fixed)}개 스킬 frontmatter 자동 보정: {', '.join(fixed)}")
        else:
            print("[ensure-frontmatter] 보정 대상 없음 (모두 정상)")

if __name__ == "__main__":
    main()
