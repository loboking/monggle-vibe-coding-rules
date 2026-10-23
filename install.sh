#!/usr/bin/env bash
#
# monggle-agent-kit 설치기
#
# 스킬 원본(skills/)과 셸 스크립트(bin/)를 도구별 위치로 뿌린다.
# 스크립트는 ~/.monggle/bin 에 한 벌만 두고 모든 도구가 그걸 부른다.
#
#   ./install.sh --claude      Claude Code  → ~/.claude/skills/<이름>/SKILL.md
#   ./install.sh --codex       Codex CLI    → ~/.codex/prompts/<이름>.md
#   ./install.sh --opencode    OpenCode     → ~/.config/opencode/command/<이름>.md
#   ./install.sh --gemini      Gemini CLI   → ~/.gemini/commands/<이름>.toml
#   ./install.sh --all         설치된 도구를 찾아서 전부
#   ./install.sh --dry-run     무엇을 어디에 쓸지만 보여준다
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DST="$HOME/.monggle/bin"
DRY=0
TARGETS=()

for arg in "$@"; do
    case "$arg" in
        --claude|--codex|--opencode|--gemini) TARGETS+=("${arg#--}") ;;
        --all) TARGETS=(claude codex opencode gemini) ;;
        --dry-run) DRY=1 ;;
        -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "모르는 옵션: $arg" >&2; exit 1 ;;
    esac
