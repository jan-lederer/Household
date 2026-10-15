"""HTTP-level regression tests for Dwell's dependency-free API."""
import concurrent.futures
import json
import os
import tempfile
import threading
import unittest
from http.server import ThreadingHTTPServer
from urllib.error import HTTPError
from urllib.request import Request, urlopen

import server


class ApiIntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        server.DB = os.path.join(cls.temp.name, 'dwell.sqlite')
        server.init_db()
        cls.httpd = ThreadingHTTPServer(('127.0.0.1', 0), server.Handler)
        cls.thread = threading.Thread(target=cls.httpd.serve_forever, daemon=True)
        cls.thread.start()
        cls.base = f'http://127.0.0.1:{cls.httpd.server_port}'

    @classmethod
    def tearDownClass(cls):
        cls.httpd.shutdown()
        cls.httpd.server_close()
        cls.thread.join(timeout=3)
        cls.temp.cleanup()

    def setUp(self):
        # Give each test an isolated on-disk database while keeping the real
        # server and handler shared across concurrent requests in that test.
        self.db_dir = tempfile.TemporaryDirectory(dir=self.temp.name)
        server.DB = os.path.join(self.db_dir.name, 'test.sqlite')
        server.init_db()

    def tearDown(self):
        self.db_dir.cleanup()

    def request(self, method, path, body=None, token=None):
        payload = None if body is None else json.dumps(body).encode()
        headers = {'Content-Type': 'application/json'}
        if token:
            headers['Authorization'] = 'Bearer ' + token
        request = Request(self.base + path, data=payload, headers=headers, method=method)
        try:
            response = urlopen(request, timeout=5)
        except HTTPError as error:
            response = error
        return response.code, json.loads(response.read())

    def register(self, label):
        code, result = self.request('POST', '/api/register', {
            'name': label, 'email': f'{label.lower()}@example.test', 'password': 'correct-horse-42'
        })
        self.assertEqual(code, 201, result)
        return result

    def group(self, token, name='Flatmates'):
        code, group = self.request('POST', '/api/households', {'name': name}, token)
        self.assertEqual(code, 201, group)
        return group

    def test_signup_login_sessions_and_logout(self):
        account = self.register('Alice')
        self.assertEqual(account['user']['email'], 'alice@example.test')
        code, login = self.request('POST', '/api/login', {
            'email': 'ALICE@example.test', 'password': 'correct-horse-42'
        })
        self.assertEqual(code, 200)
        self.assertNotEqual(account['token'], login['token'])
        self.assertEqual(self.request('GET', '/api/me', token=login['token'])[0], 200)
        self.assertEqual(self.request('POST', '/api/logout', token=login['token'])[0], 200)
        self.assertEqual(self.request('GET', '/api/me', token=login['token'])[0], 401)
        self.assertEqual(self.request('POST', '/api/login', {
            'email': 'alice@example.test', 'password': 'wrong-password'
        })[0], 401)

    def test_groups_membership_and_chore_isolation(self):
        alice = self.register('Alice')
        bob = self.register('Bob')
        outsider = self.register('Eve')
        group = self.group(alice['token'])
        self.assertEqual(self.request('POST', '/api/join', {'code': group['code']}, bob['token'])[0], 200)
        self.assertEqual(self.request('POST', '/api/join', {'code': group['code']}, bob['token'])[0], 200)
        chore_body = {'title': 'Take out recycling', 'room': 'Kitchen', 'due': '2026-10-16',
                      'repeat': 'none', 'assignee_id': bob['user']['id']}
        code, chore = self.request('POST', f"/api/households/{group['id']}/chores", chore_body, alice['token'])
        self.assertEqual(code, 201, chore)
        self.assertEqual(self.request('GET', f"/api/households/{group['id']}", token=bob['token'])[1]['chores'][0]['id'], chore['id'])
        self.assertEqual(self.request('GET', f"/api/households/{group['id']}", token=outsider['token'])[0], 403)
        other_group = self.group(outsider['token'], 'Other flat')
        invalid = dict(chore_body, assignee_id=outsider['user']['id'])
        self.assertEqual(self.request('POST', f"/api/households/{group['id']}/chores", invalid, alice['token'])[0], 403)
        self.assertEqual(self.request('PATCH', f"/api/chores/{chore['id']}", chore_body, outsider['token'])[0], 403)
        self.assertNotEqual(group['id'], other_group['id'])

    def test_chore_edit_complete_and_delete(self):
        alice = self.register('Carol')
        group = self.group(alice['token'])
        path = f"/api/households/{group['id']}/chores"
        code, chore = self.request('POST', path, {'title': 'Vacuum', 'room': 'Lounge', 'due': '2026-10-16'}, alice['token'])
        self.assertEqual(code, 201)
        edited = {'title': 'Vacuum rug', 'room': 'Living room', 'due': '2026-10-17', 'repeat': 'weekly'}
        code, updated = self.request('PATCH', f"/api/chores/{chore['id']}", edited, alice['token'])
        self.assertEqual(code, 200)
        self.assertEqual((updated['title'], updated['room'], updated['due'], updated['repeat']),
                         ('Vacuum rug', 'Living room', '2026-10-17', 'weekly'))
        code, completed = self.request('PATCH', f"/api/chores/{chore['id']}", {'done': True}, alice['token'])
        self.assertEqual(code, 200)
        self.assertEqual(completed['done'], 1)
        self.assertEqual(completed['completed_at'], server.date.today().isoformat())
        self.assertEqual(self.request('PATCH', f"/api/chores/{chore['id']}", edited, alice['token'])[0], 409)
        self.assertEqual(self.request('DELETE', f"/api/chores/{chore['id']}", token=alice['token'])[0], 200)
        self.assertEqual(self.request('DELETE', f"/api/chores/{chore['id']}", token=alice['token'])[0], 404)

    def test_repeat_completion_is_idempotent_under_concurrency(self):
        alice = self.register('Dana')
        group = self.group(alice['token'])
        code, chore = self.request('POST', f"/api/households/{group['id']}/chores", {
            'title': 'Water plants', 'room': 'Balcony', 'due': server.date.today().isoformat(), 'repeat': 'daily'
        }, alice['token'])
        self.assertEqual(code, 201)
        path = f"/api/chores/{chore['id']}"
        barrier = threading.Barrier(2)

        def complete():
            barrier.wait(timeout=3)
            return self.request('PATCH', path, {'done': True}, alice['token'])

        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(lambda _: complete(), range(2)))
        self.assertEqual([status for status, _ in results], [200, 200])
        chores = self.request('GET', f"/api/households/{group['id']}", token=alice['token'])[1]['chores']
        self.assertEqual(sum(c['done'] == 1 for c in chores), 1)
        self.assertEqual(len(chores), 2)
        following = next(c for c in chores if c['id'] != chore['id'])
        expected_due = (server.date.today() + server.timedelta(days=1)).isoformat()
        self.assertEqual(following['due'], expected_due)
        self.assertEqual(self.request('PATCH', path, {'done': False}, alice['token'])[0], 409)

    def test_validation_and_database_persistence(self):
        self.assertEqual(self.request('POST', '/api/register', {'name': '', 'email': 'bad', 'password': 'short'})[0], 400)
        account = self.register('Erin')
        self.assertEqual(self.request('POST', '/api/register', {
            'name': 'Duplicate', 'email': 'erin@example.test', 'password': 'correct-horse-42'
        })[0], 409)
        group = self.group(account['token'])
        path = f"/api/households/{group['id']}/chores"
        base = {'title': 'Clean', 'room': 'Hall', 'due': '2026-02-30'}
        self.assertEqual(self.request('POST', path, base, account['token'])[0], 400)
        self.assertEqual(self.request('POST', path, dict(base, due='2026-10-16', repeat='yearly'), account['token'])[0], 400)
        self.assertEqual(self.request('POST', path, dict(base, due='2026-10-16', title=' '), account['token'])[0], 400)
        self.assertEqual(self.request('GET', '/api/me')[0], 401)
        # Close and reopen the actual file to ensure all API data is durable.
        with server.connect() as db:
            self.assertEqual(db.execute('SELECT COUNT(*) FROM users').fetchone()[0], 1)
            self.assertIsNotNone(db.execute('SELECT id FROM households WHERE id=?', (group['id'],)).fetchone())


if __name__ == '__main__':
    unittest.main()
