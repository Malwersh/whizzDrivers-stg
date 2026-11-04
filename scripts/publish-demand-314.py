"""Staging-only demand analytics provisioning. No source/financial row mutations.
Adds one isolated analytics table, collector, schedule, stream reader and read API.
Existing Lambda ZIP is patched by one route/module; all other entries preserved.
"""
import sys, json, io, zipfile, time, urllib.request, hashlib, base64
from pathlib import Path
from datetime import datetime, timezone
import boto3, subprocess
def session():
 credentials=json.loads(subprocess.check_output(['aws','configure','export-credentials','--profile','Wizz_stg_UserApp','--format','process'],text=True))
 return boto3.Session(aws_access_key_id=credentials['AccessKeyId'],aws_secret_access_key=credentials['SecretAccessKey'],aws_session_token=credentials['SessionToken'],region_name='us-east-1')
S=session();assert S.client('sts').get_caller_identity()['Account']=='699561669180'
REGION='us-east-1';ACCOUNT='699561669180';ROOT=Path(__file__).resolve().parents[1]
TMP=Path('/private/tmp/demand314');TMP.mkdir(exist_ok=True)
l=S.client('lambda');ddb=S.client('dynamodb');iam=S.client('iam');events=S.client('events');logs=S.client('logs');sqs=S.client('sqs');cw=S.client('cloudwatch')
api=l.get_function(FunctionName='DriversApi-staging');cfg=api['Configuration'];env=cfg['Environment']['Variables']
assert env['DRIVER_TABLE']=='WhizzDrivers_staging' and env['DISPATCH_JOBS_TABLE']=='WizzDispatchJobs_staging'
TABLE='staging-DriverDemand';FN='staging-DriverDemandCollector';ROLE='staging-DriverDemandCollector';POLICY='DemandAnalytics314';RULE='staging-DriverDemandHourly'
source={k:env[k] for k in ['DISPATCH_JOBS_TABLE','ORDERS_TABLE','REGIONS_TABLE']};source['BUSINESSES_TABLE']='WhizzMerchants_Businesses';source['WORKING_HOURS_TABLE']='WhizzMerchants_BusinessWorkingHours'
try:ddb.describe_table(TableName=TABLE)
except ddb.exceptions.ResourceNotFoundException:
 ddb.create_table(TableName=TABLE,KeySchema=[{'AttributeName':'pk','KeyType':'HASH'},{'AttributeName':'sk','KeyType':'RANGE'}],AttributeDefinitions=[{'AttributeName':'pk','AttributeType':'S'},{'AttributeName':'sk','AttributeType':'S'}],BillingMode='PAY_PER_REQUEST',Tags=[{'Key':'Purpose','Value':'driver-demand-analytics'},{'Key':'Environment','Value':'staging'}]);ddb.get_waiter('table_exists').wait(TableName=TABLE,WaiterConfig={'Delay':2,'MaxAttempts':30})
if ddb.describe_time_to_live(TableName=TABLE)['TimeToLiveDescription']['TimeToLiveStatus']=='DISABLED':ddb.update_time_to_live(TableName=TABLE,TimeToLiveSpecification={'Enabled':True,'AttributeName':'expiresAt'})
t=ddb.describe_table(TableName=source['DISPATCH_JOBS_TABLE'])['Table']
if not t.get('StreamSpecification',{}).get('StreamEnabled'):
 ddb.update_table(TableName=t['TableName'],StreamSpecification={'StreamEnabled':True,'StreamViewType':'NEW_IMAGE'})
 for _ in range(30):
  t=ddb.describe_table(TableName=t['TableName'])['Table']
  if t.get('LatestStreamArn'):break
  time.sleep(1)
