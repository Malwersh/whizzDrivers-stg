'use strict';
// Bind server progress to the strongly read assignment and retain the first time on retry.
async function bindPerformanceProgress({db,GetCommand,operation,driverId,orderId,eventField}){
 if(!['arrivedAtStoreAt','pickedUpAt','arrivedAtCustomerAt'].includes(eventField))throw Error('INVALID_PROGRESS_EVENT');
 const row=(await db.send(new GetCommand({TableName:operation.TableName,Key:operation.Key,ConsistentRead:true}))).Item;
 if(!row||row.orderId!==orderId||row.driverId!==driverId)throw Object.assign(Error('ASSIGNMENT_CHANGED'),{name:'ConditionalCheckFailedException'});
 if(!row.financialAcceptance)return operation;
 const offerId=row.financialAcceptance.offerId,attempt=row.assignmentAttemptCounter;
 if(typeof offerId!=='string'||!Number.isSafeInteger(attempt)||attempt<1)throw Object.assign(Error('ASSIGNMENT_CHANGED'),{name:'ConditionalCheckFailedException'});
 operation.ConditionExpression='('+operation.ConditionExpression+') AND financialAcceptance.offerId=:performanceOffer AND assignmentAttemptCounter=:performanceAttempt';
 operation.ExpressionAttributeValues={...operation.ExpressionAttributeValues,':performanceOffer':offerId,':performanceAttempt':attempt};
 const needle=eventField+' = :'+(eventField==='pickedUpAt'?'pickedUpAt':'arrivedAt');
 if(!operation.UpdateExpression.includes(needle))throw Error('INVALID_PROGRESS_UPDATE');
 operation.UpdateExpression=operation.UpdateExpression.replace(needle,eventField+' = if_not_exists('+eventField+', :'+(eventField==='pickedUpAt'?'pickedUpAt':'arrivedAt')+')');
 return operation;
}
module.exports={bindPerformanceProgress};
