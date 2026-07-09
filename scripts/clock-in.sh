#!/usr/bin/env bash
# 무인 출근 — 도현(팀장)을 아침마다 깨운다.
# 감지는 스크립트(공짜), 판단은 AI(일감 있을 때만): 일감 0건이면 도장만 찍고 AI를 깨우지 않는다.
#
# 사용:
#   clock-in.sh              # 출근 1회 실행 (launchd가 매일 이걸 호출)
#   clock-in.sh --register   # launchd 등록 — 매일 09:03 자동 출근 (opt-in)
#   clock-in.sh --unregister # 해제
set -uo pipefail

TEAM="$HOME/.claude/agents-team"
INBOX="$TEAM/_inbox.md"
ATT="$TEAM/_attendance"
LABEL="com.monggle.clock-in"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

case "${1:-}" in
  --register)
    [ "$(uname)" = "Darwin" ] || { echo "launchd는 macOS 전용" >&2; exit 1; }
    mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
    cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$SELF</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict><key>Hour</key><integer>9</integer><key>Minute</key><integer>3</integer></dict>
    <key>EnvironmentVariables</key>
    <dict><key>PATH</key><string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string></dict>
    <key>StandardOutPath</key><string>$HOME/Library/Logs/clock-in.log</string>
    <key>StandardErrorPath</key><string>$HOME/Library/Logs/clock-in.err.log</string>
</dict>
</plist>
PLIST
    launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
    launchctl bootstrap "gui/$(id -u)" "$PLIST"
    echo "✅ 무인 출근 등록: 매일 09:03 → 도현 기상 ($PLIST)"
    exit 0 ;;
  --unregister)
    launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
    rm -f "$PLIST"
    echo "✅ 무인 출근 해제"
    exit 0 ;;
esac

mkdir -p "$ATT"
TODAY="$(date +%F)"

# 일감 감지: _inbox.md의 "## 일감" 섹션에 "- " 항목이 있는가
if ! awk '/^## 일감/{f=1;next} f && /^- /{found=1} END{exit !found}' "$INBOX" 2>/dev/null; then
  printf '# %s 출근 보고 (도현·자동)\n\n- 출근: %s (cron)\n- 일감 0건 · 퇴근\n' "$TODAY" "$(date +%H:%M)" > "$ATT/$TODAY.md"
  exit 0
fi

# 일감 있음 → 도현 기상 (headless Claude)
command -v claude >/dev/null 2>&1 || { echo "claude CLI 없음 — 출근 불가" >&2; exit 1; }
cd "$(cat "$HOME/.claude/.repo_path" 2>/dev/null || echo "$HOME")"
claude -p --permission-mode acceptEdits \
  "무인 출근이다. Task 도구로 team_dohyeon 서브에이전트를 호출해, 등록 파일의 '무인 출근' 절차(받은편지함 ~/.claude/agents-team/_inbox.md 확인 → Task Package로 분배 → 결재 경계 준수: 커밋·푸시·배포·외부발송 금지 → 출근 보고서 ~/.claude/agents-team/_attendance/$TODAY.md 작성)를 수행하게 하라. 완료 후 보고서 경로만 출력하라." \
  >> "$ATT/$TODAY.headless.log" 2>&1 || true
