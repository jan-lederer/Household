#!/usr/bin/env python3
"""One-time host registration, then health-verified deployment via pocket-docker's worker.

Run on the Docker HOST: python3 Household/scripts/deploy_host.py
The app container cannot edit the host's private worker allowlist.
"""
import argparse
import json
from pathlib import Path
import shutil
import socket
import subprocess
import time
import urllib.request

ROOT = Path(__file__).resolve().parents[1]


def request(socket_path, action, **fields):
    with socket.socket(socket.AF_UNIX) as client:
        client.settimeout(45)
        client.connect(str(socket_path))
        client.sendall(json.dumps({'action': action, **fields}).encode() + b'\n')
        with client.makefile('rb') as stream:
            response = json.loads(stream.readline(1024 * 1024))
    if not response.get('ok'):
        raise RuntimeError(response.get('error', 'Host worker rejected the request.'))
    return response['result']


def target_for(root, port):
    return {'directory': str(root), 'project': 'dwell',
            'files': [str(root / 'compose.yaml'), str(root / 'compose.host.yaml')],
            'services': ['dwell'], 'health': [{'url': f'http://127.0.0.1:{port}/api/health'}]}


def updated_config(config, root, port):
    updated = json.loads(json.dumps(config))
    previous = updated.setdefault('targets', {}).get('dwell')
    if previous and previous.get('directory') != str(root):
        raise RuntimeError('A Dwell target already points at another directory; nothing changed.')
    updated['targets']['dwell'] = target_for(root, port)
    return updated


def save_json(path, value):
    temporary = path.with_name(path.name + '.dwell.tmp')
    temporary.write_text(json.dumps(value, indent=2) + '\n')
    temporary.chmod(0o600)
    temporary.replace(path)


def wait_for_job(socket_path, job, artifacts, port, bind):
    # Persist the accepted job before waiting, so interruptions are recoverable.
    save_json(artifacts / 'deployment-job.json', job)
    last_status = None
    deadline = time.monotonic() + 1200
    while time.monotonic() < deadline:
        current = request(socket_path, 'job', id=job['id'])
        if current['status'] != last_status:
            print(f"Deployment {job['id']}: {current['status']}", flush=True)
            last_status = current['status']
        if current['status'] in ('failed', 'interrupted'):
            save_json(artifacts / 'deployment-result.json', current)
            raise RuntimeError(current.get('error', 'Deployment did not succeed. Inspect the host job logs.'))
        if current['status'] == 'succeeded':
            state = request(socket_path, 'status', target='dwell')
            mappings = [p for c in state.get('containers', []) for p in c.get('Publishers', [])]
            if not any(str(p['PublishedPort']) == str(port) and p['TargetPort'] == 8080 and p['URL'] == bind for p in mappings):
                raise RuntimeError('The requested host port mapping was not found.')
            with urllib.request.urlopen(f'http://127.0.0.1:{port}/api/health', timeout=5) as response:
                health = json.load(response)
            if health != {'status': 'ok', 'service': 'dwell'}:
                raise RuntimeError('Dwell health response did not match.')
            result = {'job': current, 'containers': state, 'health': health,
                      'address': f'http://<same-host-as-pocket-codex>:{port}'}
            save_json(artifacts / 'deployment-result.json', result)
            print(f'Verified Dwell at http://<same-host-as-pocket-codex>:{port}', flush=True)
            return result
        time.sleep(2)
    raise RuntimeError(f"Job still pending. Resume with pocket-docker job {job['id']}.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', type=int, default=8081)
    parser.add_argument('--bind-address', choices=['0.0.0.0', '127.0.0.1'], default='0.0.0.0')
    args = parser.parse_args()
    if not 1024 <= args.port <= 65535:
        parser.error('Use a port from 1024 to 65535.')
    if Path('/.dockerenv').exists():
        parser.exit(1, 'Run this script on the Docker host, not inside the app container.\n')
    config_path = Path.home() / '.config/pocket-codex-host-control/config.json'
    if not config_path.is_file():
        parser.exit(1, 'Pocket Codex host worker config was not found for this user.\n')
    if not (ROOT / 'build/web/main.dart.js').is_file():
        parser.exit(1, 'Build the web client before deployment; see README.md.\n')
    config = json.loads(config_path.read_text())
    socket_path = config['socket']
    active = request(socket_path, 'jobs').get('jobs', [])
    if any(j['status'] in ('queued', 'running') for j in active):
        parser.exit(1, 'A host Docker job is active. Retry after it finishes; nothing changed.\n')
    updated = updated_config(config, ROOT, args.port)
    env_path = ROOT / '.env'
    env_lines = env_path.read_text().splitlines() if env_path.exists() else []
    env_lines = [line for line in env_lines if not line.startswith(('DWELL_HOST_PORT=', 'DWELL_BIND_ADDRESS='))]
    env_lines.extend([f'DWELL_HOST_PORT={args.port}', f'DWELL_BIND_ADDRESS={args.bind_address}'])
    env_path.write_text('\n'.join(env_lines) + '\n')
    backup = config_path.with_suffix('.json.before-dwell')
    if not backup.exists():
        shutil.copy2(config_path, backup)
    save_json(config_path, updated)
    subprocess.run(['systemctl', '--user', 'restart', 'pocket-codex-host-control.service'], check=True)
    for attempt in range(50):
        try:
            targets = request(socket_path, 'list')['targets']
            if any(t['name'] == 'dwell' for t in targets):
                break
        except (OSError, RuntimeError):
            pass
        if attempt == 49:
            raise RuntimeError('Host worker did not load Dwell. Inspect its systemd journal.')
        time.sleep(.1)
    artifacts = ROOT / 'artifacts'
    artifacts.mkdir(exist_ok=True)
    job = request(socket_path, 'deploy', target='dwell')
    wait_for_job(socket_path, job, artifacts, args.port, args.bind_address)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        raise SystemExit(str(error))
