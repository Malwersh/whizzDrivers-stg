'use strict';
const types=['ItemUnavailable','StoreClosed','LongDelay','WrongOrder','Other'];
async function recordPickupIssue({db,GetCommand,UpdateCommand,table,driverId,orderId,body,now=()=>new Date().toISOString()}){
 const response=(statusCode,code,message)=>({statusCode,result:{success:false,code,message}});
 if(!body||Array.isArray(body)||typeof body!=='object'||Object.keys(body).some(k=>!['issueType','issueSource','notes','reportId','offerId','attempt'].includes(k))||!types.includes(body.issueType)||typeof body.reportId!=='string'||!/^[-a-zA-Z0-9]{8,80}$/.test(body.reportId)||body.issueSource!==undefined&&body.issueSource!=='Store'||body.notes!=null&&typeof body.notes!=='string')return response(400,'INVALID_PICKUP_ISSUE','بيانات البلاغ غير مكتملة');
 const notes=body.notes?.trim()||null;if(notes?.length>1000||body.issueType==='Other'&&!notes)return response(400,'INVALID_PICKUP_ISSUE','تحقق من تفاصيل المشكلة');
 const key={PK:'ORDER#'+orderId,SK:'META'},read=async()=>(await db.send(new GetCommand({TableName:table,Key:key,ConsistentRead:true}))).Item;
 const order=await read();if(!order||order.driverId!==driverId)return response(403,'ORDER_NOT_ASSIGNED','الطلب غير مسند إليك');
 if(!['assigned','accepted','heading_to_store','arrived_at_store'].includes(order.status)||order.pickedUpAt||order.pickupAt||order.merchantHandover)return response(409,'PICKUP_STAGE_REQUIRED','بلاغ الاستلام متاح قبل استلام الطعام فقط');
 const assignment=order.financialAcceptance?{offerId:body.offerId,attempt:body.attempt}:null;
 const same=r=>r&&r.driverId===driverId&&r.issueType===body.issueType&&r.notes===notes&&(assignment===null?r.assignment===null:r.assignment?.offerId===assignment.offerId&&r.assignment?.attempt===assignment.attempt);
 const prior=o=>o?.pickupIssueReports?.find(r=>r.id===body.reportId);
 const receipt=replayed=>({statusCode:200,result:{success:true,orderId,reportId:body.reportId,issueType:body.issueType,replayed,message:'تم حفظ بلاغ مشكلة الاستلام'}});
 const old=prior(order);if(old)return same(old)?receipt(true):response(409,'REPORT_CONFLICT','بيانات البلاغ تغيرت');
 if(assignment&&(assignment.offerId!==order.financialAcceptance.offerId||assignment.attempt!==order.assignmentAttemptCounter))return response(409,'ASSIGNMENT_CHANGED','حدّث الطلب قبل إرسال البلاغ');
 const at=now(),report={schemaVersion:1,id:body.reportId,issueType:body.issueType,notes,driverId,assignment,reportedAt:at};
 const values={':driver':driverId,':assigned':'assigned',':accepted':'accepted',':heading':'heading_to_store',':arrived':'arrived_at_store',':null':null,':id':body.reportId,':ids':new Set([body.reportId]),':empty':[],':reports':[report],':limit':50,':issue':{type:body.issueType,notes,reportedBy:driverId,reportedAt:at,reportId:body.reportId},':at':at};
 let condition='driverId = :driver AND #status IN (:assigned,:accepted,:heading,:arrived) AND (attribute_not_exists(pickedUpAt) OR pickedUpAt = :null) AND (attribute_not_exists(pickupAt) OR pickupAt = :null) AND (attribute_not_exists(merchantHandover) OR merchantHandover = :null) AND (attribute_not_exists(pickupIssueReportIds) OR NOT contains(pickupIssueReportIds,:id)) AND (attribute_not_exists(pickupIssueReports) OR size(pickupIssueReports) < :limit)';
 if(assignment){condition+=' AND financialAcceptance.offerId = :offer AND assignmentAttemptCounter = :attempt';values[':offer']=assignment.offerId;values[':attempt']=assignment.attempt;}
 else condition+=' AND (attribute_not_exists(financialAcceptance) OR financialAcceptance = :null)';
 try{await db.send(new UpdateCommand({TableName:table,Key:key,UpdateExpression:'SET storeIssue = :issue, storeIssueReportedAt = :at, updatedAt = :at, pickupIssueReports = list_append(if_not_exists(pickupIssueReports,:empty),:reports) ADD pickupIssueReportIds :ids',ConditionExpression:condition,ExpressionAttributeNames:{'#status':'status'},ExpressionAttributeValues:values}));return receipt(false);}
 catch{const current=await read();const old=prior(current);if(current?.driverId===driverId&&same(old))return receipt(true);return response(409,'PICKUP_ISSUE_UNCONFIRMED','لم يتأكد حفظ البلاغ؛ حدّث الطلب قبل إعادة المحاولة');}
}
module.exports={recordPickupIssue};
