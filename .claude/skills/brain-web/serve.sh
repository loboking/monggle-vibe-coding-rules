#!/usr/bin/env bash
# brain-web — 스캔 후 로컬 웹으로 기억 시각화를 띄운다.
# 사용: bash ~/.claude/skills/brain-web/serve.sh [port]
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT="${1:-8077}"

echo "🧠 brain-web: 데이터 스캔 중…"
python3 "$DIR/scan.py" "$DIR/data.json"

URL="http://localhost:$PORT/index.html"
echo "🌐 서버 시작: $URL  (Ctrl+C 로 종료)"

# 브라우저 자동 오픈 (macOS: open, linux: xdg-open)
( sleep 1; command -v open >/dev/null && open "$URL" || (command -v xdg-open >/dev/null && xdg-open "$URL") ) >/dev/null 2>&1 &

cd "$DIR"
exec python3 -m http.server "$PORT" --bind 127.0.0.1
