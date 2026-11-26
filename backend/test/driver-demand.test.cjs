const {test}=require('node:test');const assert=require('node:assert/strict');
const {readDemand}=require('../driver-demand');
const now=new Date('2026-10-23T10:00:00Z');
function fixture(){
 const rows={drivers:{d:{work_region_id:'zone'}},live:{},regions:{zone:{regionId:'zone',name_ar:'ناحية الحيرة',level:3,parent_id:'district',effective_is_active:1},district:{regionId:'district',level:2,name_ar:'قضاء',effective_is_active:1}},analytics:{}};
 const snapshot={schemaVersion:1,dataset:'TEST',timezone:'Asia/Baghdad',generatedAt:now.toISOString(),days:Array.from({length:7},(_,i)=>({date:'2026-10-'+(23+i),confidence:'MODERATE',sampleOrders:100,slots:[{hour:12,score:80,level:'HIGH'}]}))};
 rows.analytics['HEALTH#TEST']={completedAt:now.toISOString()};rows.analytics['FORECAST#TEST#zone']=snapshot;
 const calls=[];const db={send:async c=>{calls.push(c.input);return {Item:rows[c.input.TableName]?.[c.input.Key.driverId||c.input.Key.regionId||c.input.Key.pk]};}};
 return {rows,snapshot,calls,run:extra=>readDemand({db,GetCommand:class{constructor(input){this.input=input}},tables:{drivers:'drivers',live:'live',regions:'regions',demand:'analytics',dataset:'TEST'},driverId:'d',now,...extra})};
}
test('scope comes from server driver region and response excludes sample counts',async()=>{const f=fixture(),r=await f.run();assert.equal(r.result.state,'READY');assert.equal(r.result.area.id,'zone');assert.equal(r.result.isTestData,true);assert.equal(r.result.days[0].sampleOrders,undefined);assert.equal(f.calls.filter(c=>c.TableName==='analytics').length,2);});
test('cold start and stale health never fabricate bars',async()=>{for(const health of [undefined,{completedAt:'2026-10-20T00:00:00Z'}]){const f=fixture();f.rows.analytics['HEALTH#TEST']=health;const r=await f.run();assert.equal(r.result.state,'UPDATING');assert.deepEqual(r.result.days,[]);}});
test('district fallback is explicit and unrelated region never queried',async()=>{const f=fixture();f.rows.analytics['FORECAST#TEST#zone']={...f.snapshot,days:f.snapshot.days.map(d=>({...d,confidence:'INSUFFICIENT',slots:[]}))};f.rows.analytics['FORECAST#TEST#district']=f.snapshot;const r=await f.run();assert.equal(r.result.sourceArea.id,'district');assert.equal(r.result.isWiderArea,true);assert.ok(!JSON.stringify(f.calls).includes('foreign'));});
test('missing/inactive region and deleted driver cannot see forecasts',async()=>{const f=fixture();f.rows.regions.zone.effective_is_active=0;assert.equal((await f.run()).result.state,'NO_REGION');f.rows.drivers.d.isDeleted=true;assert.equal((await f.run()).statusCode,403);});
test('simulation only selected by explicit test driver allowlist',async()=>{const f=fixture();const r=await f.run({simulationDrivers:['d']});assert.equal(r.result.state,'UPDATING');assert.ok(f.calls.some(c=>c.Key.pk==='HEALTH#SIMULATION'));});

test('a snapshot from an unfinished rebuild is not served',async()=>{const f=fixture();f.snapshot.generatedAt='2026-10-23T09:59:00Z';assert.equal((await f.run()).result.state,'UPDATING');});
