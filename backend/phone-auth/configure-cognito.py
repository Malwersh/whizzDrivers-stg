"""Enable additive OTP challenges on the staging pool; preserve writable settings.
Run after deploying phone-auth-template.yaml. Backups exclude all user data.
"""
import json
import subprocess
import tempfile
from pathlib import Path

PROFILE = 'Wizz_stg_UserApp'
POOL = 'us-east-1_RGTqUXF5C'
CLIENT = '2d26d3muq0vvcuf42lkpgmkgsr'
ARN = 'arn:aws:lambda:us-east-1:699561669180:function:WhizzDrivers-phone-otp-staging'
BASE = ['aws', '--profile', PROFILE, '--region', 'us-east-1', 'cognito-idp']

def call(args):
    result = subprocess.run(BASE + args, capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError('Cognito configuration command failed: ' + args[0])
    return json.loads(result.stdout) if result.stdout.strip() else {}

def writable(operation, described):
    skeleton = call([operation, '--generate-cli-skeleton', 'input'])
    return {k: v for k, v in described.items() if k in skeleton}

if __name__ == '__main__':
    pool = writable('update-user-pool', call(['describe-user-pool', '--user-pool-id', POOL])['UserPool'])
    pool['UserPoolId'] = POOL
    client = writable('update-user-pool-client', call(['describe-user-pool-client', '--user-pool-id', POOL, '--client-id', CLIENT])['UserPoolClient'])
    client['UserPoolId'] = POOL
    backup = Path('/tmp/whizzdrivers-phone-auth-cognito-backup.json')
    if not backup.exists():
        backup.write_text(json.dumps({'pool': pool, 'client': client}, indent=2))
        backup.chmod(0o600)
    triggers = dict(pool.get('LambdaConfig', {}))
    for key in ['DefineAuthChallenge', 'CreateAuthChallenge', 'VerifyAuthChallengeResponse']:
        if triggers.get(key) and triggers[key] != ARN:
            raise RuntimeError('Existing custom auth trigger would be overwritten')
        triggers[key] = ARN
    pool['LambdaConfig'] = triggers
    flows = list(client.get('ExplicitAuthFlows', []))
    if 'ALLOW_CUSTOM_AUTH' not in flows:
        flows.append('ALLOW_CUSTOM_AUTH')
    client['ExplicitAuthFlows'] = flows
    def update(operation, data):
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json') as request:
            json.dump(data, request)
            request.flush()
            result = subprocess.run(BASE + [operation, '--cli-input-json', 'file://' + request.name], capture_output=True, text=True)
        if result.returncode:
            raise RuntimeError('Cognito update failed: ' + operation + ': ' + result.stderr.strip())
    update('update-user-pool', pool)
    update('update-user-pool-client', client)
    current = call(['describe-user-pool', '--user-pool-id', POOL])['UserPool']['LambdaConfig']
    assert current == triggers, 'Trigger preservation verification failed'
    print('OTP triggers configured; prior triggers and auth flows preserved. Backup saved.')
