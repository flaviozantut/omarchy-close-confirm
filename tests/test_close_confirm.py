#!/usr/bin/env python3
"""Run only with fake desktop commands; no compositor connection is used."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / 'bin/omarchy-close-confirm'
STUB = '''#!/usr/bin/python3
import json, os, pathlib, signal, sys, time
root = pathlib.Path(os.environ['FAKE_DESKTOP'])
state = json.loads((root / 'state.json').read_text())
kind = 'prompt' if pathlib.Path(sys.argv[0]).name == 'omarchy-shell' else sys.argv[1]
if state.get('hang') == kind:
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
    time.sleep(10)
if state.get('fail') == kind: sys.exit(1)
if kind == 'activewindow': print(json.dumps(state['window']))
elif kind == 'clients': print(state['raw_clients'] if 'raw_clients' in state else json.dumps(state['clients']))
elif kind == 'prompt': (root / 'prompt.json').write_text(sys.argv[-1])
elif kind == 'dispatch':
    with (root / 'dispatch.jsonl').open('a') as f: f.write(json.dumps(sys.argv[2:]) + '\\n')
else: sys.exit(2)
'''


class HelperTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.tmp = Path(self.temp.name)
        for name in ['hyprctl', 'omarchy-shell']:
            p = self.tmp / name
            p.write_text(STUB)
            p.chmod(0o755)
        # Exercise real /proc parsing, including a comm containing parentheses.
        self.owner = subprocess.Popen([sys.executable, '-c',
            "import ctypes,time;ctypes.CDLL(None).prctl(15,b'odd ) name (');print('ready',flush=True);time.sleep(60)"],
            stdout=subprocess.PIPE, text=True)
        self.owner.stdout.readline()
        self.addCleanup(self.stop_owner)
        self.started = Path(f'/proc/{self.owner.pid}/stat').read_text().rsplit(') ', 1)[1].split()[19]
        self.window = {'address': '0xabc', 'pid': self.owner.pid, 'title': 'original window'}
        self.state = {'window': self.window, 'clients': [self.window]}
        self.env = dict(os.environ, PATH=str(self.tmp) + ':' + os.environ['PATH'], FAKE_DESKTOP=str(self.tmp))

    def stop_owner(self):
        self.owner.terminate()
        self.owner.wait()
        self.owner.stdout.close()

    def run_helper(self, *args):
        (self.tmp / 'state.json').write_text(json.dumps(self.state))
        return subprocess.run(['bash', str(HELPER), *map(str, args)], env=self.env,
                              capture_output=True, text=True, timeout=8)

    def approve(self, **changes):
        target = dict(address='0xabc', pid=self.owner.pid, started=self.started)
        target.update(changes)
        return self.run_helper('--close', target['address'], target['pid'], target['started'])

    def no_dispatch(self):
        self.assertFalse((self.tmp / 'dispatch.jsonl').exists())

    def test_capture_and_approve_original_target_after_focus_changes(self):
        self.assertEqual(self.run_helper().returncode, 0)
        payload = json.loads((self.tmp / 'prompt.json').read_text())
        self.assertEqual(payload, dict(self.window, started=self.started))
        self.assertIsInstance(payload['started'], str)
        self.state['window'] = {'address': '0xdef', 'pid': 1, 'title': 'other window'}
        self.assertEqual(self.approve().returncode, 0)
        commands = [json.loads(line) for line in (self.tmp / 'dispatch.jsonl').read_text().splitlines()]
        self.assertEqual(commands, [['hl.dsp.window.close({ window = "address:0xabc" })']])

    def test_missing_replaced_duplicate_or_malformed_clients_do_not_close(self):
        for clients in [[], [dict(self.window, pid=self.owner.pid + 1)], [self.window, self.window], {}, [None]]:
            with self.subTest(clients=clients):
                self.state['clients'] = clients
                self.assertNotEqual(self.approve().returncode, 0)
                self.no_dispatch()
        self.state['raw_clients'] = 'not json'
        self.assertNotEqual(self.approve().returncode, 0)
        self.no_dispatch()

    def test_changed_or_missing_process_does_not_close(self):
        self.assertNotEqual(self.approve(started=str(int(self.started) + 1)).returncode, 0)
        self.owner.terminate()
        self.owner.wait()
        self.assertNotEqual(self.approve().returncode, 0)
        self.no_dispatch()

    def test_invalid_tuple_and_shell_syntax_are_rejected(self):
        for changes in [dict(address='0xabc; touch /tmp/injected'), dict(address=''),
                        dict(pid='0'), dict(pid='-1'), dict(pid='1; true'),
                        dict(started='1; true'), dict(started='')]:
            with self.subTest(changes=changes):
                self.assertNotEqual(self.approve(**changes).returncode, 0)
                self.no_dispatch()
        self.assertNotEqual(self.run_helper('--close', '0xabc').returncode, 0)
        self.assertNotEqual(self.run_helper('unexpected').returncode, 0)
        self.no_dispatch()

    def test_failed_or_hung_queries_never_dispatch(self):
        for mode in ['fail', 'hang']:
            with self.subTest(mode=mode):
                self.state = {'window': self.window, 'clients': [self.window], mode: 'clients'}
                self.assertNotEqual(self.approve().returncode, 0)
                self.no_dispatch()
        self.state = {'window': self.window, 'clients': [self.window], 'fail': 'dispatch'}
        self.assertNotEqual(self.approve().returncode, 0)
        self.no_dispatch()

    def test_empty_or_unverifiable_capture_never_opens_dialog(self):
        for window in [{}, dict(self.window, pid=0), dict(self.window, pid=999999999),
                       dict(self.window, address='bad')]:
            with self.subTest(window=window):
                self.state['window'] = window
                self.run_helper()
                self.assertFalse((self.tmp / 'prompt.json').exists())
        self.state = {'window': self.window, 'clients': [self.window], 'hang': 'activewindow'}
        self.assertNotEqual(self.run_helper().returncode, 0)
        self.assertFalse((self.tmp / 'prompt.json').exists())


if __name__ == '__main__':
    unittest.main()
