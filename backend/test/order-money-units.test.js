const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');const vm=require('node:vm');
const source=fs.readFileSync('backend/lambda_driver_api_v2.js','utf8');
const helpers=source.slice(source.indexOf('function toNumber('),source.indexOf('async function getDriverProfileItem('));
function read(order){const ctx={order};vm.runInNewContext(helpers+'\nthis.result=normalizeOrderPricingToIqd(order);',ctx);return ctx.result;}
test('verified writer converts small, large and fractional amounts exactly once',()=>{
 for(const fee of [0,1000,2500000,2500125]){
 const result=read({currency:'IQD',createdBy:'wizzuser_app',pricing:{total:3500000+fee,goodsSubtotal:3500000,deliveryFee:fee,tip:500}});
 assert.equal(result.deliveryFee,fee/1000);assert.equal(result.total,3500+fee/1000);assert.equal(result.tip,0.5);
 }
});
test('legacy direct IQD remains unchanged',()=>{
 const result=read({total:6250,subtotal:3750,deliveryFee:2500});assert.equal(result.total,6250);assert.equal(result.deliveryFee,2500);
});
