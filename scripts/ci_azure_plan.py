"""Run authenticated Terraform plans without publishing state/plan contents.
Author: Samuel Texa. The CI identity cannot modify workload resources.
"""
import argparse
import datetime
import json
import os
from pathlib import Path
import subprocess
import tempfile


def run(command):
    return subprocess.run(command, capture_output=True, text=True, check=False)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--stack', choices=['foundation', 'integrated'], required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    os.umask(0o077)
    summary = {'captured_at_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'configuration_commit': os.environ.get('GITHUB_SHA', 'operator-working-tree'), 'stack': args.stack, 'exit_code': 1, 'status': 'error', 'changes': {}, 'stage': 'configuration'}
    command = ['terraform', '-chdir=examples/' + args.stack]
    try:
        required = ['TFSTATE_ACCOUNT', 'TFSTATE_CONTAINER', 'TFSTATE_EXPECTED_LINEAGE', 'ARM_SUBSCRIPTION_ID']
        if not all(os.environ.get(key) for key in required):
            raise RuntimeError('Missing protected environment configuration')
        summary['stage'] = 'backend initialization'
        init = run(command + ['init', '-input=false', '-lockfile=readonly', '-reconfigure',
            '-backend-config=storage_account_name=' + os.environ['TFSTATE_ACCOUNT'],
            '-backend-config=container_name=' + os.environ['TFSTATE_CONTAINER'],
            '-backend-config=key=' + args.stack + '.tfstate'])
        if init.returncode:
            raise RuntimeError('Backend initialization failed')
        summary['stage'] = 'state identity'
        state = run(command + ['state', 'pull'])
        if state.returncode:
            raise RuntimeError('State read failed')
        document = json.loads(state.stdout)
        if document.get('lineage') != os.environ['TFSTATE_EXPECTED_LINEAGE']:
            raise RuntimeError('Unexpected state lineage')
        if not any(r.get('mode') == 'managed' and r.get('instances') for r in document.get('resources', [])):
            raise RuntimeError('Empty managed state')
        summary['stage'] = 'plan'
        with tempfile.TemporaryDirectory(prefix='infraforge-plan-') as tmp:
            plan_path = str(Path(tmp) / 'plan.tfplan')
            result = run(command + ['plan', '-input=false', '-no-color', '-detailed-exitcode', '-lock-timeout=60s', '-out=' + plan_path])
            if result.returncode not in (0, 2):
                raise RuntimeError('Terraform plan failed')
            rendered = run(command + ['show', '-json', plan_path])
            if rendered.returncode:
                raise RuntimeError('Plan inspection failed')
            plan = json.loads(rendered.stdout)
            changes = [r['change']['actions'] for r in plan.get('resource_changes', []) if r.get('mode') == 'managed']
            summary.update({
                'exit_code': result.returncode,
                'status': 'no_changes' if result.returncode == 0 else 'changes_detected',
                'changes': {action: sum(action in actions for actions in changes) for action in ['create', 'update', 'delete']},
                'state_drift_resources': len(plan.get('resource_drift', [])),
                'stage': 'complete',
            })
    except (OSError, ValueError, RuntimeError):
        # Provider/backend diagnostics can contain tenant IDs and credentials.
        # Publish only the failed stage; investigate privately with an operator.
        pass
    args.output.write_text(json.dumps(summary, indent=2) + '\n', encoding='utf-8')
    output = os.environ.get('GITHUB_OUTPUT')
    if output:
        with open(output, 'a', encoding='utf-8') as stream:
            stream.write('plan_exit_code=' + str(summary['exit_code']) + '\n')
    print(json.dumps(summary))
    return 1 if summary['exit_code'] == 1 else 0


if __name__ == '__main__':
    raise SystemExit(main())
