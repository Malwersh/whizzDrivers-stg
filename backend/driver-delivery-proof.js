'use strict';
const {createHash}=require('node:crypto');
const MAX_BYTES=1500000,MAX_PHOTOS=3;
const reply=(statusCode,code)=>({statusCode,result:{success:false,code}});
const publicProof=p=>({id:p.id,uploadedAt:p.uploadedAt,sha256:p.sha256,bytes:p.bytes,contentType:'image/jpeg'});
async function deliveryProof({db,s3,GetCommand,UpdateCommand,PutObjectCommand,GetObjectCommand,table,bucket,driverId,orderId,body,proofId,beginUpload,now=()=>new Date().toISOString()}){
 if(!/^[-a-zA-Z0-9]{1,100}$/.test(orderId)||!bucket||!driverId)return reply(400,'INVALID_REQUEST');
 const key={PK:'ORDER#'+orderId,SK:'META'},read=async()=>(await db.send(new GetCommand({TableName:table,Key:key,ConsistentRead:true}))).Item;
 const order=await read();if(!order||order.driverId!==driverId)return reply(403,'ORDER_NOT_ASSIGNED');
 const photos=order.deliveryProofs||[];
 if(proofId!==undefined){
  if(proofId==='list')return {statusCode:200,result:{success:true,orderId,proofs:photos.map(publicProof)}};
  const photo=photos.find(p=>p.id===proofId&&p.driverId===driverId);if(!photo)return reply(404,'PROOF_NOT_FOUND');
  const object=await s3.send(new GetObjectCommand({Bucket:bucket,Key:photo.key}));
  if(object.ContentLength>MAX_BYTES)return reply(502,'INVALID_STORED_PROOF');
  const bytes=Buffer.from(await object.Body.transformToByteArray());
  if(bytes.length>MAX_BYTES||createHash('sha256').update(bytes).digest('hex')!==photo.sha256)return reply(502,'INVALID_STORED_PROOF');
  const latest=await read();if(latest?.driverId!==driverId)return reply(403,'ORDER_NOT_ASSIGNED');
  return {statusCode:200,result:{success:true,orderId,proof:publicProof(photo),fileData:bytes.toString('base64')}};
 }
 if(!body||Object.keys(body).some(k=>!['proofId','fileData','offerId','attempt'].includes(k))||!/^[-a-zA-Z0-9]{8,80}$/.test(body.proofId||'')||typeof body.fileData!=='string'||body.fileData.length>2000000||body.fileData.length%4!==0||!/^[A-Za-z0-9+/]*={0,2}$/.test(body.fileData))return reply(400,'INVALID_PHOTO');
 const bytes=Buffer.from(body.fileData,'base64');
 if(bytes.length<4||bytes.length>MAX_BYTES||bytes[0]!==255||bytes[1]!==216||bytes[2]!==255||bytes.at(-2)!==255||bytes.at(-1)!==217)return reply(400,'JPEG_REQUIRED');
 const hash=createHash('sha256').update(bytes).digest('hex');
 const prior=o=>(o?.deliveryProofs||[]).find(p=>p.id===body.proofId);
 const same=p=>p?.driverId===driverId&&p.sha256===hash;
 const receipt=(p,replayed)=>({statusCode:200,result:{success:true,orderId,proof:publicProof(p),replayed}});
 const old=prior(order);if(old)return same(old)?receipt(old,true):reply(409,'PROOF_ID_CONFLICT');
 if(!['arrived_at_customer','at_customer'].includes(order.status))return reply(409,'DELIVERY_STAGE_REQUIRED');
 if(photos.length>=MAX_PHOTOS)return reply(409,'PHOTO_LIMIT');
 const financial=order.financialAcceptance;
 if(financial&&(body.offerId!==financial.offerId||body.attempt!==order.assignmentAttemptCounter))return reply(409,'ASSIGNMENT_CHANGED');
 const photo={id:body.proofId,key:`drivers/${driverId}/delivery-proof/${orderId}/${body.proofId}-${hash}.jpg`,driverId,uploadedAt:now(),sha256:hash,bytes:bytes.length,contentType:'image/jpeg'};
 let finish;
 try {
  finish=await beginUpload();
  try { await s3.send(new PutObjectCommand({Bucket:bucket,Key:photo.key,Body:bytes,ContentType:'image/jpeg',ServerSideEncryption:'AES256',IfNoneMatch:'*',ChecksumSHA256:Buffer.from(hash,'hex').toString('base64')})); }
  catch(e){if(e?.$metadata?.httpStatusCode!==412)throw e;}
  const values={':driver':driverId,':arrived':'arrived_at_customer',':atCustomer':'at_customer',':id':body.proofId,':ids':new Set([body.proofId]),':empty':[],':photos':[photo],':limit':MAX_PHOTOS};
  let condition='driverId = :driver AND #status IN (:arrived,:atCustomer) AND (attribute_not_exists(deliveryProofIds) OR NOT contains(deliveryProofIds,:id)) AND (attribute_not_exists(deliveryProofs) OR size(deliveryProofs) < :limit)';
  if(financial){condition+=' AND financialAcceptance.offerId = :offer AND assignmentAttemptCounter = :attempt';values[':offer']=body.offerId;values[':attempt']=body.attempt;}
  else {condition+=' AND (attribute_not_exists(financialAcceptance) OR financialAcceptance = :null)';values[':null']=null;}
  try {await db.send(new UpdateCommand({TableName:table,Key:key,UpdateExpression:'SET deliveryProofs = list_append(if_not_exists(deliveryProofs,:empty),:photos) ADD deliveryProofIds :ids',ConditionExpression:condition,ExpressionAttributeNames:{'#status':'status'},ExpressionAttributeValues:values}));return receipt(photo,false);}
  catch {const latest=await read();const saved=prior(latest);return latest?.driverId===driverId&&same(saved)?receipt(saved,true):reply(409,'PROOF_ATTACHMENT_UNCONFIRMED');}
 } catch {return reply(503,'PROOF_UPLOAD_UNCONFIRMED');}
 finally{if(finish)try{await finish();}catch{console.error('Delivery proof operation requires reconciliation');}}
}
module.exports={deliveryProof,MAX_BYTES};
