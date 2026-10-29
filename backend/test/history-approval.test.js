const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const { createRequire } = require('node:module');
const { isDriverApproved } = require('../driver_eligibility');

function loadApi(send, options = {}) {
  const filename = path.resolve(__dirname, '../lambda_driver_api_v2.js');
  const realRequire = createRequire(filename);
  const env = Object.fromEntries(['DRIVER_TABLE', 'DRIVER_LIVE_STATE_TABLE', 'ORDERS_TABLE', 'WEBSOCKET_CONNECTIONS_TABLE', 'REGIONS_TABLE', 'REGION_INDEX_TABLE', 'REGION_NEIGHBORS_TABLE', 'ORDER_SERVICE_URL', 'DRIVER_DOCUMENTS_BUCKET'].map(key => [key, key]));
  Object.assign(env, options.env || {});
  const sandbox = { Buffer, URL, setTimeout, clearTimeout, process: { env }, exports: {}, console: { log() {}, warn() {}, error() {} }, require(name) {
    if (name === '@aws-sdk/client-lambda' && options.invoke) return { ...realRequire(name), LambdaClient: class { async send(c) { return options.invoke(c); } } };
    if (name === './pinned-legacy-runtime' && options.bridge) return { acceptPinnedLegacyFromDriver: options.bridge };
    if (name === '@aws-sdk/client-cognito-identity-provider') return { ...realRequire(name), CognitoIdentityProviderClient: class { async send() { throw new Error('Invalid token'); } } };
    if (name === '@aws-sdk/lib-dynamodb') return { ...realRequire(name), DynamoDBDocumentClient: { from: () => ({ send }) } };
    return realRequire(name);
  } };
  vm.runInNewContext(fs.readFileSync(filename, 'utf8') + '\nexports.testHooks = { getDriverTrips, startSearching, acceptWaveOffer, rejectWaveOffer, updateDriverProfile, handler: exports.handler };', sandbox);
  const {driverRequestContext}=realRequire('./driver-lifecycle');
  return Object.fromEntries(Object.entries(sandbox.exports.testHooks).map(([name,fn])=>[name,name==='handler'?fn:(...args)=>driverRequestContext.run({sub:args[0]},()=>fn(...args))]));
}

test('profile completion never substitutes for approval; suspension takes precedence', () => {
  assert.equal(isDriverApproved({ status: 'ACTIVE' }), false);
  assert.equal(isDriverApproved({ status: 'APPROVED' }), true);
  assert.equal(isDriverApproved({ status: 'ACTIVE', isVerified: true }), true);
  assert.equal(isDriverApproved({ status: 'SUSPENDED', isVerified: true }), false);
  assert.equal(isDriverApproved({ status: 'PENDING_REVIEW', documentsVerified: true }), false);
});

test('unapproved driver cannot start work or create an acceptance hold', async () => {
  const calls = [];
  const api = loadApi(async command => { calls.push(command); return { Item: { driverId: 'd', status: 'ACTIVE' } }; });
  assert.equal((await api.startSearching('d', { lat: 31, lng: 44 }, {})).statusCode, 403);
  assert.equal((await api.acceptWaveOffer('d', { offerId: 'OFFER_o_d_W1', orderId: 'o' }, {})).statusCode, 403);
  assert.ok(calls.every(command => command.constructor.name === 'GetCommand'));
});

test('history crosses empty scan pages and preserves cursor and IQD amounts', async () => {
  const calls = [];
  const cursor = { PK: 'ORDER#next', SK: 'META' };
  const api = loadApi(async command => {
    calls.push(command.input);
    if (calls.length === 1) return { Items: [], LastEvaluatedKey: cursor };
    return { Items: [{ PK: 'ORDER#o', SK: 'META', orderId: 'o', tripNumber: 'TRP123', status: 'delivered', createdAt: '2026-10-09T18:00:00Z', deliveredAt: '2026-10-09T18:30:00Z', total: 6010, pricing: { total: 6010000, deliveryFee: 10000, finalDeliveryFee: 10000 }, deliveryAddress: { fullAddress: 'النجف', lat: 31, lng: 44 } }] };
  });
  const response = await api.getDriverTrips('d', { limit: '20' }, {});
  const body = JSON.parse(response.body);
  assert.equal(body.trips.length, 1);
  assert.equal(body.trips[0].tripNumber, 'TRP123');
  assert.equal(body.trips[0].finalDeliveryFee, null);
  assert.equal(body.trips[0].driverEarnings, null);
  assert.equal(body.trips[0].deliveryFee, 10);
  assert.equal(body.trips[0].deliveryAddress, 'النجف');
  assert.deepEqual(calls[1].ExclusiveStartKey, cursor);
  assert.equal(calls[0].ExpressionAttributeValues[':driverId'], 'd');
  assert.equal(body.hasMore, false);
});

