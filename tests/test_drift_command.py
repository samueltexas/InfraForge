"""Protect drift failure classification and non-mutating execution."""
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('drift', Path(__file__).resolve().parents[1] / 'scripts/check_drift.py')
drift = importlib.util.module_from_spec(spec)
spec.loader.exec_module(drift)


class DriftCommandTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.state = subprocess.CompletedProcess([], 0, json.dumps({
            'lineage': 'test-lineage',
            'resources': [{'mode': 'managed', 'instances': [{}]}],
        }), '')

    def test_drift_is_not_reported_as_failure_or_clean(self):
        with patch.object(drift.subprocess, 'run', side_effect=[self.state, subprocess.CompletedProcess([], 2, 'sensitive plan', '')]) as run:
            code, message = drift.check_drift(self.directory.name)
        self.assertEqual(code, 2)
        self.assertNotIn('sensitive plan', message)
        args = run.call_args.args[0]
        self.assertIn('-refresh-only', args)
        self.assertNotIn('apply', args)
        self.assertFalse(any(a.startswith('-out') or a == '-lock=false' for a in args))

    def test_plan_error_is_not_clean(self):
        with patch.object(drift.subprocess, 'run', side_effect=[self.state, subprocess.CompletedProcess([], 1, '', 'token')]):
            code, message = drift.check_drift(self.directory.name)
        self.assertEqual(code, 1)
        self.assertNotIn('token', message)

    def test_empty_state_stops_before_plan(self):
        with patch.object(drift.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, '{"lineage":"empty","resources":[]}', '')) as run:
            code, _ = drift.check_drift(self.directory.name)
        self.assertEqual(code, 1)
        self.assertEqual(run.call_count, 1)

    def test_unreadable_state_stops_before_plan(self):
        with patch.object(drift.subprocess, 'run', return_value=subprocess.CompletedProcess([], 1, '', 'secret')) as run:
            code, _ = drift.check_drift(self.directory.name)
        self.assertEqual(code, 1)
        self.assertEqual(run.call_count, 1)

    def test_clean_plan_is_success(self):
        with patch.object(drift.subprocess, 'run', side_effect=[self.state, subprocess.CompletedProcess([], 0, '', '')]):
            self.assertEqual(drift.check_drift(self.directory.name)[0], 0)
