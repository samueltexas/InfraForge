"""Read-only drift detection against initialized state. Author: Samuel Texa."""
import argparse
import json
from pathlib import Path
import subprocess


def check_drift(directory):
    """Return Terraform's detailed exit code without exposing state or plan text."""
    root = Path(directory).resolve()
    if not root.is_dir():
        return 1, 'Configuration directory does not exist.'
    command = ['terraform', f'-chdir={root}']
    try:
        state = subprocess.run(command + ['state', 'pull'], capture_output=True, text=True, check=False)
        if state.returncode != 0:
            return 1, 'Cannot read initialized state. Check authentication and backend configuration.'
        document = json.loads(state.stdout)
        if not document.get('lineage') or not any(
            r.get('mode') == 'managed' and r.get('instances')
            for r in document.get('resources', [])
        ):
            return 1, 'No managed resources in state; refusing a misleading clean result.'
        result = subprocess.run(
            command + ['plan', '-refresh-only', '-input=false', '-no-color',
                       '-detailed-exitcode', '-lock-timeout=60s'],
            capture_output=True, text=True, check=False,
        )
    except (OSError, ValueError):
        return 1, 'Terraform is unavailable or state could not be decoded.'
    messages = {
        0: 'No remote drift detected relative to state.',
        2: 'Remote drift detected. Review a fresh plan; no changes were applied.',
    }
    if result.returncode in messages:
        return result.returncode, messages[result.returncode]
    return 1, 'Drift check failed. Investigate in a protected terminal; no clean result is claimed.'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    args = parser.parse_args()
    code, message = check_drift(args.directory)
    print(json.dumps({'exit_code': code, 'summary': message}))
    return code


if __name__ == '__main__':
    raise SystemExit(main())