assert t.get('LatestStreamArn') and t['StreamSpecification']['StreamViewType'] in ('NEW_IMAGE','NEW_AND_OLD_IMAGES')
stream=t['LatestStreamArn']
qurl=sqs.create_queue(QueueName='staging-DriverDemandFailures',Attributes={'MessageRetentionPeriod':'1209600','SqsManagedSseEnabled':'true'})['QueueUrl']
qarn=sqs.get_queue_attributes(QueueUrl=qurl,AttributeNames=['QueueArn'])['Attributes']['QueueArn']
trust={'Version':'2012-10-17','Statement':[{'Effect':'Allow','Principal':{'Service':'lambda.amazonaws.com'},'Action':'sts:AssumeRole'}]}
try:role=iam.get_role(RoleName=ROLE)['Role']
except iam.exceptions.NoSuchEntityException:role=iam.create_role(RoleName=ROLE,AssumeRolePolicyDocument=json.dumps(trust),Description='Isolated driver demand analytics; no financial/source writes')['Role'];time.sleep(8)
def arn(table):return f'arn:aws:dynamodb:{REGION}:{ACCOUNT}:table/{table}'
policy={'Version':'2012-10-17','Statement':[
 {'Effect':'Allow','Action':['dynamodb:GetItem'],'Resource':[arn(v) for v in source.values()]},
 {'Effect':'Allow','Action':['dynamodb:Scan'],'Resource':[arn(source[k]) for k in ['DISPATCH_JOBS_TABLE','REGIONS_TABLE','BUSINESSES_TABLE','WORKING_HOURS_TABLE']]},
 {'Effect':'Allow','Action':['dynamodb:GetItem','dynamodb:PutItem','dynamodb:Scan'],'Resource':arn(TABLE)},
 {'Effect':'Allow','Action':['dynamodb:DescribeStream','dynamodb:GetRecords','dynamodb:GetShardIterator'],'Resource':stream},
 {'Effect':'Allow','Action':['dynamodb:ListStreams'],'Resource':'*'},
 {'Effect':'Allow','Action':['sqs:SendMessage'],'Resource':qarn},
 {'Effect':'Allow','Action':['logs:CreateLogStream','logs:PutLogEvents'],'Resource':f'arn:aws:logs:{REGION}:{ACCOUNT}:log-group:/aws/lambda/{FN}:*'}]}
iam.put_role_policy(RoleName=ROLE,PolicyName=POLICY,PolicyDocument=json.dumps(policy))
try:logs.create_log_group(logGroupName='/aws/lambda/'+FN)
except logs.exceptions.ResourceAlreadyExistsException:pass
logs.put_retention_policy(logGroupName='/aws/lambda/'+FN,retentionInDays=14)
try:old=l.get_function_configuration(FunctionName=FN)
except l.exceptions.ResourceNotFoundException:old=None
coverage=old['Environment']['Variables']['COVERAGE_START'] if old else datetime.now(timezone.utc).isoformat()
profile=S.resource('dynamodb').Table(env['DRIVER_TABLE']).get_item(Key={'driverId':'34d8e408-1021-7076-6055-7325644f97cb'},ConsistentRead=True)['Item'];simregion=profile['work_region_id']
workerEnv={**source,'DEMAND_TABLE':TABLE,'DEMAND_DATASET':'TEST','COVERAGE_START':coverage,'SIMULATION_REGION':simregion}
z=io.BytesIO()
with zipfile.ZipFile(z,'w',zipfile.ZIP_DEFLATED) as out:out.writestr('worker.py',(ROOT/'backend/demand/worker.py').read_bytes())
if old:
 l.update_function_code(FunctionName=FN,ZipFile=z.getvalue(),RevisionId=old['RevisionId']);l.get_waiter('function_updated_v2').wait(FunctionName=FN,WaiterConfig={'Delay':2,'MaxAttempts':30});l.update_function_configuration(FunctionName=FN,Environment={'Variables':workerEnv},Timeout=300,MemorySize=256)
else:
 for attempt in range(8):
  try:l.create_function(FunctionName=FN,Runtime='python3.12',Role=role['Arn'],Handler='worker.handler',Code={'ZipFile':z.getvalue()},Timeout=300,MemorySize=256,Environment={'Variables':workerEnv});break
  except l.exceptions.InvalidParameterValueException:
   if attempt==7:raise
   time.sleep(3)
l.get_waiter('function_active_v2').wait(FunctionName=FN,WaiterConfig={'Delay':2,'MaxAttempts':30})
l.get_waiter('function_updated_v2').wait(FunctionName=FN,WaiterConfig={'Delay':2,'MaxAttempts':30})
mappings=l.list_event_source_mappings(FunctionName=FN,EventSourceArn=stream)['EventSourceMappings']
if not mappings:
 l.create_event_source_mapping(FunctionName=FN,EventSourceArn=stream,StartingPosition='TRIM_HORIZON',BatchSize=100,MaximumBatchingWindowInSeconds=10,FunctionResponseTypes=['ReportBatchItemFailures'],MaximumRetryAttempts=6,MaximumRecordAgeInSeconds=21600,BisectBatchOnFunctionError=True,DestinationConfig={'OnFailure':{'Destination':qarn}},FilterCriteria={'Filters':[{'Pattern':json.dumps({'eventName':['INSERT','MODIFY'],'dynamodb':{'NewImage':{'SK':{'S':['METADATA']}}}})}]})
