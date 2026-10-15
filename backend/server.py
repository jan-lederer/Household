"""Dwell's dependency-free, persistent HTTP API and Flutter web host."""
import hashlib
import hmac
import json
import mimetypes
import os
import re
import secrets
import sqlite3
import time
import threading
import weakref
from collections import OrderedDict, deque
from datetime import date, timedelta
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

DB = os.environ.get('DWELL_DB', str(Path(__file__).parent / 'data' / 'dwell.sqlite'))
WEB = Path(os.environ.get('DWELL_WEB', str(Path(__file__).parents[1] / 'build' / 'web'))).resolve()
SCHEMA = '''
PRAGMA journal_mode=WAL;
PRAGMA foreign_keys=ON;
CREATE TABLE IF NOT EXISTS users(id TEXT PRIMARY KEY,name TEXT NOT NULL,email TEXT UNIQUE NOT NULL,password TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS sessions(token TEXT PRIMARY KEY,user_id TEXT REFERENCES users(id),expires INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS households(id TEXT PRIMARY KEY,name TEXT NOT NULL,code TEXT UNIQUE NOT NULL,owner_id TEXT REFERENCES users(id));
CREATE TABLE IF NOT EXISTS members(household_id TEXT REFERENCES households(id),user_id TEXT REFERENCES users(id),PRIMARY KEY(household_id,user_id));
CREATE TABLE IF NOT EXISTS chores(id TEXT PRIMARY KEY,household_id TEXT REFERENCES households(id),title TEXT NOT NULL,room TEXT NOT NULL,assignee_id TEXT REFERENCES users(id),due TEXT NOT NULL,repeat TEXT NOT NULL DEFAULT 'none',done INTEGER NOT NULL DEFAULT 0,completed_at TEXT,created_by TEXT REFERENCES users(id));
'''

RATE_LIMITS = {
    '/api/login': (30, 10 * 60),
    '/api/register': (30, 10 * 60),
    '/api/join': (20, 10 * 60),
}


class RequestLimiter:
    """Thread-safe sliding-window limits with bounded per-client state."""
    def __init__(self, max_keys=4096):
        self.max_keys = max_keys
        self._requests = OrderedDict()
        self._lock = threading.Lock()
        self._operations = 0

    def allow(self, client_ip, endpoint, limit, window_seconds, now=None):
        now = time.monotonic() if now is None else now
        key = (client_ip, endpoint)
        with self._lock:
            self._operations += 1
            if self._operations % 128 == 0:
                self._prune(now)

            attempts = self._requests.get(key)
            if attempts is not None:
                while attempts and now - attempts[0] >= window_seconds:
                    attempts.popleft()
                if not attempts:
                    del self._requests[key]
                    attempts = None

            if attempts is None:
                if len(self._requests) >= self.max_keys:
                    self._requests.popitem(last=False)
                attempts = deque()
                self._requests[key] = attempts
            else:
                self._requests.move_to_end(key)

            if len(attempts) >= limit:
                return False
            attempts.append(now)
            return True

    def _prune(self, now):
        for key, attempts in list(self._requests.items()):
            window = RATE_LIMITS.get(key[1], (0, 0))[1]
            while attempts and now - attempts[0] >= window:
                attempts.popleft()
            if not attempts:
                del self._requests[key]


_server_limiters = weakref.WeakKeyDictionary()
_server_limiters_lock = threading.Lock()


def limiter_for(http_server):
    # Keep independent limits for each HTTP server instance and release state
    # automatically when an embedded/test server shuts down.
    with _server_limiters_lock:
        limiter = _server_limiters.get(http_server)
        if limiter is None:
            limiter = RequestLimiter()
            _server_limiters[http_server] = limiter
        return limiter

def connect():
    db = sqlite3.connect(DB, timeout=15)
    db.row_factory = sqlite3.Row
    db.execute('PRAGMA foreign_keys=ON')
    return db

def init_db():
    Path(DB).parent.mkdir(parents=True, exist_ok=True)
    with connect() as db:
        db.executescript(SCHEMA)

def password_hash(password, salt=None):
    salt = salt or secrets.token_hex(16)
    return salt + ':' + hashlib.pbkdf2_hmac('sha256', password.encode(), bytes.fromhex(salt), 310000).hex()

def uid():
    return secrets.token_hex(12)

class ApiError(Exception):
    def __init__(self, status, message):
        self.status, self.message = status, message

