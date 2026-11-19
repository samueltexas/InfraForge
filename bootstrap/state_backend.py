"""Provision the separate state backend and plan identity. Author: Samuel Texa.
Requires an authorized Azure administrator; never reads or prints account keys.
"""
import argparse
import json
import subprocess
import time


def az(*args):
    output = subprocess.check_output(['az', *args, '--only-show-errors', '-o', 'json'], text=True)
    return json.loads(output) if output.strip() else None


def put(path, version, body):
    return az('rest', '--method', 'put', '--url', 'https://management.azure.com' + path + '?api-version=' + version, '--body', json.dumps(body))


def grant(principal, kind, role, scope):
    existing = az('role', 'assignment', 'list', '--scope', scope)
    if not any(r['principalId'] == principal and r['roleDefinitionName'] == role and r['scope'].lower() == scope.lower() for r in existing):
        az('role', 'assignment', 'create', '--assignee-object-id', principal, '--assignee-principal-type', kind, '--role', role, '--scope', scope)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--subscription', required=True)
    p.add_argument('--account', required=True)
    p.add_argument('--resource-group', default='rg-infraforge-tfstate')
    p.add_argument('--workload-group', default='rg-infraforge-dev')
    p.add_argument('--container', default='tfstate-development')
    p.add_argument('--github-subject-prefix', required=True)
    args = p.parse_args()
    account = az('account', 'show')
    assert account['id'] == args.subscription, 'Wrong active Azure subscription'
    subscription = '/subscriptions/' + args.subscription
    policies = az('rest', '--method', 'get', '--url', 'https://management.azure.com' + subscription + '?api-version=2022-12-01')['subscriptionPolicies']
    assert policies['spendingLimit'] == 'On', 'Keep the trial spending limit enabled'
    tags = {'project': 'InfraForge', 'component': 'terraform-state', 'managed_by': 'bootstrap-cli', 'environment': 'development'}
    az('group', 'create', '-n', args.resource_group, '-l', 'polandcentral', '--tags', *[k+'='+v for k,v in tags.items()])
    rg = subscription + '/resourceGroups/' + args.resource_group
    sid = rg + '/providers/Microsoft.Storage/storageAccounts/' + args.account
    accounts = az('storage', 'account', 'list', '-g', args.resource_group)
    existing = next((a for a in accounts if a['name'] == args.account), None)
    if existing:
        assert existing.get('tags', {}).get('component') == 'terraform-state', 'Refuse to repurpose unrelated storage'
    else:
        put(sid, '2023-05-01', {
            'location': 'polandcentral', 'kind': 'StorageV2', 'sku': {'name': 'Standard_LRS'}, 'tags': tags,
            'properties': {
                'minimumTlsVersion': 'TLS1_2', 'supportsHttpsTrafficOnly': True,
                'allowBlobPublicAccess': False, 'allowSharedKeyAccess': False,
                'defaultToOAuthAuthentication': True, 'isLocalUserEnabled': False,
                'publicNetworkAccess': 'Enabled', 'allowCrossTenantReplication': False,
                'encryption': {'keySource': 'Microsoft.Storage', 'requireInfrastructureEncryption': True,
                    'services': {'blob': {'enabled': True, 'keyType': 'Account'}, 'file': {'enabled': True, 'keyType': 'Account'}}},
            },
        })
    for _ in range(60):
        storage = az('storage', 'account', 'show', '-g', args.resource_group, '-n', args.account)
        if storage['provisioningState'] == 'Succeeded':
            break
        time.sleep(5)
    else:
        raise RuntimeError('Storage provisioning did not complete')
    assert storage['allowSharedKeyAccess'] is False and storage['allowBlobPublicAccess'] is False
    put(sid + '/blobServices/default', '2023-05-01', {'properties': {
        'isVersioningEnabled': True, 'deleteRetentionPolicy': {'enabled': True, 'days': 30},
        'containerDeleteRetentionPolicy': {'enabled': True, 'days': 30},
    }})
    container = sid + '/blobServices/default/containers/' + args.container
    put(container, '2023-05-01', {'properties': {'publicAccess': 'None'}})
    operator = az('ad', 'signed-in-user', 'show')['id']
    grant(operator, 'User', 'Storage Blob Data Contributor', container)
    identity = az('identity', 'create', '-g', args.resource_group, '-n', 'id-infraforge-plan', '-l', 'polandcentral', '--tags', *[k+'='+v for k,v in tags.items()])
    grant(identity['principalId'], 'ServicePrincipal', 'Reader', subscription + '/resourceGroups/' + args.workload_group)
    grant(identity['principalId'], 'ServicePrincipal', 'Storage Blob Data Contributor', container)
    for environment in ['development-plan', 'development-drift']:
        az('identity', 'federated-credential', 'create', '-g', args.resource_group, '--identity-name', identity['name'], '-n', 'github-' + environment,
           '--issuer', 'https://token.actions.githubusercontent.com', '--subject', args.github_subject_prefix + ':environment:' + environment,
           '--audiences', 'api://AzureADTokenExchange')
    put(sid + '/providers/Microsoft.Authorization/locks/protect-terraform-state', '2016-09-01', {'properties': {
        'level': 'CanNotDelete', 'notes': 'Protect independent Terraform backend. Review recovery and ownership before removal.'}})
    print('Backend, retention, scoped roles, OIDC federation and deletion lock configured. No state migrated yet.')


if __name__ == '__main__':
    main()
