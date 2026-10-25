'use strict';
const id=v=>typeof v==='string'&&/^[A-Za-z0-9][A-Za-z0-9_.:-]{0,199}$/.test(v);
const fail=code=>{throw Object.assign(Error(code),{code});};
function validReceipt(row,driverId){const r=row?.deviceDisplayReceipt;return r?.kind==='DRIVER_OFFER_DISPLAY_ACK_V1'&&r.driverId===driverId&&r.offerId===row.offerId&&r.orderId===row.orderId&&r.offerSentAt===row.sentAt&&r.offerExpiresAt===row.expiresAt&&Number.isFinite(Date.parse(r.receivedAt))&&Date.parse(r.receivedAt)>=Date.parse(row.sentAt)&&Date.parse(r.receivedAt)<Date.parse(row.expiresAt);}
async function acknowledgeDisplayedOffer({db,QueryCommand,GetCommand,TransactWriteCommand,driverId,value,now=()=>Date.now()}){
 if(!id(driverId)||!value||Object.keys(value).sort().join(',')!=='offerId,orderId'||![value.orderId,value.offerId].every(id))return fail('INVALID_OFFER_RECEIPT');
 let cursor,found=null,pages=0;
 do{const r=await db.send(new QueryCommand({TableName:'WaveOffers_staging',KeyConditionExpression:'orderId=:order',ExpressionAttributeValues:{':order':value.orderId},ConsistentRead:true,Limit:100,...(cursor?{ExclusiveStartKey:cursor}:{})}));
  for(const row of r.Items||[])if(row.kind==='FINANCIAL_DRIVER_OFFER'&&row.offerId===value.offerId&&row.driverId===driverId){if(found)return fail('OFFER_RECEIPT_UNAVAILABLE');found=row;}
  cursor=r.LastEvaluatedKey;
 }while(cursor&&++pages<5);
 if(cursor)return fail('OFFER_RECEIPT_UNAVAILABLE');
 const row=found;if(!row||row.kind!=='FINANCIAL_DRIVER_OFFER'||row.schemaVersion!==2)return fail('OFFER_RECEIPT_FORBIDDEN');
 const receiptKey={orderId:row.orderId,SK:'DISPLAY_ACK#'+row.offerId+'#'+driverId};
 const prior=(await db.send(new GetCommand({TableName:'WaveOffers_staging',Key:receiptKey,ConsistentRead:true}))).Item;
 if(validReceipt({...row,deviceDisplayReceipt:prior},driverId))return {success:true,acknowledged:true,replayed:true,receivedAt:prior.receivedAt};
 const at=new Date(now()).toISOString();
 if(row.responseStatus!=='financial_pending'||row.isWinner!==false||!Number.isFinite(Date.parse(row.sentAt))||!Number.isFinite(Date.parse(row.expiresAt))||Date.parse(row.sentAt)>now()||Date.parse(row.expiresAt)<=now())return {success:true,acknowledged:false,reason:'OFFER_NOT_AVAILABLE'};
 const receipt={kind:'DRIVER_OFFER_DISPLAY_ACK_V1',driverId,orderId:row.orderId,offerId:row.offerId,receivedAt:at,offerSentAt:row.sentAt,offerExpiresAt:row.expiresAt};
 try{await db.send(new TransactWriteCommand({TransactItems:[
  {ConditionCheck:{TableName:'staging-AccountDeletion',Key:{pk:'ACCOUNT_LIFECYCLE#DRIVER#'+driverId,sk:'META'},ConditionExpression:'attribute_not_exists(pk)'}},
  {ConditionCheck:{TableName:'WaveOffers_staging',Key:{orderId:row.orderId,SK:row.SK},ConditionExpression:'driverId=:driver AND offerId=:offer AND #state=:pending AND isWinner=:no AND sentAt=:sent AND expiresAt=:expires AND expiresAt>:now',ExpressionAttributeNames:{'#state':'responseStatus'},ExpressionAttributeValues:{':driver':driverId,':offer':row.offerId,':pending':'financial_pending',':no':false,':sent':row.sentAt,':expires':row.expiresAt,':now':at}}},
  {Put:{TableName:'WaveOffers_staging',Item:{...receiptKey,...receipt,offerSK:row.SK},ConditionExpression:'attribute_not_exists(orderId)'}}
 ]}));}
 catch(error){if(!['ConditionalCheckFailedException','TransactionCanceledException'].includes(error.name))throw error;const current=(await db.send(new GetCommand({TableName:'WaveOffers_staging',Key:receiptKey,ConsistentRead:true}))).Item;if(validReceipt({...row,deviceDisplayReceipt:current},driverId))return {success:true,acknowledged:true,replayed:true,receivedAt:current.receivedAt};return {success:true,acknowledged:false,reason:'OFFER_CHANGED'};}

 return {success:true,acknowledged:true,replayed:false,receivedAt:at};
}
module.exports={acknowledgeDisplayedOffer,validReceipt};