test('invalid history cursor is rejected without reading DynamoDB', async () => {
  const api = loadApi(async () => { throw new Error('must not read'); });
  assert.equal((await api.getDriverTrips('d', { nextToken: 'bad' }, {})).statusCode, 400);
});

test('mobile profile update cannot grant approval or change availability', async () => {
  let update;
  const api = loadApi(async command => {
    if (command.constructor.name === 'GetCommand') return { Item: { driverId: 'd', status: 'ACTIVE' } };
    update = command.input.TransactItems?.find(item=>item.Update)?.Update || command.input;
    return { Attributes: { status: 'PENDING_REVIEW' } };
  });
  await api.updateDriverProfile('d', [], null, { name: 'Driver', city: 'Najaf', vehicleType: 'car', licenseNumber: '123', nationalId: '456', status: 'APPROVED', isActive: true, isOnline: true, isVerified: true }, {});
  assert.ok(update);
  assert.equal(Object.values(update.ExpressionAttributeValues).includes('APPROVED'), false);
  assert.equal(Object.values(update.ExpressionAttributeNames).includes('isOnline'), false);
  assert.equal(Object.values(update.ExpressionAttributeNames).includes('isVerified'), false);
});


test('forged JWT cannot impersonate an approved driver or read their history', async () => {
  const api = loadApi(async () => { throw new Error('must not access data'); });
  const forgedToken = 'header.' + Buffer.from(JSON.stringify({ sub: 'approved-driver' })).toString('base64url') + '.fake-signature';
  const response = await api.handler({ httpMethod: 'GET', path: '/driver/trips', headers: { Authorization: 'Bearer ' + forgedToken } });
  assert.equal(response.statusCode, 401);
});

test('simplified profile submits three documents and enters review without ID numbers', async () => {
  const rows=[{regionId:'iq',name_ar:'العراق',level:0,effective_is_active:1},{regionId:'g',name_ar:'محافظة',level:1,parent_id:'iq',effective_is_active:1},{regionId:'district',level:2,parent_id:'g',effective_is_active:1},{regionId:'work',name_ar:'منطقة',level:3,parent_id:'district',effective_is_active:1}];
  const legal=require('../customer-legal-contract-344'),values=legal.defaults('DRIVER');const row={pk:legal.pkFor('DRIVER'),sk:'CURRENT',status:'PUBLISHED',version:1,publishedAt:'2026-10-28T00:00:00.000Z',values};row.digest=legal.hash({schemaVersion:1,revision:1,publishedAt:row.publishedAt,...values});
  const calls=[];
  const api=loadApi(async command=>{calls.push(command);if(command.input.TableName==='legal')return {Item:row};if(command.constructor.name==='ScanCommand')return {Items:rows};if(command.constructor.name==='UpdateCommand')return {Attributes:{driverId:'d',status:'PENDING_REVIEW'}};return {Item:{driverId:'d',status:'PENDING_PROFILE'}};},{env:{LEGAL_SETTINGS_TABLE:'legal'}});
  const prefix='s3://DRIVER_DOCUMENTS_BUCKET/drivers/d/';
  const body={profileSchemaVersion:2,legalAccepted:true,legalAcceptance:legal.pin(legal.readPublished(row)),vehicleType:'motorcycle',name:'سائق اختبار',governorate_id:'g',work_region_id:'work',home_address_text:'قرب المدرسة',drivingLicenseUrl:prefix+'driving_license/photo.jpg',registrationPaperUrl:prefix+'registration_paper/photo.jpg',nationalIdUrl:prefix+'national_id/photo.jpg'};
  const response=await api.updateDriverProfile('d',[],'token',body,{});
  assert.equal(response.statusCode,200);
  const transaction=calls.find(c=>c.constructor.name==='TransactWriteCommand');
  const update=transaction.input.TransactItems.find(item=>item.Update).Update;
  assert.equal(transaction.input.TransactItems[0].ConditionCheck.Key.pk,'ACCOUNT_LIFECYCLE#DRIVER#d');
  assert.ok(transaction.input.TransactItems.some(o=>o.ConditionCheck?.Key.pk===legal.pkFor('DRIVER')));
  assert.equal(update.ExpressionAttributeValues[':legalAcceptance'].subjectId,'d');
  assert.equal(update.ExpressionAttributeValues[':pendingReview'],'PENDING_REVIEW');
  assert.equal(Object.values(update.ExpressionAttributeNames).includes('licenseNumber'),false);
  calls.length=0;
  assert.equal((await api.updateDriverProfile('d',[],'token',{...body,legalAccepted:false},{})).statusCode,409);
  assert.equal(calls.some(c=>c.constructor.name==='TransactWriteCommand'),false);
  calls.length=0;
  assert.equal((await api.updateDriverProfile('d',[],'token',{...body,legalAcceptance:{revision:99,digest:'0'.repeat(64)}},{})).statusCode,409);
  assert.equal(calls.some(c=>c.constructor.name==='TransactWriteCommand'),false);
  calls.length=0;
  assert.equal((await api.updateDriverProfile('d',[],'token',{...body,governorate_id:'other'},{})).statusCode,400);
  assert.equal(calls.some(c=>['UpdateCommand','TransactWriteCommand'].includes(c.constructor.name)),false);
});

