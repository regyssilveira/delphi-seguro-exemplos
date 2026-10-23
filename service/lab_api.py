"""Servidor local de laboratório; nunca expor este processo à rede externa.

Autenticação própria com fixtures não implementa OAuth/OIDC nem substitui
um provedor de identidade. A API usa token opaco e autorização no servidor.
"""
from __future__ import annotations
import hashlib
import hmac
import json
import re
import secrets
import sqlite3
import threading
import time
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class LabServer(ThreadingHTTPServer):
    def __init__(self, port=0):
        super().__init__(("127.0.0.1", port), Handler)
        self.lock = threading.RLock()
        self.sessions = {}
        self.failures = {}
        self.events = []
        self.db = sqlite3.connect(":memory:", check_same_thread=False)
        self.db.execute("CREATE TABLE charges(id INTEGER PRIMARY KEY, tenant INTEGER, amount INTEGER, state TEXT)")
        self.db.executemany("INSERT INTO charges VALUES(?,?,?,?)", [(9817, 42, 15000, "OPEN"), (9818, 77, 10000, "OPEN")])
        self.db.execute("CREATE TABLE requests(tenant INTEGER, user TEXT, key TEXT, fingerprint TEXT, result TEXT, PRIMARY KEY(tenant,user,key))")
        self.db.commit()
        self.users = {}
        for name, tenant in (("alice", 42), ("bob", 77)):
            salt = secrets.token_bytes(16)
            password = "FICTICIA-" + name + "-2026"
            derived = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, 100_000)
            self.users[name] = {"salt": salt, "derived": derived, "tenant": tenant, "can_cancel": True, "limit": 50000}
        self.dummy_salt = secrets.token_bytes(16)
        self.dummy_hash = secrets.token_bytes(32)

    def server_close(self):
        super().server_close()
        self.db.close()


class Handler(BaseHTTPRequestHandler):
    server: LabServer

    def log_message(self, *_args):
        pass  # Não registrar URL, cabeçalhos ou mensagens livres da biblioteca.

    def send_json(self, status, value):
        content = json.dumps(value, separators=(",", ":")).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(content)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(content)

    def reject(self, status, code):
        correlation = str(uuid.uuid4())
        with self.server.lock:
            self.server.events.append({"event": "request.denied", "code": code, "correlation_id": correlation})
        self.send_json(status, {"code": code, "correlation_id": correlation})

    def read_json(self):
        if self.headers.get_content_type() != "application/json":
            raise ValueError("content_type")
        if self.headers.get("Transfer-Encoding"):
            raise ValueError("transfer_encoding")
        length = int(self.headers.get("Content-Length", "0"))
        if not 0 < length <= 4096:
            raise ValueError("body_size")
        value = json.loads(self.rfile.read(length))
        if not isinstance(value, dict):
            raise ValueError("body_type")
        return value

    def authenticate(self):
        header = self.headers.get("Authorization", "")
        if not header.startswith("Bearer ") or len(header) > 160:
            return None
        with self.server.lock:
            session = self.server.sessions.get(header[7:])
            return session if session and session["expires"] > time.monotonic() else None

    def do_GET(self):
        match = re.fullmatch(r"/v1/cobrancas/(\d+)", self.path)
        if not match:
            return self.reject(404, "not_found")
        session = self.authenticate()
        if session is None:
            return self.reject(401, "session_required")
        with self.server.lock:
            row = self.server.db.execute("SELECT id,amount,state FROM charges WHERE id=? AND tenant=?", (int(match[1]), session["tenant"])).fetchone()
        if row is None:
            return self.reject(404, "not_found")
        self.send_json(200, {"id": row[0], "amount_cents": row[1], "state": row[2]})

    def do_POST(self):
        try:
            body = self.read_json()
        except (ValueError, UnicodeError):
            return self.reject(400, "invalid_body")
        if self.path == "/session":
            return self.login(body)
        match = re.fullmatch(r"/v1/cobrancas/(\d+)/cancelar", self.path)
        if not match:
            return self.reject(404, "not_found")
        session = self.authenticate()
        if session is None:
            return self.reject(401, "session_required")
        if body != {"reason_code": "CUSTOMER_REQUEST"}:
            return self.reject(400, "invalid_fields")
        key = self.headers.get("Idempotency-Key", "")
        if not re.fullmatch(r"[a-zA-Z0-9-]{16,80}", key):
            return self.reject(400, "invalid_key")
        fingerprint = hashlib.sha256((self.path + json.dumps(body, sort_keys=True)).encode()).hexdigest()
        with self.server.lock:
            row = self.server.db.execute("SELECT amount,state FROM charges WHERE id=? AND tenant=?", (int(match[1]), session["tenant"])).fetchone()
            if row is None:
                return self.reject(404, "not_found")
            if not session["can_cancel"] or row[0] > session["limit"]:
                return self.reject(403, "not_allowed")
            previous = self.server.db.execute("SELECT fingerprint,result FROM requests WHERE tenant=? AND user=? AND key=?", (session["tenant"], session["user"], key)).fetchone()
            if previous:
                if previous[0] != fingerprint:
                    return self.reject(409, "key_conflict")
                return self.send_json(200, json.loads(previous[1]))
            if row[1] != "OPEN":
                return self.reject(409, "not_open")
            result = {"id": int(match[1]), "state": "CANCELLED"}
            with self.server.db:
                changed = self.server.db.execute("UPDATE charges SET state='CANCELLED' WHERE id=? AND tenant=? AND state='OPEN'", (int(match[1]), session["tenant"])).rowcount
                if changed != 1:
                    raise RuntimeError("unexpected_transition")
                self.server.db.execute("INSERT INTO requests VALUES(?,?,?,?,?)", (session["tenant"], session["user"], key, fingerprint, json.dumps(result)))
            self.server.events.append({"event": "charge.cancelled", "charge_id": result["id"], "tenant": session["tenant"], "user": session["user"]})
        self.send_json(200, result)

    def login(self, body):
        name, password = body.get("user"), body.get("password")
        if not isinstance(name, str) or not isinstance(password, str) or len(name) > 64 or len(password) > 128:
            return self.reject(400, "invalid_fields")
        with self.server.lock:
            count, until = self.server.failures.get(name, (0, 0))
            if until > time.monotonic():
                return self.reject(429, "try_later")
            user = self.server.users.get(name)
            salt = user["salt"] if user else self.server.dummy_salt
            expected = user["derived"] if user else self.server.dummy_hash
            candidate = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, 100_000)
            if not hmac.compare_digest(candidate, expected) or user is None:
                count += 1
                self.server.failures[name] = (count, time.monotonic() + 30 if count >= 5 else 0)
                return self.reject(401, "invalid_credentials")
            self.server.failures.pop(name, None)
            token = secrets.token_urlsafe(32)
            self.server.sessions[token] = {"user": name, "tenant": user["tenant"], "can_cancel": user["can_cancel"], "limit": user["limit"], "expires": time.monotonic() + 300}
        self.send_json(200, {"access_token": token, "expires_in": 300})


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args()
    with LabServer(args.port) as server:
        print(f"Laboratorio local em 127.0.0.1:{server.server_port}")
        server.serve_forever()