done
[ ${#TARGETS[@]} -eq 0 ] && TARGETS=(claude codex opencode gemini)

say() { printf '%s\n' "$*"; }
run() { if [ "$DRY" = 1 ]; then say "  [건너뜀] $*"; else "$@"; fi; }

# 스킬 하나의 본문(frontmatter 제외)을 꺼낸다
skill_body() { awk 'BEGIN{d=0} /^---$/{d++; next} d>=2{print}' "$1"; }
# frontmatter 에서 한 필드를 꺼낸다
skill_field() { awk -v k="$2" 'BEGIN{d=0} /^---$/{d++; next} d==1 && $0 ~ "^"k":" {sub("^"k":[ \t]*",""); print; exit}' "$1"; }

install_scripts() {
    say "스크립트 → $BIN_DST"
    run mkdir -p "$BIN_DST"
    if [ "$DRY" = 0 ]; then
        cp -R "$ROOT/bin/." "$BIN_DST/"
        chmod +x "$BIN_DST"/*.sh 2>/dev/null || true
    fi
    say "  $(ls "$ROOT/bin" | wc -l | tr -d ' ')개"
}

install_claude() {
    local dst="$HOME/.claude/skills"
    say "Claude Code → $dst"
    run mkdir -p "$dst"
    local n=0
    for d in "$ROOT"/skills/*/; do
        local name; name="$(basename "$d")"
        if [ "$DRY" = 0 ]; then rm -rf "$dst/$name"; cp -R "$d" "$dst/$name"; fi
        n=$((n+1))
    done
    say "  스킬 ${n}개"
}

# Codex·OpenCode 는 frontmatter 없는 마크다운 슬래시 프롬프트를 읽는다
install_markdown_prompts() {
    local dst="$1" label="$2"
    say "$label → $dst"
    run mkdir -p "$dst"
    local n=0
    for f in "$ROOT"/skills/*/SKILL.md; do
        local name; name="$(basename "$(dirname "$f")")"
        local desc; desc="$(skill_field "$f" description)"
        if [ "$DRY" = 0 ]; then
            { printf '%s\n\n' "<!-- monggle-agent-kit 에서 생성됨. 원본: skills/$name/SKILL.md -->"
              [ -n "$desc" ] && printf '%s\n\n' "$desc"
              skill_body "$f"
            } > "$dst/$name.md"
        fi
        n=$((n+1))
    done
    say "  프롬프트 ${n}개"
}

# Gemini CLI 는 TOML(description + prompt)을 읽는다
install_gemini() {
    local dst="$HOME/.gemini/commands"
    say "Gemini CLI → $dst"
    run mkdir -p "$dst"
    local n=0
    for f in "$ROOT"/skills/*/SKILL.md; do
        local name; name="$(basename "$(dirname "$f")")"
        if [ "$DRY" = 0 ]; then
            python3 - "$f" "$dst/$name.toml" <<'PY'
import re, sys, pathlib
src, out = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
t = src.read_text(encoding="utf-8", errors="replace")
m = re.match(r"^---\n(.*?)\n---\n(.*)$", t, re.S)
fm, body = (m.group(1), m.group(2)) if m else ("", t)
d = re.search(r"^description:\s*(.*)$", fm, re.M)
desc = (d.group(1).strip() if d else src.parent.name).replace('"', "'")
body = body.strip()
# TOML 여러 줄 문자열 — 본문에 따옴표 3개가 들어 있으면 블록이 거기서 끊기므로 구분자를 바꾼다
TQ = chr(34) * 3
SQ = chr(39) * 3
if TQ not in body:
    block = TQ + "\n" + body + "\n" + TQ
elif SQ not in body:
    block = SQ + "\n" + body + "\n" + SQ
else:
    block = TQ + "\n" + body.replace(TQ, "\\" + chr(34) + "\\" + chr(34) + "\\" + chr(34)) + "\n" + TQ
out.write_text('description = "' + desc + '"\n\nprompt = ' + block + "\n", encoding="utf-8")
PY
        fi
        n=$((n+1))
    done
    say "  명령 ${n}개"
}

# brain 은 모든 도구가 같이 쓰도록 공용 위치(~/.agents/skills/brain)에 코드·훅을 한 벌 둔다.
# 기억 데이터는 여기가 아니라 각 프로젝트의 .agents/brain 에 쌓인다(brain-resolve.sh).
BRAIN_DST="$HOME/.agents/skills/brain"
install_brain() {
    say "brain → $BRAIN_DST"
    if [ "$DRY" = 0 ]; then
        rm -rf "$BRAIN_DST"; mkdir -p "$BRAIN_DST/scripts"
        cp "$ROOT/skills/brain/SKILL.md" "$BRAIN_DST/"
        cp "$ROOT"/brain/*.sh "$ROOT"/.claude/hooks/brain-*.sh "$BRAIN_DST/scripts/"
        chmod +x "$BRAIN_DST"/scripts/*.sh
    fi
}

# Claude 는 ~/.agents/skills 를 읽는지 확인되지 않아 링크로 연결하고, 훅은 전역 settings.json 에 건다.
# 기존 설정은 보존하고 brain 항목만 추가·교체한다(재실행해도 중복 없음).
register_claude_brain() {
    local sf="$HOME/.claude/settings.json" s="$BRAIN_DST/scripts"
    say "Claude Code brain 훅 → $sf"
    [ "$DRY" = 1 ] && return 0
    command -v jq >/dev/null || { say "  jq 가 없어 건너뜀"; return 0; }
    rm -rf "$HOME/.claude/skills/brain"; ln -s "$BRAIN_DST" "$HOME/.claude/skills/brain"
    [ -f "$sf" ] || echo '{}' > "$sf"
    local tmp; tmp="$(mktemp)"
    jq --arg s "$s" '
        def put($ev; $file; $t):
            .hooks[$ev] = ([(.hooks[$ev] // [])[] | select(any(.hooks[]?; .command | test("brain-")) | not)]
                           + [{"matcher":"*","hooks":[{"type":"command","command":"\($s)/\($file)","timeout":$t}]}]);
        .hooks = (.hooks // {})
        | put("SessionStart"; "brain-session-start.sh"; 10)
        | put("UserPromptSubmit"; "brain-prompt-recall.sh"; 15)
        | put("Stop"; "brain-turn-save.sh"; 15)
        | put("SessionEnd"; "brain-session-end.sh"; 30)
    ' "$sf" > "$tmp" && mv "$tmp" "$sf" || { rm -f "$tmp"; say "  settings.json 갱신 실패"; }
}

say "monggle-agent-kit 설치 — 대상: ${TARGETS[*]}"
[ "$DRY" = 1 ] && say "(--dry-run: 실제로 쓰지 않는다)"
say ""
install_scripts
install_brain
for t in "${TARGETS[@]}"; do
    case "$t" in
        claude)   install_claude; register_claude_brain ;;
        codex)    [ -d "$HOME/.codex" ] && install_markdown_prompts "$HOME/.codex/prompts" "Codex CLI" || say "Codex CLI → 건너뜀(~/.codex 없음)" ;;
        opencode) [ -d "$HOME/.config/opencode" ] && install_markdown_prompts "$HOME/.config/opencode/command" "OpenCode" || say "OpenCode → 건너뜀(~/.config/opencode 없음)" ;;
        gemini)   [ -d "$HOME/.gemini" ] && install_gemini || say "Gemini CLI → 건너뜀(~/.gemini 없음)" ;;
    esac
done
say ""
say "끝. 규칙 원본은 AGENTS.md 이고 CLAUDE.md·GEMINI.md 는 그걸 가리킨다."
