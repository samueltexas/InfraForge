"""Export allowlisted backend controls without account identifiers. Author: Samuel Texa."""
import argparse
import datetime
import json
from pathlib import Path
import subprocess


def az(*args):
    return json.loads(subprocess.check_output(['az', *args, '--only-show-errors', '-o', 'json'], text=True))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--account', required=True)
    parser.add_argument('--resource-group', default='rg-infraforge-tfstate')
    parser.add_argument('--container', default='tfstate-development')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    account = az('storage', 'account', 'show', '-g', args.resource_group, '-n', args.account)
    sid = account['id']
    blob = az('rest', '--url', 'https://management.azure.com' + sid + '/blobServices/default?api-version=2023-05-01')['properties']
    container = sid + '/blobServices/default/containers/' + args.container
    identity = az('identity', 'show', '-g', args.resource_group, '-n', 'id-infraforge-plan')
    assignments = az('role', 'assignment', 'list', '--all')
    roles = [r for r in assignments if r['principalId'] == identity['principalId']]
    federation = az('identity', 'federated-credential', 'list', '-g', args.resource_group, '--identity-name', 'id-infraforge-plan')
    locks = az('rest', '--url', 'https://management.azure.com' + sid + '/providers/Microsoft.Authorization/locks?api-version=2016-09-01')['value']
    checks = {
        'provisioned': account['provisioningState'] == 'Succeeded',
        'shared_key_disabled': account['allowSharedKeyAccess'] is False,
        'anonymous_blob_disabled': account['allowBlobPublicAccess'] is False,
        'local_users_disabled': account['isLocalUserEnabled'] is False,
        'entra_default': account['defaultToOAuthAuthentication'] is True,
        'https_only': account['enableHttpsTrafficOnly'] is True,
        'tls_1_2': account['minimumTlsVersion'] == 'TLS1_2',
        'infrastructure_encryption': account['encryption']['requireInfrastructureEncryption'] is True,
        'versioning': blob['isVersioningEnabled'] is True,
        'blob_soft_delete_30_days': blob['deleteRetentionPolicy']['enabled'] and blob['deleteRetentionPolicy']['days'] == 30,
        'container_soft_delete_30_days': blob['containerDeleteRetentionPolicy']['enabled'] and blob['containerDeleteRetentionPolicy']['days'] == 30,
        'deletion_lock': any(l['properties']['level'] == 'CanNotDelete' for l in locks),
        'plan_roles_scoped': len(roles) == 2 and any(r['roleDefinitionName'] == 'Reader' and r['scope'].endswith('/resourceGroups/rg-infraforge-dev') for r in roles) and any(r['roleDefinitionName'] == 'Storage Blob Data Contributor' and r['scope'] == container for r in roles),
        'oidc_environments': len(federation) == 2 and {f['subject'].rsplit(':environment:', 1)[-1] for f in federation} == {'development-plan', 'development-drift'} and all(f['issuer'] == 'https://token.actions.githubusercontent.com' and f['audiences'] == ['api://AzureADTokenExchange'] for f in federation),
    }
    report = {'captured_at_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'source': 'Allowlisted Azure management-plane fields; account and identity identifiers omitted', 'checks': checks, 'region': account['location'], 'sku': account['sku']['name'], 'public_endpoint': account['publicNetworkAccess'], 'boundary': 'Resource Reader plus state-container data contributor; authenticated public backend endpoint for hosted runners'}
    args.output.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(checks))
    return 0 if all(checks.values()) else 1


if __name__ == '__main__':
    raise SystemExit(main())
