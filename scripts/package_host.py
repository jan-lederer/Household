#!/usr/bin/env python3
"""Package the verified web build and API for a host without Flutter installed."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / 'build' / 'web'
for required in ('index.html', 'main.dart.js', 'flutter_bootstrap.js'):
    if not (WEB / required).is_file():
        raise SystemExit('Build the web client first: ./scripts/flutterw build web --release --no-web-resources-cdn')

FILES = {
'Dockerfile': '''FROM python:3.12-slim
WORKDIR /app
ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1 DWELL_PORT=8080 DWELL_DB=/data/dwell.sqlite DWELL_WEB=/app/web
COPY server.py /app/server.py
COPY web /app/web
VOLUME ["/data"]
EXPOSE 8080
CMD ["python", "server.py"]
''',
'compose.yaml': '''name: dwell
services:
  dwell:
    build: .
    restart: unless-stopped
    ports:
      - "${DWELL_BIND_ADDRESS:-0.0.0.0}:${DWELL_HOST_PORT:-8081}:8080"
    volumes:
      - dwell-data:/data
    healthcheck:
      test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8080/api/health', timeout=3)"]
      interval: 30s
      timeout: 5s
      retries: 3
volumes:
  dwell-data:
''',
'README.md': '''# Dwell host bundle

This bundle contains the built Flutter web app and the Python/SQLite API. No Flutter SDK or Python packages are required on your host.

## Python 3.11 or later

From the extracted `dwell-host` directory:

    DWELL_WEB=./web DWELL_DB=./data/dwell.sqlite python3 server.py

The API and browser app are available at http://localhost:8080. Verify http://localhost:8080/api/health returns `{"status": "ok", "service": "dwell"}`. The database is saved in `data/`; back it up with the server stopped, or use SQLite's backup API.

## Docker

    docker compose up --build -d
    docker compose ps

Docker publishes `0.0.0.0:8081` on your host and forwards it to port 8080 in the container. Open `http://<host-address>:8081`, using the same host address as Pocket Codex. Verify `http://127.0.0.1:8081/api/health` on the host. Port 8081 avoids the existing Dataset Management service on 8080. Override `DWELL_HOST_PORT` and `DWELL_BIND_ADDRESS` with environment variables or a local `.env` file.

SQLite persists in the named `dwell-data` volume. A Python-based container healthcheck checks the API. The container build configuration is provided; it has not been executed in the development environment because no Dwell Docker target is configured.

## Connect your phone

Install the Dwell APK. Open “Set up server connection” on the welcome screen and enter your host's LAN URL, for example http://192.168.1.20:8081 for Docker (8080 for the direct Python command). Both devices must be able to reach that address. Use HTTPS via a reverse proxy for a public server. The web app needs HTTPS or localhost for secure browser storage. Android supports local HTTP for home networks.

Create an account, create a household, and share the invite code shown on the Household tab. Each housemate creates their own account and joins with that code. Daily and weekly chores create their next occurrence on completion.

“Explore a demo home” is a temporary preview; demo edits are not saved to the server. The Android package is a release build signed with a development key. Configure your production signing key before store distribution.
'''
}
output = ROOT / 'artifacts' / 'dwell-host.zip'
output.parent.mkdir(exist_ok=True)
with ZipFile(output, 'w', ZIP_DEFLATED) as bundle:
    bundle.write(ROOT / 'backend' / 'server.py', 'dwell-host/server.py')
    for path in WEB.rglob('*'):
        if path.is_file():
            bundle.write(path, 'dwell-host/web/' + path.relative_to(WEB).as_posix())
    for name, content in FILES.items():
        bundle.writestr('dwell-host/' + name, content)
with ZipFile(output) as bundle:
    assert bundle.testzip() is None
    print(f'Verified {output.relative_to(ROOT)}: {len(bundle.namelist())} files, {output.stat().st_size:,} bytes')
