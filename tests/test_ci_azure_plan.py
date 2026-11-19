"""Guard against empty-state plans and disclosure through CI summaries."""
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('ci_plan', Path(__file__).resolve().parents[1] / 'scripts/ci_azure_plan.py')
ci = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ci)


class AzurePlanSafetyTests(unittest.TestCase):
    def execute(self, responses):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'summary.json'
            env = {'TFSTATE_ACCOUNT':'test','TFSTATE_CONTAINER':'test', 'TFSTATE_EXPECTED_LINEAGE':'expected', 'ARM_SUBSCRIPTION_ID':'test'}
            with patch.dict(os.environ, env, clear=True), patch('sys.argv', ['ci_plan','--stack','foundation','--output',str(path)]), patch.object(ci, 'run', side_effect=responses) as run, contextlib.redirect_stdout(io.StringIO()) as output:
                result = ci.main()
            return result, json.loads(path.read_text()), output.getvalue(), run.call_args_list

    def response(self, code=0, body=''):
        return subprocess.CompletedProcess([],code,body,'private-error-details')

    def state(self, lineage='expected', resources=None):
        return self.response(body=json.dumps({'lineage':lineage,'resources': resources if resources is not None else [{'mode':'managed','instances':[{}]}]}))

    def test_wrong_lineage_prevents_plan(self):
        result, report, _, calls = self.execute([self.response(), self.state('wrong')])
        self.assertEqual(result,1)
        self.assertEqual(report['stage'],'state identity')
        self.assertEqual(len(calls),2)

    def test_empty_state_prevents_plan(self):
        result, _, _, calls = self.execute([self.response(), self.state(resources=[])])
        self.assertEqual(result,1)
        self.assertEqual(len(calls),2)

    def test_backend_error_does_not_publish_diagnostics(self):
        result, report, output, _ = self.execute([self.response(1,'private-subscription-id')])
        self.assertEqual(result,1)
        self.assertEqual(report['exit_code'],1)
        self.assertNotIn('private-',output)

    def test_changes_are_counted_without_state_values(self):
        plan = {'resource_changes':[{'mode':'managed','change':{'actions':['delete','create'],'before':{'secret':'sensitive-value'}}}]}
        result, report, output, calls = self.execute([self.response(),self.state(),self.response(2),self.response(body=json.dumps(plan))])
        self.assertEqual(result,0)
        self.assertEqual(report['exit_code'],2)
        self.assertEqual(report['changes'],{'create':1,'update':0,'delete':1})
        self.assertNotIn('sensitive-value',output)
        for call in calls:
            self.assertNotIn('apply',call.args[0])
            self.assertNotIn('-lock=false',call.args[0])
