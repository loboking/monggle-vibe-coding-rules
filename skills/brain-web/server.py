#!/usr/bin/env python3
"""brain-web 로컬 서버. index.html 과 data.json 두 파일만 내준다.

python -m http.server 는 폴더 전체를 보여주고 Host 를 확인하지 않아,
악성 웹페이지가 DNS 리바인딩으로 127.0.0.1 의 기억 데이터를 읽어 갈 수 있었다.
사용: python3 server.py <port>
"""
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8077
FILES = {
    "/": (Path(__file__).parent / "index.html", "text/html; charset=utf-8"),
    "/index.html": (Path(__file__).parent / "index.html", "text/html; charset=utf-8"),
    "/data.json": (Path.home() / ".agents" / "brain-web-data" / "data.json", "application/json"),
}
HOSTS = {f"127.0.0.1:{PORT}", f"localhost:{PORT}", "127.0.0.1", "localhost"}


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.headers.get("Host", "") not in HOSTS:
            return self.send_error(403)
        entry = FILES.get(self.path.split("?", 1)[0])
        if not entry or not entry[0].is_file():
            return self.send_error(404)
        body = entry[0].read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", entry[1])
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
