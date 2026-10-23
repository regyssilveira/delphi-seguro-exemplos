import concurrent.futures
import http.client
import json
from pathlib import Path
import subprocess
import threading
import unittest
import uuid
from lab_api import LabServer


class ApiTests(unittest.TestCase):
    def setUp(self):
        self.server = LabServer()
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()

    def request(self, method, path, body=None, token=None, key=None):
        headers = {"Content-Type": "application/json"}
        if token: headers["Authorization"] = "Bearer " + token
        if key: headers["Idempotency-Key"] = key
        connection = http.client.HTTPConnection("127.0.0.1", self.server.server_port, timeout=3)
        try:
            connection.request(method, path, json.dumps(body) if body is not None else None, headers)
            response = connection.getresponse()
            return response.status, json.loads(response.read())
        finally:
            connection.close()

    def login(self, name="alice"):
        status, body = self.request("POST", "/session", {"user": name, "password": "FICTICIA-" + name + "-2026"})
        self.assertEqual(status, 200)
        return body["access_token"]

    def test_authentication_and_expiration(self):
        self.assertEqual(self.request("GET", "/v1/cobrancas/9817")[0], 401)
        token = self.login()
        self.assertEqual(self.request("GET", "/v1/cobrancas/9817", token=token)[0], 200)
        self.server.sessions[token]["expires"] = 0
        self.assertEqual(self.request("GET", "/v1/cobrancas/9817", token=token)[0], 401)

    def test_credentials_have_uniform_failure_and_limit(self):
        first = self.request("POST", "/session", {"user": "alice", "password": "errada"})
        absent = self.request("POST", "/session", {"user": "ausente", "password": "errada"})
        self.assertEqual((first[0], first[1]["code"]), (absent[0], absent[1]["code"]))
        for _ in range(4):
            self.request("POST", "/session", {"user": "alice", "password": "errada"})
        self.assertEqual(self.request("POST", "/session", {"user": "alice", "password": "errada"})[0], 429)

    def test_cross_tenant_and_client_claims(self):
        token = self.login("bob")
        self.assertEqual(self.request("GET", "/v1/cobrancas/9817", token=token)[0], 404)
        self.assertEqual(self.request("POST", "/v1/cobrancas/9817/cancelar", {"reason_code": "CUSTOMER_REQUEST", "role": "ADMIN"}, token, str(uuid.uuid4()))[0], 400)

    def test_permission_and_limit(self):
        token = self.login()
        self.server.sessions[token]["can_cancel"] = False
        self.assertEqual(self.request("POST", "/v1/cobrancas/9817/cancelar", {"reason_code": "CUSTOMER_REQUEST"}, token, str(uuid.uuid4()))[0], 403)
        self.server.sessions[token]["can_cancel"] = True
        self.server.sessions[token]["limit"] = 100
        self.assertEqual(self.request("POST", "/v1/cobrancas/9817/cancelar", {"reason_code": "CUSTOMER_REQUEST"}, token, str(uuid.uuid4()))[0], 403)

    def test_concurrent_duplicate_and_key_conflict(self):
        token, key = self.login(), str(uuid.uuid4())
        def cancel(_):
            return self.request("POST", "/v1/cobrancas/9817/cancelar", {"reason_code": "CUSTOMER_REQUEST"}, token, key)
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
            results = list(pool.map(cancel, range(4)))
        self.assertTrue(all(code == 200 for code, _ in results))
        self.assertEqual(len([e for e in self.server.events if e["event"] == "charge.cancelled"]), 1)
        # Mesma identidade e chave, mas outra operação sobre recurso do mesmo tenant.
        with self.server.db:
            self.server.db.execute("INSERT INTO charges VALUES(9819,42,100,'OPEN')")
        self.assertEqual(self.request("POST", "/v1/cobrancas/9819/cancelar", {"reason_code": "CUSTOMER_REQUEST"}, token, key)[0], 409)

    def test_no_secrets_in_events(self):
        token = self.login()
        self.request("GET", "/v1/cobrancas/9818", token=token)
        output = json.dumps(self.server.events)
        for marker in (token, "FICTICIA-alice-2026", "Authorization", "password"):
            self.assertNotIn(marker, output)

    def test_delphi_client(self):
        executable = Path(__file__).resolve().parents[1] / "build/win64/HttpClientLab.exe"
        if not executable.exists():
            self.skipTest("Compile primeiro com scripts/test-delphi.ps1")
        result = subprocess.run([str(executable), str(self.server.server_port)], capture_output=True, text=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        print(result.stdout, end="")


if __name__ == "__main__":
    unittest.main()
