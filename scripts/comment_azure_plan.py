"""Publish only redacted plan counts to an authorized PR. Author: Samuel Texa."""
import json
import os
from pathlib import Path
import re
import subprocess
import sys

report = json.loads(Path(sys.argv[1]).read_text())
stack = report['stack']
assert stack in ('foundation', 'integrated')
repo = os.environ['GITHUB_REPOSITORY']
number = os.environ['PR_NUMBER']
sha = os.environ['PR_HEAD_SHA']
assert number.isdigit() and re.fullmatch(r'[0-9a-f]{40}', sha)
marker = '<!-- infraforge-azure-plan-' + stack + ' -->'
changes = report['changes']
body = '\n'.join([
    marker, '### Azure plan: ' + stack,
    'Commit: `' + sha + '`',
    'Result: **' + report['status'] + '** (stage: ' + report['stage'] + ').',
    'Managed resource actions: ' + ', '.join(k + '=' + str(changes.get(k, 0)) for k in ['create', 'update', 'delete']) + '.',
    'Refreshed state differences (not necessarily planned actions): ' + str(report.get('state_drift_resources', 0)) + '.',
    'Authenticated through OIDC; no apply performed. Raw plans, state and resource identifiers are not published.',
    '[Workflow run](' + os.environ['GITHUB_SERVER_URL'] + '/' + repo + '/actions/runs/' + os.environ['GITHUB_RUN_ID'] + ')',
])
comments = json.loads(subprocess.check_output(['gh', 'api', 'repos/' + repo + '/issues/' + number + '/comments', '--paginate', '--slurp'], text=True))
existing = next((c for page in comments for c in page if c['user']['login'] == 'github-actions[bot]' and marker in c.get('body', '')), None)
endpoint = 'repos/' + repo + ('/issues/comments/' + str(existing['id']) if existing else '/issues/' + number + '/comments')
subprocess.run(['gh', 'api', '--method', 'PATCH' if existing else 'POST', endpoint, '--input', '-', '--silent'], input=json.dumps({'body': body}), text=True, check=True)
