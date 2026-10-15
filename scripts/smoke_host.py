#!/usr/bin/env python3
"""Exercise the exact host bundle over HTTP without retaining test accounts."""
import importlib.util
import json
import tempfile
import threading
import urllib.request
from pathlib import Path
from zipfile import ZipFile
from http.server import ThreadingHTTPServer

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='host-smoke-', dir=root / 'artifacts') as temporary:
    folder = Path(temporary)
    with ZipFile(root / 'artifacts' / 'dwell-host.zip') as bundle:
        assert bundle.testzip() is None
        bundle.extractall(folder)
    source = folder / 'dwell-host'
    spec = importlib.util.spec_from_file_location('dwell_host_smoke', source / 'server.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.DB = str(source / 'test.sqlite')
    module.WEB = source / 'web'
    module.init_db()
    server = ThreadingHTTPServer(('127.0.0.1', 0), module.Handler)
    worker = threading.Thread(target=server.serve_forever, daemon=True)
    worker.start()
    base = f'http://127.0.0.1:{server.server_port}'
    def request(path, data=None, token=None):
        headers = {'Content-Type': 'application/json'}
        if token:
            headers['Authorization'] = 'Bearer ' + token
        req = urllib.request.Request(base + path, data=json.dumps(data).encode() if data else None, headers=headers)
        with urllib.request.urlopen(req, timeout=5) as response:
            body = response.read()
            return json.loads(body) if path.startswith('/api/') else body
    try:
        assert request('/api/health') == {'status': 'ok', 'service': 'dwell'}
        assert b'Dwell' in request('/')
        assert request('/main.dart.js') == (source / 'web' / 'main.dart.js').read_bytes()
        account = request('/api/register', {'name': 'Smoke Test', 'email': 'smoke@example.test', 'password': 'temporary-password-123'})
        token = account['token']
        home = request('/api/households', {'name': 'Bundle verification'}, token)
        assert len(home['code']) == 12
        task = request(f"/api/households/{home['id']}/chores", {'title': 'Verify the host bundle', 'room': 'Kitchen', 'due': '2026-10-15', 'repeat': 'none', 'assignee_id': account['user']['id']}, token)
        state = request(f"/api/households/{home['id']}", token=token)
        assert state['chores'][0]['id'] == task['id']
        report = {'status': 'passed', 'source': 'artifacts/dwell-host.zip', 'checks': ['zip integrity', 'API health over HTTP', 'Dwell HTML served', 'built JavaScript served byte-for-byte', 'account registration', 'household creation', '12-character invite code', 'assigned chore persisted and read back']}
        (root / 'artifacts' / 'host-smoke.json').write_text(json.dumps(report, indent=2) + '\n')
        print(json.dumps(report))
    finally:
        server.shutdown()
        server.server_close()
        worker.join(timeout=5)
