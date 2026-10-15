import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('deploy_host', Path(__file__).with_name('deploy_host.py'))
deploy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(deploy)


class HostDeploymentTests(unittest.TestCase):
    def test_registration_preserves_existing_targets_and_uses_host_paths(self):
        original = {'socket': '/private/docker.sock', 'targets': {'pocket-codex': {'project': 'pocket-codex'}}}
        root = Path('/host/projects/Household')
        updated = deploy.updated_config(original, root, 8081)
        self.assertEqual(updated['targets']['pocket-codex'], original['targets']['pocket-codex'])
        self.assertNotIn('dwell', original['targets'])
        self.assertEqual(updated['targets']['dwell']['files'], [str(root / 'compose.yaml'), str(root / 'compose.host.yaml')])
        self.assertEqual(updated['targets']['dwell']['health'], [{'url': 'http://127.0.0.1:8081/api/health'}])

    def test_registration_refuses_to_replace_another_dwell_project(self):
        with self.assertRaisesRegex(RuntimeError, 'another directory'):
            deploy.updated_config({'targets': {'dwell': {'directory': '/other/project'}}}, Path('/host/Household'), 8081)

    def test_success_requires_persisted_job_mapping_and_actual_health(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            calls = []
            def request(socket_path, action, **fields):
                self.assertTrue((folder / 'deployment-job.json').is_file())
                calls.append(action)
                if action == 'job':
                    return {'id': 'test-job', 'status': 'succeeded'}
                return {'containers': [{'Publishers': [{'PublishedPort': 8081, 'TargetPort': 8080, 'URL': '0.0.0.0'}]}]}
            with patch.object(deploy, 'request', side_effect=request), patch.object(deploy.urllib.request, 'urlopen') as urlopen:
                urlopen.return_value.__enter__.return_value.read.return_value = b'{"status":"ok","service":"dwell"}'
                result = deploy.wait_for_job('/socket', {'id': 'test-job', 'status': 'queued'}, folder, 8081, '0.0.0.0')
            self.assertEqual(calls, ['job', 'status'])
            self.assertEqual(result['health']['status'], 'ok')
            self.assertTrue((folder / 'deployment-result.json').is_file())

    def test_failed_job_is_reported_without_health_claim(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            with patch.object(deploy, 'request', return_value={'id': 'test-job', 'status': 'failed', 'error': 'Build failed'}), patch.object(deploy.urllib.request, 'urlopen') as health:
                with self.assertRaisesRegex(RuntimeError, 'Build failed'):
                    deploy.wait_for_job('/socket', {'id': 'test-job'}, folder, 8081, '0.0.0.0')
                health.assert_not_called()
            self.assertEqual(json.loads((folder / 'deployment-result.json').read_text())['status'], 'failed')

    def test_wrong_host_binding_cannot_be_reported_as_success(self):
        with tempfile.TemporaryDirectory() as temporary:
            replies = [{'id': 'test-job', 'status': 'succeeded'}, {'containers': [{'Publishers': [{'PublishedPort': 8081, 'TargetPort': 8080, 'URL': '127.0.0.1'}]}]}]
            with patch.object(deploy, 'request', side_effect=replies), patch.object(deploy.urllib.request, 'urlopen') as health:
                with self.assertRaisesRegex(RuntimeError, 'mapping was not found'):
                    deploy.wait_for_job('/socket', {'id': 'test-job'}, Path(temporary), 8081, '0.0.0.0')
                health.assert_not_called()


if __name__ == '__main__':
    unittest.main()
