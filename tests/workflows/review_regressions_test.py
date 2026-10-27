#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
"""Workflow/migration regression checks. Requires Python 3 and PyYAML."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[2]
WORKFLOWS = ROOT / '.github/workflows'
MIGRATOR = ROOT / 'scripts/migrate-wellknown-to-www.sh'


def workflow(name):
    # BaseLoader preserves the GitHub Actions `on` key as a string.
    return yaml.load((WORKFLOWS / f'{name}.yml').read_text(), Loader=yaml.BaseLoader)


def step(name, job, label):
    return next(s for s in workflow(name)['jobs'][job]['steps'] if s.get('name') == label)


def run(script, cwd, **extra_env):
    return subprocess.run(['bash', '-e', '-o', 'pipefail', '-c', script], cwd=cwd,
                          env={**os.environ, **extra_env}, text=True, capture_output=True)


class WorkflowTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.cwd = Path(self.temp.name)
        self.bin = self.cwd / 'bin'
        self.bin.mkdir()
        self.env = {'PATH': f'{self.bin}:{os.environ["PATH"]}',
                    'RUNNER_TEMP': str(self.cwd), 'GITHUB_OUTPUT': str(self.cwd / 'output')}

    def stub(self, name, body):
        path = self.bin / name
        path.write_text('#!/usr/bin/env bash\n' + body + '\n')
        path.chmod(0o755)

    def test_yaml_bash_and_lockfile_coverage(self):
        lock = yaml.safe_load((WORKFLOWS / 'actions.lock').read_text())
        for path in sorted(WORKFLOWS.glob('*.yml')):
            with self.subTest(workflow=path.name):
                data = yaml.load(path.read_text(), Loader=yaml.BaseLoader)
                for job in data['jobs'].values():
                    for item in job.get('steps', []):
                        if 'run' in item:
                            result = subprocess.run(['bash', '-n'], input=item['run'],
                                                    text=True, capture_output=True)
                            self.assertEqual(result.returncode, 0, result.stderr)
                        if 'uses' in item and not item['uses'].startswith('./'):
                            owner_repo, ref = item['uses'].split('@')
                            dependency = '/'.join(owner_repo.split('/')[:2]) + '@' + ref
                            self.assertIn(dependency, lock['workflows'][str(path.relative_to(ROOT))])
                            self.assertIn(dependency, lock['dependencies'])
        for path in [MIGRATOR, ROOT / 'scripts/update-actions-lock.sh']:
            self.assertEqual(subprocess.run(['bash', '-n', str(path)]).returncode, 0)

    def test_requested_headers_and_security_trigger(self):
        for name in ['dot-wellknown-enforcement', 'governance', 'hypatia-scan', 'mirror',
                     'release', 'scorecard', 'secret-scanner', 'static-analysis-gate']:
            self.assertEqual((WORKFLOWS / f'{name}.yml').read_text().splitlines()[:2],
                             ['# SPDX-License-Identifier: MPL-2.0',
                              '# This workflow is managed by gh actions-lock.'])
        triggers = workflow('dot-wellknown-enforcement')['on']
        self.assertEqual(triggers['push']['paths'], triggers['pull_request']['paths'])
        self.assertIn('security.txt', triggers['pull_request']['paths'])

    def test_security_expiry(self):
        script = step('dot-wellknown-enforcement', 'validate',
                      'RFC 9116 security.txt validation')['run']
        sectxt = self.cwd / 'www/.well-known/security.txt'
        sectxt.parent.mkdir(parents=True)
        # Fix the clock while allowing real date parsing, including parse errors.
        date = shutil.which('date')
        self.stub('date', f'if [[ "$*" == +%s ]]; then echo 1893456000; else exec "{date}" "$@"; fi')
        cases = [
            ('2030-01-01T00:00:00Z', 1, 'EXPIRED'),
            ('2029-12-31T23:59:59Z', 1, 'EXPIRED'),
            ('2029-12-31T12:00:00Z', 1, 'EXPIRED'),
            ('2030-01-01T00:00:01Z', 0, 'expires in 0 days'),
            ('2030-01-02T00:00:00Z', 0, 'expires in 1 days'),
            ('2030-02-01T00:00:00Z', 0, 'valid (31 days)'),
            ('2030-01-02T01:00:00+01:00', 0, 'expires in 1 days'),
            ('2030-01-02t00:00:00.5z', 0, 'expires in 1 days'),
        ]
        for expires in ['', 'tomorrow', '2030-02-01', '2030-02-01 00:00:00Z',
                        '2030-02-01T00:00:00', '2030-02-30T00:00:00Z',
                        '2030-02-01T24:00:00Z', '2030-02-01T00:00:00+24:00',
                        '2030-02-01T00:00:00+01:60', '2030-02-01T0 0:00:00Z']:
            cases.append((expires, 1, 'valid RFC 3339'))
        for expires, code, message in cases:
            with self.subTest(expires=expires):
                sectxt.write_text(f'Contact: mailto:security@example.invalid\nExpires: {expires}\n')
                result = run(script, self.cwd, **self.env)
                self.assertEqual(result.returncode, code, result.stdout + result.stderr)
                self.assertIn(message, result.stdout)
        # A date implementation failure must fail even for correctly shaped input.
        self.stub('date', 'exit 2')
        sectxt.write_text('Contact: mailto:security@example.invalid\nExpires: 2030-02-01T00:00:00Z\n')
        self.assertNotEqual(run(script, self.cwd, **self.env).returncode, 0)

    def test_triage_failure_and_report_schema(self):
        script = step('static-analysis-gate', 'patch-bridge-triage', 'Run Patch Bridge triage')['run']
        report = {'cves': [], 'mitigated': 0, 'unmitigable': 2, 'concatenative': 0, 'informational': 1}
        self.stub('panic-attack', 'printf "%s" "$REPORT"; echo diagnostic >&2; exit "$STATUS"')
        for payload, status, valid in [
            (json.dumps(report), '0', True), (json.dumps(report), '7', False),
            ('', '0', False), ('{', '0', False), ('{}', '0', False),
            ('null', '0', False), ('[]', '0', False),
            (json.dumps({**report, 'cves': None}), '0', False),
            (json.dumps({**report, 'unmitigable': -1}), '0', False),
            (json.dumps({**report, 'unmitigable': '0'}), '0', False),
            (json.dumps({**report, 'unmitigable': 0.5}), '0', False),
        ]:
            with self.subTest(payload=payload, status=status):
                output = self.cwd / 'output'
                output.unlink(missing_ok=True)
                result = run(script, self.cwd, **self.env, REPORT=payload, STATUS=status)
                self.assertEqual(result.returncode == 0, valid, result.stdout + result.stderr)
                self.assertEqual((self.cwd / 'bridge-report.json').read_text(), payload)
                if valid:
                    self.assertIn('unmitigable=2', output.read_text())
                else:
                    self.assertIn('diagnostic', result.stderr)
                    self.assertFalse(output.exists())
                if status == '7':
                    self.assertEqual(result.returncode, 7)

    def test_secret_assignments_and_original_formats(self):
        script = step('secret-scanner', 'shell-secrets', 'Run repository secret pattern hook')['run']
        subprocess.run(['git', 'init', '-q', str(self.cwd)], check=True)
        fixture = self.cwd / 'fixture.sh'
        positives = [
            'MY_TOKEN=abcdefghij0123456789ABCD', 'export MY_API_KEY="abcdefghij0123456789ABCD"',
            "MY_SECRET = 'abcdefghij0123456789ABCD'", 'PASSWORD="abcdefghij0123456789ABCD"',
            '"MY_TOKEN": "abcdefghij0123456789ABCD",',
            'PASSWORD="a long password with spaces !@#%&*()"',
            "SERVICE_SECRET='very!@#%&*(),?:complex-secret'",
            '"PASSWORD": "abcdefghij0123456789ABCD"',
            'ghp_' + 'A' * 36, 'github_pat_' + 'A' * 82,
            'glpat-' + 'A' * 20, 'AKIA' + 'A' * 16, '-----BEGIN PRIVATE KEY-----',
            '-----BEGIN RSA PRIVATE KEY-----', '-----BEGIN EC PRIVATE KEY-----',
            '-----BEGIN OPENSSH PRIVATE KEY-----',
        ]
        negatives = ['MY_TOKEN="$OTHER_TOKEN"', 'MY_SECRET=${OTHER_SECRET}', 'PASSWORD="short"',
                     'NOTPASSWORD=abcdefghij0123456789ABCD', 'MY_TOKEN="${{ secrets.MY_TOKEN }}"',
                     'MY_API_KEY=$(read_secret)', 'ordinary=abcdefghij0123456789ABCD']
        for literal, expected in [(s, 1) for s in positives] + [(s, 0) for s in negatives]:
            with self.subTest(literal=literal):
                fixture.write_text(literal + '\n')
                subprocess.run(['git', 'add', 'fixture.sh'], cwd=self.cwd, check=True)
                result = run(script, self.cwd, **self.env)
                self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
                if expected:
                    self.assertNotIn(literal, result.stdout)  # Filenames only; no secret contents.
        fixture.unlink()
        subprocess.run(['git', 'rm', '-q', '--cached', 'fixture.sh'], cwd=self.cwd, check=True)
        ignored = self.cwd / 'tests/intentional.sh'
        ignored.parent.mkdir()
        ignored.write_text(positives[0])
        subprocess.run(['git', 'add', 'tests'], cwd=self.cwd, check=True)
        self.assertEqual(run(script, self.cwd, **self.env).returncode, 0)

    def test_sarif_condition_preserves_non_pr_events(self):
        condition = step('hypatia-scan', 'hypatia',
                         'Upload Hypatia SARIF to GitHub Code Scanning')['if']
        for event in ['push', 'schedule', 'workflow_dispatch', 'pull_request']:
            for same_repo in [True, False]:
                for actor in ['contributor', 'dependabot[bot]']:
                    expression = condition.replace('github.event_name', repr(event))
                    expression = expression.replace('github.event.pull_request.head.repo.full_name',
                                                    repr('owner/repo' if same_repo else 'fork/repo'))
                    expression = expression.replace('github.repository', repr('owner/repo'))
                    expression = expression.replace('github.actor', repr(actor))
                    actual = eval(expression.replace('||', ' or ').replace('&&', ' and '),
                                  {'__builtins__': {}})
                    self.assertEqual(actual, event != 'pull_request' or
                                     (same_repo and actor != 'dependabot[bot]'))

    def test_release_artifact_flow(self):
        upload = step('release', 'build', 'Upload build artifacts')
        download = step('release', 'release', 'Download build artifacts')
        attest = step('release', 'release', 'Attest build provenance')
        publish = step('release', 'release', 'Create GitHub Release')
        self.assertEqual(upload['with']['name'], download['with']['name'])
        self.assertEqual(upload['with']['if-no-files-found'], 'error')
        self.assertNotIn('if', attest)
        self.assertEqual(attest['with']['subject-path'], publish['with']['files'])
        self.assertTrue(attest['with']['subject-path'].startswith(download['with']['path']))
        steps = workflow('release')['jobs']['release']['steps']
        self.assertLess(steps.index(download), steps.index(attest))
        self.assertLess(steps.index(attest), steps.index(publish))
        # Execute the repository's Justfile branch and inspect its output selection.
        (self.cwd / 'Justfile').write_text('')
        self.stub('just', 'mkdir -p src/interface/ffi/zig-out/lib; echo synthetic > src/interface/ffi/zig-out/lib/libtest.a')
        result = run(step('release', 'build', 'Detect project type and build')['run'], self.cwd, **self.env)
        self.assertEqual(result.returncode, 0, result.stderr)
        outputs = dict(line.split('=', 1) for line in (self.cwd / 'output').read_text().splitlines())
        self.assertTrue((self.cwd / outputs['artifact_path'] / 'lib/libtest.a').is_file())
        self.assertEqual(upload['with']['path'], '${{ steps.build.outputs.artifact_path }}')

    def test_lock_update_restores_headers(self):
        scripts = self.cwd / 'scripts'
        scripts.mkdir()
        shutil.copy(ROOT / 'scripts/update-actions-lock.sh', scripts)
        directory = self.cwd / '.github/workflows'
        directory.mkdir(parents=True)
        target = directory / 'governance.yml'
        source = (WORKFLOWS / 'governance.yml').read_text()
        target.write_text(source)
        self.stub('gh', '''[[ "$1" == actions-lock ]] || exit 2
python3 - <<'CODE'
from pathlib import Path
p = Path('.github/workflows/governance.yml')
p.write_text('# This workflow is managed by gh actions-lock.\\n' + p.read_text())
CODE''')
        # Isolate the fake gh command from interactive shell startup hooks.
        self.env['BASH_ENV'] = '/dev/null'
        for _ in range(2):
            result = run('bash scripts/update-actions-lock.sh', self.cwd, **self.env)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(target.read_text(), source)
        self.stub('gh', 'exit 9')
        self.assertEqual(run('bash scripts/update-actions-lock.sh', self.cwd, **self.env).returncode, 9)


class MigrationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.cwd = Path(self.temp.name)
        self.legacy = self.cwd / '.well-known'
        self.legacy.mkdir()
        self.dest = self.cwd / 'www/.well-known'

    def migrate(self, *args):
        return subprocess.run(['bash', str(MIGRATOR), *args], cwd=self.cwd,
                              text=True, capture_output=True)

    def test_root_only_and_identical_tracked_files(self):
        subprocess.run(['git', 'init', '-q', str(self.cwd)], check=True)
        self.dest.mkdir(parents=True)
        (self.legacy / 'security.txt').write_text('canonical content\n')
        (self.dest / 'security.txt').write_text('canonical content\n')
        (self.legacy / 'humans.txt').write_text('people\n')
        subprocess.run(['git', 'add', '.'], cwd=self.cwd, check=True)
        subprocess.run(['git', '-c', 'user.name=Fixture', '-c',
                        'user.email=fixture@example.invalid', 'commit', '-qm', 'fixture'],
                       cwd=self.cwd, check=True)
        result = self.migrate()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.legacy.exists())
        self.assertEqual((self.dest / 'security.txt').read_text(), 'canonical content\n')
        self.assertEqual((self.dest / 'humans.txt').read_text(), 'people\n')

    def test_symlinks_are_explicit_errors_even_in_dry_run(self):
        (self.cwd / 'target.txt').write_text('security contact\n')
        for target in ['../target.txt', '../missing.txt', '.', str(self.cwd / 'target.txt')]:
            for options in [(), ('--dry-run',)]:
                with self.subTest(target=target, options=options):
                    link = self.legacy / 'security.txt'
                    link.symlink_to(target)
                    result = self.migrate(*options, '--report', 'report.tsv')
                    self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
                    self.assertIn('symbolic links are unsupported', result.stderr)
                    self.assertIn('left\tsecurity.txt', (self.cwd / 'report.tsv').read_text())
                    self.assertTrue(link.is_symlink())
                    self.assertEqual((self.cwd / 'target.txt').read_text(), 'security contact\n')
                    link.unlink()
        self.legacy.rmdir()
        self.legacy.symlink_to('missing')
        self.assertEqual(self.migrate().returncode, 2)

    def test_divergence_contract_and_dry_run(self):
        self.dest.mkdir(parents=True)
        source = self.legacy / 'security.txt'
        canonical = self.dest / 'security.txt'
        source.write_text('legacy\n')
        canonical.write_text('canonical\n')
        result = self.migrate('--dry-run')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(source.read_text(), 'legacy\n')
        self.assertFalse(list((self.cwd / 'www').glob('.legacy-*')))
        self.assertEqual(self.migrate('--in-place').returncode, 1)
        self.assertEqual(source.read_text(), 'legacy\n')
        result = self.migrate('--strict')
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(canonical.read_text(), 'canonical\n')
        quarantined = list((self.cwd / 'www').glob('.legacy-*/security.txt'))
        self.assertEqual(len(quarantined), 1)
        self.assertEqual(quarantined[0].read_text(), 'legacy\n')
        self.assertFalse(self.legacy.exists())

    def test_destination_symlink_is_preserved(self):
        self.dest.mkdir(parents=True)
        (self.legacy / 'security.txt').write_text('legacy\n')
        link = self.dest / 'security.txt'
        link.symlink_to('missing')
        self.assertEqual(self.migrate().returncode, 2)
        self.assertTrue(link.is_symlink())
        self.assertTrue((self.legacy / 'security.txt').exists())


if __name__ == '__main__':
    unittest.main(verbosity=2)
