"""Tiny mock of the Tekservix APIs for the CLI tests: records each request to a file and
answers with canned JSON. Paths starting with /fail return an API error."""
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

LOG = sys.argv[2]


class Handler(BaseHTTPRequestHandler):
    def handle_any(self):
        length = int(self.headers.get("content-length") or 0)
        body = self.rfile.read(length).decode() if length else ""
        with open(LOG, "a", encoding="utf-8") as f:
            f.write(json.dumps({
                "method": self.command,
                "path": self.path,
                "key": self.headers.get("x-api-key") or self.headers.get("authorization"),
                "body": json.loads(body) if body else None,
            }) + "\n")
        if self.path.startswith("/fail"):
            status, reply = 429, {"success": False, "message": "Too many requests"}
        elif self.path.startswith("/soft"):
            status, reply = 200, {"success": False, "message": "Invalid number"}
        else:
            status, reply = 200, {"success": True, "data": {"ok": True, "message_ids": [1873], "msgId": 58213}}
        data = json.dumps(reply).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    do_GET = do_POST = do_PUT = do_DELETE = handle_any

    def log_message(self, *args):
        pass


HTTPServer(("127.0.0.1", int(sys.argv[1])), Handler).serve_forever()
