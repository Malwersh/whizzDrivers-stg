'use strict';
const {GetCommand,UpdateCommand}=require('@aws-sdk/lib-dynamodb');
async function cleanupFinishedOrder(db,table,driverId,orderId){
 const {Item:live}=await db.send(new GetCommand({TableName:table,Key:{driverId},ConsistentRead:true}));if(!live)return false;
 const pointerMatches=live.currentOrderId===orderId||live.currentOrderId==='ORDER#'+orderId;
 const jobMatches=typeof live.currentDeliveryJob==='object'&&live.currentDeliveryJob&&[orderId,'ORDER#'+orderId].includes(live.currentDeliveryJob.orderId)||typeof live.currentDeliveryJob==='string'&&(live.currentDeliveryJob===orderId||live.currentDeliveryJob.startsWith('DISPATCH_'+orderId+'_')); 
 if(!pointerMatches&&!jobMatches)return false;
 // Never clear a different current assignment, even after an old completion is retried.
 if(live.currentOrderId&&!pointerMatches)return false;
 if(live.currentDeliveryJob&&typeof live.currentDeliveryJob==='object'&&!jobMatches)return false;
 if(live.activeOrdersCount!==undefined&&(!Number.isSafeInteger(live.activeOrdersCount)||live.activeOrdersCount<0))throw Error('INVALID_ACTIVE_ORDER_COUNT');
 const count=live.activeOrdersCount||0,remaining=Math.max(0,count-1),offline=live.status==='offline'||live.isOnline===false;
 const names={'#status':'status'},values={':remaining':remaining,':status':offline?'offline':remaining?'busy':'available',':available':!offline&&remaining===0,':now':new Date().toISOString()};
 const conditions=['attribute_exists(driverId)'];
 if(live.activeOrdersCount===undefined)conditions.push('attribute_not_exists(activeOrdersCount)');else{conditions.push('activeOrdersCount = :count');values[':count']=count;}
 if(live.status===undefined)conditions.push('attribute_not_exists(#status)');else{conditions.push('#status = :oldStatus');values[':oldStatus']=live.status;}
 const remove=['currentWaveOfferId'];if(pointerMatches){conditions.push('currentOrderId = :pointer');values[':pointer']=live.currentOrderId;remove.push('currentOrderId');}else conditions.push('attribute_not_exists(currentOrderId)');
 if(jobMatches){conditions.push('currentDeliveryJob = :job');values[':job']=live.currentDeliveryJob;remove.push('currentDeliveryJob');}
 try{await db.send(new UpdateCommand({TableName:table,Key:{driverId},UpdateExpression:'SET activeOrdersCount = :remaining, #status = :status, isAvailable = :available, isSearching = :available, updatedAt = :now REMOVE '+remove.join(', '),ConditionExpression:conditions.join(' AND '),ExpressionAttributeNames:names,ExpressionAttributeValues:values}));return true;}catch(e){if(e.name==='ConditionalCheckFailedException')return false;throw e;}
}
module.exports={cleanupFinishedOrder};