test('pinned cycles never enter the old pre-hold and automatic release wrapper',async()=>{
 const calls=[];const api=loadApi(async command=>{calls.push(command);const q=command.input;if(q.TableName==='DRIVER_TABLE')return {Item:{driverId:'d',status:'APPROVED'}};if(q.TableName==='ORDERS_TABLE')return {Item:{orderId:'o',status:'ready_for_pickup'}};if(q.TableName==='WizzDispatchJobs_staging')return {Item:{dispatchCycle:null}};throw Error('unexpected table');});
 const r=await api.acceptWaveOffer('d',{offerId:'OFFER_o_d_W1',orderId:'o'},{});assert.equal(r.statusCode,409);assert.equal(JSON.parse(r.body).code,'PINNED_LEGACY_ACCEPTANCE_REQUIRES_COORDINATED_RELEASE');assert(calls.every(c=>c.constructor.name==='GetCommand'));
});


test('pinned driver acceptance passes token and selectors to durable bridge, keeps pending separate from success',async()=>{
 for(const result of [{success:false,pending:true,requestId:'LA:test'},{success:false,reviewRequired:true},{success:true}]){
 const calls=[],routed=[];const api=loadApi(async c=>{calls.push(c);if(c.input.TableName==='DRIVER_TABLE')return {Item:{driverId:'d',status:'APPROVED'}};if(c.input.TableName==='ORDERS_TABLE')return {Item:{orderId:'o',status:'ready_for_pickup'}};if(c.input.TableName==='WizzDispatchJobs_staging')return {Item:{dispatchCycle:{id:'cycle'}}};throw Error('unexpected old write');},{env:{DISPATCH_CYCLE_MODE:'LEGACY_RESPONSES'},bridge:async(...args)=>{routed.push(args);return result;}});
 const response=await api.acceptWaveOffer('d',{offerId:'OFFER_o_d_W1',orderId:'o',driverId:'forged',holdAmount:1},{},'test-token');
 assert.equal(response.statusCode,result.success?200:result.pending?202:409);assert.equal(routed.length,1);assert.deepEqual(Object.keys(routed[0][0]).sort(),['offerId','orderId','waveNumber']);assert.equal(routed[0][1],'test-token');assert.equal(routed[0][2],'d');assert.equal(typeof routed[0][3],'function');assert(calls.every(c=>c.constructor.name==='GetCommand'));
 }
});

test('driver rejection forwards bearer identity to pinned response handler without body financial claims',async()=>{
 let payload;const api=loadApi(async()=>{throw Error('no database required');},{env:{WAVESYSTEM_HANDLE_DRIVER_REJECT_FUNCTION_NAME:'WaveSystem_HandleDriverReject'},invoke:async c=>{payload=JSON.parse(c.input.Payload);return {Payload:Buffer.from(JSON.stringify({statusCode:200,body:JSON.stringify({success:true})}))};}});
 const r=await api.rejectWaveOffer('d',{orderId:'o',offerId:'OFFER_o_d_W1',driverId:'forged',holdAmount:1},{},'test-token');assert.equal(r.statusCode,200);assert.equal(payload.headers.Authorization,'Bearer test-token');assert.deepEqual(JSON.parse(payload.body),{orderId:'o',offerId:'OFFER_o_d_W1',driverId:'d'});
});

test('authenticated history detail routes to the owned terminal order only',async()=>{
 const order={PK:'ORDER#order1',SK:'META',orderId:'order1',status:'delivered',driverId:'driver1',driverEarnings:2750,createdAt:'2026-10-22T10:00:00Z'};
 const api=loadApi(async c=>({Item:order}));
 for(const subject of ['driver1','other']){
  const r=await api.handler({httpMethod:'GET',path:'/driver/trips/order1',requestContext:{authorizer:{claims:{sub:subject}}}});
  assert.equal(r.statusCode,subject==='driver1'?200:404, r.body);
 }
});
