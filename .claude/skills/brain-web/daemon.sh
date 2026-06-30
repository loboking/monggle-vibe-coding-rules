#!/usr/bin/env bash
# brain-web 데몬 — launchd가 상시 실행. 죽으면 자동 재시작.
# scan을 주기적으로 갱신하면서 http.server를 포그라운드로 붙잡는다.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT="${1:-8077}"
SCAN_INTERVAL="${BRAIN_WEB_SCAN_INTERVAL:-300}"  # 초. 기본 5분마다 재스캔

cd "$DIR"

# 백그라운드: 주기적 재스캔 (서버는 정적 data.json을 서빙하므로 갱신 필요)
(
  while true; do
    python3 "$DIR/scan.py" "$DIR/data.json" >/dev/null 2>&1 || true
    sleep "$SCAN_INTERVAL"
  done
) &
SCANNER_PID=$!
trap 'kill "$SCANNER_PID" 2>/dev/null || true' EXIT

# 최초 1회 스캔 (data.json 보장)
python3 "$DIR/scan.py" "$DIR/data.json" >/dev/null 2>&1 || true

# 포그라운드 서버 — launchd가 이 프로세스를 감시하다 죽으면 재시작
exec python3 -m http.server "$PORT" --bind 127.0.0.1
