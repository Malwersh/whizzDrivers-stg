const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const { createRequire } = require('node:module');
const { isDriverApproved } = require('../driver_eligibility');

function loadApi(send) {
  const filename = path.resolve(__dirname, '../lambda_driver_api_v2.js');
  const realRequire = createRequire(filename);
  const env = Object.fromEntries(['DRIVER_TABLE', 'DRIVER_LIVE_STATE_TABLE', 'ORDERS_TABLE', 'WEBSOCKET_CONNECTIONS_TABLE', 'REGIONS_TABLE', 'REGION_INDEX_TABLE', 'REGION_NEIGHBORS_TABLE', 'ORDER_SERVICE_URL', 'DRIVER_DOCUMENTS_BUCKET'].map(key => [key, key]));
  const sandbox = { Buffer, URL, setTimeout, clearTimeout, process: { env }, exports: {}, console: { log() {}, warn() {}, error() {} }, require(name) {
    if (name === '@aws-sdk/client-cognito-identity-provider') return { ...realRequire(name), CognitoIdentityProviderClient: class { async send() { throw new Error('Invalid token'); } } };
    if (name === '@aws-sdk/lib-dynamodb') return { ...realRequire(name), DynamoDBDocumentClient: { from: () => ({ send }) } };
    return realRequire(name);
  } };
  vm.runInNewContext(fs.readFileSync(filename, 'utf8') + '\nexports.testHooks = { getDriverTrips, startSearching, acceptWaveOffer, updateDriverProfile, handler: exports.handler };', sandbox);
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
  assert.equal(body.trips[0].finalDeliveryFee, 10);
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
  const calls=[];
  const api=loadApi(async command=>{calls.push(command);if(command.constructor.name==='ScanCommand')return {Items:rows};if(command.constructor.name==='UpdateCommand')return {Attributes:{driverId:'d',status:'PENDING_REVIEW'}};return {Item:{driverId:'d',status:'PENDING_PROFILE'}};});
  const prefix='s3://DRIVER_DOCUMENTS_BUCKET/drivers/d/';
  const body={profileSchemaVersion:2,vehicleType:'motorcycle',name:'سائق اختبار',governorate_id:'g',work_region_id:'work',home_address_text:'قرب المدرسة',drivingLicenseUrl:prefix+'driving_license/photo.jpg',registrationPaperUrl:prefix+'registration_paper/photo.jpg',nationalIdUrl:prefix+'national_id/photo.jpg'};
  const response=await api.updateDriverProfile('d',[],'token',body,{});
  assert.equal(response.statusCode,200);
  const transaction=calls.find(c=>c.constructor.name==='TransactWriteCommand');
  const update=transaction.input.TransactItems.find(item=>item.Update).Update;
  assert.equal(transaction.input.TransactItems[0].ConditionCheck.Key.pk,'ACCOUNT_LIFECYCLE#DRIVER#d');
  assert.equal(update.ExpressionAttributeValues[':pendingReview'],'PENDING_REVIEW');
  assert.equal(Object.values(update.ExpressionAttributeNames).includes('licenseNumber'),false);
  calls.length=0;
  assert.equal((await api.updateDriverProfile('d',[],'token',{...body,governorate_id:'other'},{})).statusCode,400);
  assert.equal(calls.some(c=>['UpdateCommand','TransactWriteCommand'].includes(c.constructor.name)),false);
});