class Handler(BaseHTTPRequestHandler):
    server_version = 'Dwell/1.0'

    def log_message(self, fmt, *args):
        # Paths and status only; never log credentials or authorization headers.
        print('%s %s' % (self.address_string(), fmt % args), flush=True)

    def send_json(self, status, data):
        body = json.dumps(data).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Cache-Control', 'no-store')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self): self.dispatch()
    def do_POST(self): self.dispatch()
    def do_PATCH(self): self.dispatch()
    def do_DELETE(self): self.dispatch()

    def dispatch(self):
        path = urlparse(self.path).path
        try:
            if self.command == 'POST' and path in RATE_LIMITS:
                limit, window = RATE_LIMITS[path]
                if not limiter_for(self.server).allow(
                    self.client_address[0], path, limit, window
                ):
                    raise ApiError(429, 'Too many attempts. Please wait before trying again.')
            if not path.startswith('/api/'):
                return self.static(path)
            length = int(self.headers.get('Content-Length', '0'))
            if length > 16384:
                raise ApiError(413, 'Request too large.')
            try:
                data = json.loads(self.rfile.read(length)) if length else {}
            except (ValueError, UnicodeError):
                raise ApiError(400, 'Invalid JSON.')
            if not isinstance(data, dict):
                raise ApiError(400, 'Expected a JSON object.')
            with connect() as db:
                result, status = self.route(db, self.command, path, data)
            self.send_json(status, result)
        except ApiError as error:
            self.send_json(error.status, {'error': error.message})
        except sqlite3.IntegrityError:
            self.send_json(409, {'error': 'This account or membership already exists.'})
        except (ValueError, TypeError, OverflowError):
            self.send_json(400, {'error': 'Invalid request values.'})
        except Exception:
            self.send_json(500, {'error': 'Something went wrong. Please try again.'})

    def static(self, path):
        file = (WEB / path.lstrip('/')).resolve()
        if not file.is_relative_to(WEB):
            raise ApiError(404, 'Not found.')
        if not file.is_file():
            file = WEB / 'index.html'
        if not file.is_file():
            return self.send_json(200 if path == '/' else 404, {'service': 'Dwell', 'health': '/api/health'})
        body = file.read_bytes()
        self.send_response(200)
        self.send_header('Content-Type', mimetypes.guess_type(str(file))[0] or 'application/octet-stream')
        self.send_header('Content-Length', str(len(body)))
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.end_headers()
        self.wfile.write(body)

    def text(self, data, key, maximum=100, minimum=1):
        value = data.get(key, '')
        if not isinstance(value, str) or not minimum <= len(value.strip()) <= maximum:
            raise ApiError(400, f'{key.replace("_", " ").capitalize()} must be {minimum}–{maximum} characters.')
        return value.strip()

    def member(self, db, household_id, user_id):
        if not db.execute('SELECT 1 FROM members WHERE household_id=? AND user_id=?', (household_id, user_id)).fetchone():
            raise ApiError(403, 'You do not belong to this household.')

    def route(self, db, method, path, data):
        if path == '/api/health' and method == 'GET':
            db.execute('SELECT 1').fetchone()
            return {'status': 'ok', 'service': 'dwell'}, 200
        if path in ('/api/register', '/api/login') and method == 'POST':
            email = self.text(data, 'email', 254).lower()
            password = data.get('password', '')
            if not re.fullmatch(r'[^\s@]+@[^\s@]+\.[^\s@]+', email):
                raise ApiError(400, 'Enter a valid email address.')
            if not isinstance(password, str) or not 8 <= len(password) <= 128:
                raise ApiError(400, 'Password must be 8–128 characters.')
            if path == '/api/register':
                user_id = uid()
                db.execute('INSERT INTO users VALUES(?,?,?,?)', (user_id, self.text(data, 'name', 60), email, password_hash(password)))
            else:
                user = db.execute('SELECT * FROM users WHERE email=?', (email,)).fetchone()
                # Perform a hash even for unknown emails to avoid an obvious timing difference.
                stored = user['password'] if user else '00' * 16 + ':' + '00' * 32
                computed = password_hash(password, stored.split(':')[0])
                if not user or not hmac.compare_digest(stored, computed):
                    raise ApiError(401, 'Email or password is incorrect.')
                user_id = user['id']
            token = secrets.token_urlsafe(32)
            db.execute('DELETE FROM sessions WHERE expires < ?', (int(time.time()),))
            db.execute('INSERT INTO sessions VALUES(?,?,?)', (hashlib.sha256(token.encode()).hexdigest(), user_id, int(time.time()) + 30*86400))
            user = dict(db.execute('SELECT id,name,email FROM users WHERE id=?', (user_id,)).fetchone())
            return {'token': token, 'user': user}, 201 if path == '/api/register' else 200
        raw_token = self.headers.get('Authorization', '').removeprefix('Bearer ')
        token_hash = hashlib.sha256(raw_token.encode()).hexdigest()
        session = db.execute('SELECT user_id FROM sessions WHERE token=? AND expires>?', (token_hash, int(time.time()))).fetchone()
        if not session:
            raise ApiError(401, 'Please sign in again.')
        user_id = session['user_id']
        if path == '/api/logout' and method == 'POST':
            db.execute('DELETE FROM sessions WHERE token=?', (token_hash,))
            return {'ok': True}, 200
        if path == '/api/me' and method == 'GET':
            user = dict(db.execute('SELECT id,name,email FROM users WHERE id=?', (user_id,)).fetchone())
            groups = [dict(row) for row in db.execute('SELECT h.* FROM households h JOIN members m ON m.household_id=h.id WHERE m.user_id=? ORDER BY h.rowid', (user_id,))]
            return {'user': user, 'households': groups}, 200
        if path == '/api/households' and method == 'POST':
            group = dict(id=uid(), name=self.text(data, 'name', 60), code=secrets.token_hex(6).upper(), owner_id=user_id)
            db.execute('INSERT INTO households VALUES(:id,:name,:code,:owner_id)', group)
            db.execute('INSERT INTO members VALUES(?,?)', (group['id'], user_id))
            return group, 201
        if path == '/api/join' and method == 'POST':
            code = self.text(data, 'code', 20).upper()
            group = db.execute('SELECT * FROM households WHERE code=?', (code,)).fetchone()
            if not group:
                raise ApiError(404, 'That invite code was not found.')
            db.execute('INSERT OR IGNORE INTO members VALUES(?,?)', (group['id'], user_id))
            return dict(group), 200
        match = re.fullmatch(r'/api/households/([a-f0-9]+)/?(chores)?', path)
        if match:
            group_id, action = match.groups()
            self.member(db, group_id, user_id)
            if method == 'GET' and not action:
                group = dict(db.execute('SELECT * FROM households WHERE id=?', (group_id,)).fetchone())
                members = [dict(r) for r in db.execute('SELECT u.id,u.name FROM users u JOIN members m ON m.user_id=u.id WHERE m.household_id=? ORDER BY u.name', (group_id,))]
                chores = [dict(r) for r in db.execute('SELECT * FROM chores WHERE household_id=? ORDER BY done,due,rowid DESC', (group_id,))]
                return {'household': group, 'members': members, 'chores': chores}, 200
            if method == 'POST' and action == 'chores':
                chore = self.chore_values(db, data, group_id)
                chore.update(id=uid(), household_id=group_id, created_by=user_id)
                db.execute('INSERT INTO chores(id,household_id,title,room,assignee_id,due,repeat,created_by) VALUES(:id,:household_id,:title,:room,:assignee_id,:due,:repeat,:created_by)', chore)
                return dict(db.execute('SELECT * FROM chores WHERE id=?', (chore['id'],)).fetchone()), 201
        match = re.fullmatch(r'/api/chores/([a-f0-9]+)', path)
        if match:
            chore = db.execute('SELECT * FROM chores WHERE id=?', (match[1],)).fetchone()
            if not chore:
                raise ApiError(404, 'Chore not found.')
            self.member(db, chore['household_id'], user_id)
            if method == 'DELETE':
                db.execute('DELETE FROM chores WHERE id=?', (chore['id'],))
                return {'ok': True}, 200
            if method == 'PATCH':
                if 'done' in data:
                    if type(data['done']) is not bool:
                        raise ApiError(400, 'Done must be true or false.')
                    # BEGIN IMMEDIATE serializes completion so repeat instances are created once.
                    db.execute('BEGIN IMMEDIATE')
                    chore = db.execute('SELECT * FROM chores WHERE id=?', (match[1],)).fetchone()
                    if chore['done'] and not data['done'] and chore['repeat'] != 'none':
                        raise ApiError(409, 'Repeating chores cannot be reopened. Edit the next occurrence instead.')
                    changed = db.execute('UPDATE chores SET done=?,completed_at=? WHERE id=? AND done<>?', (int(data['done']), date.today().isoformat() if data['done'] else None, chore['id'], int(data['done']))).rowcount
                    if changed and data['done'] and chore['repeat'] != 'none':
                        next_due = max(date.fromisoformat(chore['due']), date.today()) + timedelta(days=1 if chore['repeat'] == 'daily' else 7)
                        db.execute('INSERT INTO chores(id,household_id,title,room,assignee_id,due,repeat,created_by) VALUES(?,?,?,?,?,?,?,?)', (uid(),chore['household_id'],chore['title'],chore['room'],chore['assignee_id'],next_due.isoformat(),chore['repeat'],user_id))
                else:
                    if chore['done']:
                        raise ApiError(409, 'Completed chores cannot be edited.')
                    values = self.chore_values(db, data, chore['household_id'])
                    values['id'] = chore['id']
                    db.execute('UPDATE chores SET title=:title,room=:room,assignee_id=:assignee_id,due=:due,repeat=:repeat WHERE id=:id', values)
                return dict(db.execute('SELECT * FROM chores WHERE id=?', (chore['id'],)).fetchone()), 200
        raise ApiError(404, 'Endpoint not found.')

    def chore_values(self, db, data, group_id):
        assignee = data.get('assignee_id') or None
        if assignee is not None:
            self.member(db, group_id, assignee)
        due = self.text(data, 'due', 10)
        if date.fromisoformat(due).isoformat() != due:
            raise ApiError(400, 'Use a valid date in YYYY-MM-DD format.')
        repeat = data.get('repeat', 'none')
        if repeat not in ('none', 'daily', 'weekly'):
            raise ApiError(400, 'Invalid repeat schedule.')
        return dict(title=self.text(data, 'title'), room=self.text(data, 'room', 40), assignee_id=assignee, due=due, repeat=repeat)

if __name__ == '__main__':
    init_db()
    port = int(os.environ.get('DWELL_PORT', '8080'))
    print(f'Dwell listening on 0.0.0.0:{port}', flush=True)
    ThreadingHTTPServer(('0.0.0.0', port), Handler).serve_forever()
