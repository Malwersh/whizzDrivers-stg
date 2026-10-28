'use strict';
// Aggregate only ready, unassigned pickup work. Never return order/customer data.
const valid=v=>typeof v==='string'&&/^[A-Za-z0-9_.:-]{1,150}$/.test(v);
async function parallel(values,limit,fn){let n=0;const out=[];await Promise.all(Array.from({length:Math.min(limit,values.length)},async()=>{while(n<values.length){const i=n++;out[i]=await fn(values[i]);}}));return out;}
function waiting(o,id){return o?.storeId===id&&o.status==='ready_for_pickup'&&[undefined,null,'ready_for_pickup'].includes(o.orderStatus)&&!o.driverId&&!o.assignedDriverId&&!o.pickedUpAt&&!o.pickupAt&&!o.returnCaseId&&!o.holdId&&!o.walletPendingHoldId&&!o.financialAcceptance&&!o.financialOutcome&&o.merchantHandover?.state!=='HANDED_TO_DRIVER'&&!o.cancellationExecution;}
async function readActivity({db,GetCommand,QueryCommand,driverId,input,tables,regionAccess,now=()=>new Date()}){
 const fail=code=>{throw Object.assign(Error(code),{code});};
 if(!valid(driverId)||!input||Object.keys(input).some(k=>k!=='storeIds')||!Array.isArray(input.storeIds)||input.storeIds.length>20||input.storeIds.some(v=>!valid(v)))fail('MAP_ACTIVITY_INVALID_REQUEST');
 const get=async(t,k)=>(await db.send(new GetCommand({TableName:t,Key:k,ConsistentRead:true}))).Item;
 const driver=await get(tables.drivers,{driverId});if(!driver||driver.isDeleted||driver.deletedAt||driver.isBanned||driver.isSuspended||!valid(driver.work_region_id))fail('MAP_ACTIVITY_DRIVER_UNAVAILABLE');
 const policy=await require('./driver-map-settings-329').readPolicy(db,GetCommand);
 if(!policy.heatEnabled)return {success:true,enabled:false,generatedAt:now().toISOString(),validForSeconds:0,items:[]};
 const simulation=await require('./driver-map-simulation').loadSimulation(db,GetCommand,driverId,now());
 const work=driver.work_region_id,results=await parallel([...new Set(input.storeIds)],3,async storeId=>{
  const store=await get(tables.businesses,{businessId:storeId});if(!store||store.isActive!==true||store.status!=='approved')return {storeId,state:'UNAVAILABLE'};
  const access=await regionAccess.check(driver,work,store.regionId,1);if(!access.allowed)return {storeId,state:'OUTSIDE_WORK_AREA'};
  try{
   const candidates=await parallel(Array.from({length:10},(_,i)=>i),3,async bucket=>{
    const q=await db.send(new QueryCommand({TableName:tables.orders,IndexName:'GSI_StoreStatus',KeyConditionExpression:'storeStatus=:s',ExpressionAttributeValues:{':s':storeId+'#ready_for_pickup#b'+bucket},ProjectionExpression:'PK,SK',Limit:30}));
    // Never describe a truncated index result as an exact count.
    if(q.LastEvaluatedKey)throw Error('BUSY_INDEX_PAGE');return q.Items||[];
   });
   const keys=[...new Map(candidates.flat().map(o=>[o.PK+'|'+o.SK,o])).values()];if(keys.length>100)throw Error('BUSY_INDEX_LIMIT');
   const fresh=await parallel(keys,5,async k=>{if(typeof k.PK!=='string'||k.SK!=='META')throw Error('INVALID_ORDER_KEY');return get(tables.orders,{PK:k.PK,SK:k.SK});});
   const realCount=fresh.filter(o=>waiting(o,storeId)).length, added=simulation?.stores.find(s=>s.storeId===storeId)?.addedReadyCount||0, count=realCount+added;return {storeId,state:'CURRENT',readyCount:count,...(added?{isTestData:true,simulatedAddedCount:added}:{}),level:count>=policy.busyMinimumReady?'BUSY':count>0?'READY':'QUIET'};
  }catch{return {storeId,state:'UPDATING'};}
 });
 return {success:true,enabled:true,policyVersion:policy.version,generatedAt:now().toISOString(),validForSeconds:policy.refreshSeconds+5,meaning:'READY_UNASSIGNED_PICKUPS',isTestData:!!simulation,simulationExpiresAt:simulation?.expiresAt??null,items:results};
}
module.exports={readActivity,waiting};
