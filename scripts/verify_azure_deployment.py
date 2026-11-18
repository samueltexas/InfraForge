"""Collect a redacted, read-only deployment snapshot. Author: Samuel Texa."""
import argparse
import datetime
import json
from pathlib import Path
import subprocess


def az(*args):
    return json.loads(subprocess.check_output(['az', *args, '-o', 'json'], text=True))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--resource-group', default='rg-infraforge-dev')
    parser.add_argument('--storage-account', default='stinfraforgeint01')
    args = parser.parse_args()
    account = az('account', 'show')
    sa = az('storage', 'account', 'show', '-g', args.resource_group, '-n', args.storage_account)
    sid = sa['id']

    def rest(path, version):
        return az('rest', '--method', 'get', '--url', f'https://management.azure.com{path}?api-version={version}')

    containers = rest(sid + '/blobServices/default/containers', '2023-05-01')['value']
    blob = rest(sid + '/blobServices/default', '2023-05-01')['properties']
    diagnostics = {}
    for service in ['blobServices', 'queueServices']:
        entries = rest(sid + '/' + service + '/default/providers/Microsoft.Insights/diagnosticSettings', '2021-05-01-preview')['value']
        diagnostics[service] = [{
            'name': d['name'],
            'workspace': d['properties']['workspaceId'].split('/')[-1],
            'enabled_logs': sorted(x['category'] for x in d['properties']['logs'] if x['enabled']),
            'enabled_metrics': sorted(x['category'] for x in d['properties']['metrics'] if x['enabled']),
        } for d in entries]
    endpoints = []
    for name in ['pe-stinfraforgeint01-blob', 'pe-infraforge-monitoring', 'kv-infraforge-int-dev-pe']:
        pe = az('network', 'private-endpoint', 'show', '-g', args.resource_group, '-n', name)
        endpoints.append({'name': name, 'state': pe['provisioningState'], 'connections': [c['privateLinkServiceConnectionState']['status'] for c in pe['privateLinkServiceConnections']]})
    identity = az('identity', 'show', '-g', args.resource_group, '-n', 'id-infraforge-foundation-dev')
    roles = az('role', 'assignment', 'list', '--all')
    scopes = sorted(r['scope'].split('/')[-1] for r in roles if r['principalId'] == identity['principalId'] and r['roleDefinitionName'] == 'Storage Blob Data Contributor' and r['scope'].startswith(sid + '/blobServices/default/containers/'))
    dns = az('network', 'private-dns', 'record-set', 'a', 'show', '-g', args.resource_group, '-z', 'privatelink.blob.core.windows.net', '-n', args.storage_account)
    policies = rest('/subscriptions/' + account['id'], '2022-12-01')['subscriptionPolicies']
    checks = {
        'storage_provisioned': sa['provisioningState'] == 'Succeeded',
        'public_access_disabled': sa['publicNetworkAccess'] == 'Disabled',
        'shared_key_disabled': sa['allowSharedKeyAccess'] is False,
        'local_users_disabled': sa['isLocalUserEnabled'] is False,
        'entra_default': sa['defaultToOAuthAuthentication'] is True,
        'infrastructure_encryption': sa['encryption']['requireInfrastructureEncryption'] is True,
        'private_containers': len(containers) == 3 and all(c['properties']['publicAccess'] == 'None' for c in containers),
        'container_scoped_rbac': scopes == sorted(c['name'] for c in containers),
        'private_endpoints_approved': all(p['state'] == 'Succeeded' and p['connections'] == ['Approved'] for p in endpoints),
        'private_dns_record_present': bool(dns['aRecords']),
        'audit_logs_enabled': all(any(d['enabled_logs'] == ['StorageDelete', 'StorageRead', 'StorageWrite'] for d in entries) for entries in diagnostics.values()),
        'spending_limit_on': policies['spendingLimit'] == 'On',
    }
    report = {
        'captured_at_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'source': 'Read-only Azure CLI and ARM queries; identifiers and account details omitted',
        'scope': 'Management-plane evidence; not an application availability or disaster recovery test',
        'checks': checks,
        'storage': {'name': sa['name'], 'region': sa['location'], 'sku': sa['sku']['name'], 'tls': sa['minimumTlsVersion'], 'key_source': sa['encryption']['keySource'], 'versioning': blob['isVersioningEnabled'], 'blob_retention_days': blob['deleteRetentionPolicy']['days'], 'container_retention_days': blob['containerDeleteRetentionPolicy']['days']},
        'containers': sorted(c['name'] for c in containers),
        'rbac_container_scopes': scopes,
        'endpoints': endpoints,
        'diagnostics': diagnostics,
        'subscription': {'offer': policies['quotaId'], 'spending_limit': policies['spendingLimit']},
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(checks, indent=2))
    raise SystemExit(0 if all(checks.values()) else 1)


if __name__ == '__main__':
    main()
