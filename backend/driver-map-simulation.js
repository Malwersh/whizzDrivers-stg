'use strict';
// Explicit staging UAT only, bound to the already allowlisted simulation driver.
async function loadSimulation(db,GetCommand,driverId,at){
 if(process.env.ENVIRONMENT!=='staging'||process.env.DEMAND_DATASET!=='TEST'||!(process.env.DEMAND_SIMULATION_DRIVERS||'').split(',').includes(driverId))return null;
 const row=(await db.send(new GetCommand({TableName:'staging-PlatformStaff',Key:{pk:'OPERATIONAL_SETTINGS#DRIVER_MAP_TOOLS',sk:'SIMULATION#'+driverId},ConsistentRead:true}))).Item;
 const created=Date.parse(row?.createdAt),expiry=Number(row?.expiresAt)*1000;
 if(!row||row.kind!=='DRIVER_MAP_ACTIVITY_SIMULATION'||row.driverId!==driverId||!Number.isFinite(created)||!Number.isSafeInteger(row.expiresAt)||expiry<=at.getTime()||created>at.getTime()+300000||expiry-created>7200000||expiry<=created||!Array.isArray(row.stores)||row.stores.length!==3)return null;
 const ids=new Set();for(const s of row.stores){if(typeof s.storeId!=='string'||!s.storeId||ids.has(s.storeId)||!Number.isSafeInteger(s.addedReadyCount)||s.addedReadyCount<1||s.addedReadyCount>50)return null;ids.add(s.storeId);}
 return row;
}
module.exports={loadSimulation};
