#!/usr/bin/env bash
# brain-web — 스캔 후 로컬 웹으로 기억 시각화를 띄운다.
# 사용: bash ~/.claude/skills/brain-web/serve.sh [port]
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT="${1:-8077}"
LABEL="com.monggle.brain-web"
URL="http://localhost:$PORT/index.html"

echo "🧠 brain-web: 데이터 스캔 중…"
python3 "$DIR/scan.py" "$DIR/data.json"

open_browser() {
  ( sleep 1; command -v open >/dev/null && open "$URL" || (command -v xdg-open >/dev/null && xdg-open "$URL") ) >/dev/null 2>&1 &
}

# 이미 서버가 살아있으면(launchd 데몬 등) 두 번 띄우지 않는다.
# 여기서 직접 띄우면 포트 결투가 나서 launchd 데몬이 crash loop에 빠진다.
if curl -s -o /dev/null --max-time 2 "http://127.0.0.1:$PORT/"; then
  echo "✅ 이미 실행 중: $URL — 브라우저만 엽니다"
  open_browser
  exit 0
fi

# launchd 데몬이 등록돼 있으면 데몬으로 기동 — 서버 소유권은 launchd에 (죽어도 자동 부활)
if [ "$(uname)" = "Darwin" ] && launchctl print "gui/$(id -u)/$LABEL" >/dev/null 2>&1; then
  echo "🚀 launchd 데몬으로 기동: $URL"
  launchctl kickstart "gui/$(id -u)/$LABEL" || true
  sleep 2
  open_browser
  exit 0
fi

# 데몬 없는 환경(linux 등) 폴백 — 직접 포그라운드 실행
echo "🌐 서버 시작: $URL  (Ctrl+C 로 종료)"
open_browser
cd "$DIR"
exec python3 -m http.server "$PORT" --bind 127.0.0.1