rule=events.put_rule(Name=RULE,ScheduleExpression='rate(1 hour)',State='ENABLED',Description='Reconcile analytics and rebuild complete regional forecasts')
try:l.add_permission(FunctionName=FN,StatementId='DemandHourly314',Action='lambda:InvokeFunction',Principal='events.amazonaws.com',SourceArn=rule['RuleArn'])
except l.exceptions.ResourceConflictException:pass
events.put_targets(Rule=RULE,Targets=[{'Id':'DemandHourly','Arn':l.get_function_configuration(FunctionName=FN)['FunctionArn'],'Input':'{}','RetryPolicy':{'MaximumRetryAttempts':2,'MaximumEventAgeInSeconds':3600}}])
for alarm,namespace,metric,dimension,threshold in [('Errors','AWS/Lambda','Errors',{'Name':'FunctionName','Value':FN},1),('StreamLag','AWS/Lambda','IteratorAge',{'Name':'FunctionName','Value':FN},600000),('DeadLetter','AWS/SQS','ApproximateNumberOfMessagesVisible',{'Name':'QueueName','Value':'staging-DriverDemandFailures'},1)]:
 cw.put_metric_alarm(AlarmName='staging-DriverDemand-'+alarm,Namespace=namespace,MetricName=metric,Dimensions=[dimension],Statistic='Maximum',Period=300,EvaluationPeriods=1,Threshold=threshold,ComparisonOperator='GreaterThanOrEqualToThreshold',TreatMissingData='notBreaching')
# Warm rebuild: writes analytics table ONLY, not synthetic orders or financial records.
r=l.invoke(FunctionName=FN,Payload=b'{}');v=json.loads(r['Payload'].read());assert not r.get('FunctionError'),v
# Narrow API role permission: reads this one analytics table, never writes it.
apiRole=cfg['Role'].split('/')[-1]
iam.put_role_policy(RoleName=apiRole,PolicyName='DriverDemandRead314',PolicyDocument=json.dumps({'Version':'2012-10-17','Statement':[{'Effect':'Allow','Action':['dynamodb:GetItem'],'Resource':arn(TABLE)}]}))
# Patch live ZIP only: route plus new module. Source branch may contain unrelated edits.
api=l.get_function(FunctionName='DriversApi-staging');cfg=api['Configuration'];data=urllib.request.urlopen(api['Code']['Location']).read();(TMP/'before.zip').write_bytes(data);(TMP/'before-config.private.json').write_text(json.dumps(cfg,default=str));oldzip=zipfile.ZipFile(io.BytesIO(data));name='lambda_driver_api_v2.js';live=oldzip.read(name).decode();local=(ROOT/'backend'/name).read_text();a=local.index("    if ((path === '/driver/demand-forecast'");b=local.index('    // 📊 NEW: Get driver performance metrics',a);block=local[a:b]
if "path === '/driver/demand-forecast'" not in live:
 marker='    // 📊 NEW: Get driver performance metrics';assert live.count(marker)==1;live=live.replace(marker,block+marker,1)
else:
 a=live.index("    if ((path === '/driver/demand-forecast'");b=live.index('    // 📊 NEW: Get driver performance metrics',a);live=live[:a]+block+live[b:]
out=io.BytesIO()
with zipfile.ZipFile(out,'w') as target:
 for entry in oldzip.infolist():
  if entry.filename!='driver-demand.js':target.writestr(entry,live.encode() if entry.filename==name else oldzip.read(entry.filename))
 target.writestr('driver-demand.js',(ROOT/'backend/driver-demand.js').read_bytes())
(TMP/'candidate.zip').write_bytes(out.getvalue())
l.update_function_code(FunctionName='DriversApi-staging',RevisionId=cfg['RevisionId'],ZipFile=out.getvalue());l.get_waiter('function_updated_v2').wait(FunctionName='DriversApi-staging',WaiterConfig={'Delay':2,'MaxAttempts':30})
updated=l.get_function_configuration(FunctionName='DriversApi-staging');newenv={**updated['Environment']['Variables'],'DEMAND_TABLE':TABLE,'DEMAND_DATASET':'TEST','DEMAND_SIMULATION_DRIVERS':'34d8e408-1021-7076-6055-7325644f97cb'}
l.update_function_configuration(FunctionName='DriversApi-staging',RevisionId=updated['RevisionId'],Environment={'Variables':newenv});l.get_waiter('function_updated_v2').wait(FunctionName='DriversApi-staging',WaiterConfig={'Delay':2,'MaxAttempts':30})
report={'status':'PUBLISHED','stage':'staging','table':TABLE,'collector':FN,'dataset':'TEST','simulationIsolated':True,'coverageStart':coverage,'stream':stream,'schedule':RULE,'changedApiEntries':[name,'driver-demand.js'],'apiCodeSha256':base64.b64encode(hashlib.sha256(out.getvalue()).digest()).decode(),'sourceRowsMutated':False,'financialWrites':False,'initialRebuild':v,'alarms':['Errors','StreamLag','DeadLetter'],'alarmNotifications':'CloudWatch only; no SNS contact configured'}
(ROOT/'docs/demand-publication-314.json').write_text(json.dumps(report,indent=2));print(json.dumps(report))
