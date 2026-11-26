'use strict';
// Read-only, versioned interpretation of verified modern personal offers.
// Does not write legacy metrics, live state, financial data or dispatch policy.
const {validReceipt}=require('./driver-offer-display-receipt');
const {classifyTiming,POLICY:TIMING_POLICY}=require('./driver-performance-timing-273');
const {applyTimingReview}=require('./driver-timing-review');
const {readRatingWindow}=require('./driver-rating-window-281');
const RULES='OBSERVED_DRIVER_PERFORMANCE_V2';
const validId=v=>typeof v==='string'&&/^[A-Za-z0-9][A-Za-z0-9_.:-]{0,199}$/.test(v);
const date=v=>typeof v==='string'&&Number.isFinite(Date.parse(v));
function offerDecision(row,driverId){
 if(!row||row.driverId!==driverId||row.kind!=='FINANCIAL_DRIVER_OFFER'||row.schemaVersion!==2||!validId(row.offerId)||!validId(row.orderId)||!date(row.sentAt))return null;
 if(row.responseStatus!=='financial_expired'&&!date(row.responseAt))return null;
 if(row.responseStatus==='financial_accepted'&&row.isWinner===true&&row.financialReceipt?.success===true&&row.financialReceipt.driverId===driverId&&row.financialReceipt.offerId===row.offerId&&row.financialReceipt.orderId===row.orderId&&Number.isSafeInteger(row.financialReceipt.assignmentAttempt)&&row.financialReceipt.assignmentAttempt>0)return 'ACCEPTED';
 if(row.responseStatus==='financial_declined'&&row.isWinner===false&&date(row.expiresAt)&&Date.parse(row.responseAt)<=Date.parse(row.expiresAt))return 'DECLINED';
 if(row.responseStatus==='financial_expired'&&row.isWinner===false&&validReceipt(row,driverId))return 'EXPIRED_DELIVERED';
 return null;
}
function findingDecision(record,review){
 if(!record||record.kind!=='ORDER_EXCEPTION_FINDING'||record.decisionStatus!=='CONFIRMED'||record.caseId!==review.caseId||record.findingId!==review.activeResponsibilityFindingId||!Array.isArray(record.allocations)||!record.allocations.length)return 'REVIEW';
 const seen=new Set();let sum=0,driver=0;
 for(const a of record.allocations){if(!['DRIVER','MERCHANT','CUSTOMER','PLATFORM'].includes(a.party)||seen.has(a.party)||!Number.isSafeInteger(a.basisPoints)||a.basisPoints<1||a.basisPoints>10000)return 'REVIEW';seen.add(a.party);sum+=a.basisPoints;if(a.party==='DRIVER')driver=a.basisPoints;}
 if(sum!==10000)return 'REVIEW';
 return driver===10000?'DRIVER_FAILURE':driver===0?'EXCLUDED_NO_FAULT':'REVIEW';
}
async function commitmentDecision(offer,readOrder,readHold){
 const o=await readOrder(offer.orderId),attempt=offer.financialReceipt.assignmentAttempt;
 const same=o&&o.orderId===offer.orderId&&o.driverId===offer.driverId&&o.financialAcceptance?.offerId===offer.offerId&&o.assignmentAttemptCounter===attempt;
 if(same&&['delivered','completed'].includes(o.status)&&o.walletFinancialStatus==='SETTLED'&&typeof o.financialOutcome==='string'&&o.financialOutcome)return 'FULFILLED';
 if(same&&o.status==='returned'&&o.returnStatus==='CONFIRMED'&&o.walletFinancialStatus==='RETURNED'&&typeof o.financialOutcome==='string'&&o.financialOutcome)return 'FULFILLED_RETURN';
 const decision=await readHold(offer.orderId,'DRIVER_PERFORMANCE#'+offer.driverId+'#'+attempt);
 if(decision){
  if(decision.kind!=='DRIVER_PERFORMANCE_DECISION'||decision.schemaVersion!==1||decision.orderId!==offer.orderId||decision.offerId!==offer.offerId||decision.driverId!==offer.driverId||decision.attempt!==attempt||decision.actorKind!=='STAFF'||!validId(decision.decisionId)||!validId(decision.caseId)||!['CUSTOMER_CANCELLATION','MERCHANT_CANCELLATION'].includes(decision.caseKey)&&!/^RETURN#[1-9][0-9]{0,2}$/.test(decision.caseKey||''))return 'REVIEW';
  const review=await readHold(offer.orderId,decision.caseKey);
  if((review?.caseId??review?.exceptionResolution?.caseId)!==decision.caseId||review.appealReviewRequired||(review.caseAppeals||[]).some(a=>a.status==='OPEN')||!(review.driverPerformanceDecisions||[]).some(d=>d.decisionId===decision.decisionId&&d.driverId===offer.driverId&&d.attempt===attempt&&d.decision===decision.decision))return 'REVIEW';
  return decision.decision==='COUNT_FAILURE'?'DRIVER_FAILURE':decision.decision==='EXCUSED'?'EXCLUDED_NO_FAULT':'REVIEW';
 }
 if(!same||['cancelled','canceled','returned','delivered','completed'].includes(o.status))return 'REVIEW';
 return ['assigned','heading_to_store','arrived_at_store','picked_up','heading_to_customer','arrived_at_customer','returning','return_arrived','ready','ready_for_pickup'].includes(o.status)?'IN_PROGRESS':'REVIEW';
}
async function readPerformance({db,GetCommand,QueryCommand,driverId,tables,now=()=>Date.now(),maxPages=10,windowSize=100,rulesVersion=2}){
 if(!validId(driverId)||!tables?.offers||!tables?.orders||!tables?.holds||!tables?.drivers)throw Error('PERFORMANCE_UNAVAILABLE');
 const started=Date.now();
 const asOf=new Date(now()).toISOString(), decisions=[],commitments=[],offerEvents=[],activityAccepted=[],activityExpiries=[],seen=new Set(),attempts=new Set();
 const activitySince=new Date(Date.parse(asOf)-30*86400000).toISOString();let activityBoundarySeen=false,activityLegacyExcluded=0;
 let consecutiveRejections=0,streakComplete=false;const streakEvents=[];let oldestScannedOffer=Infinity;
 let cursor,pages=0,rowsRead=0,unconfirmed=0,withdrawn=0,legacy=0,legacyInWindow=0,exhausted=false;
 do{
  const result=await db.send(new QueryCommand({TableName:tables.offers,IndexName:'driverId-sentAt-index',KeyConditionExpression:'driverId=:driver AND sentAt<=:asOf',ExpressionAttributeValues:{':driver':driverId,':asOf':asOf},ScanIndexForward:false,Limit:100,...(cursor?{ExclusiveStartKey:cursor}:{})}));
  const rows=result.Items||[];rowsRead+=rows.length;
  for(let i=0;i<rows.length;i+=5){
   const current=await Promise.all(rows.slice(i,i+5).map(async row=>{
    if(row.driverId!==driverId||!validId(row.orderId)||typeof row.SK!=='string')throw Error('PERFORMANCE_UNAVAILABLE');
    return (await db.send(new GetCommand({TableName:tables.offers,Key:{orderId:row.orderId,SK:row.SK},ConsistentRead:true}))).Item;
   }));
   for(const row of current){
    if(!row)continue;
    if(date(row.sentAt)){oldestScannedOffer=Math.min(oldestScannedOffer,Date.parse(row.sentAt));if(Date.parse(row.sentAt)<Date.parse(activitySince))activityBoundarySeen=true;}
    if(row.driverId!==driverId)throw Error('PERFORMANCE_UNAVAILABLE');
    if(!validId(row.offerId)||seen.has(row.offerId))continue;seen.add(row.offerId);
    const inOfferWindow=decisions.length<windowSize;
    if(row.kind!=='FINANCIAL_DRIVER_OFFER'||row.schemaVersion!==2){legacy++;if(inOfferWindow)legacyInWindow++;if(date(row.sentAt)&&Date.parse(row.sentAt)>=Date.parse(activitySince))activityLegacyExcluded++;continue;}
    if(rulesVersion>=2&&row.responseStatus==='financial_expired'){const receipt=(await db.send(new GetCommand({TableName:tables.offers,Key:{orderId:row.orderId,SK:'DISPLAY_ACK#'+row.offerId+'#'+driverId},ConsistentRead:true}))).Item;if(receipt?.offerSK===row.SK)row.deviceDisplayReceipt=receipt;}
    const observed=offerDecision(row,driverId),decision=rulesVersion===1&&observed==='EXPIRED_DELIVERED'?null:observed;
    if(decision){const at=Date.parse(decision==='EXPIRED_DELIVERED'?row.expiresAt:row.responseAt);if(Number.isFinite(at)&&at<=Date.parse(asOf))streakEvents.push({status:decision,at});}
    if(decision&&decisions.length<windowSize){decisions.push(decision);offerEvents.push({orderId:row.orderId,offerId:row.offerId,sentAt:row.sentAt,occurredAt:row.responseAt||row.expiresAt,status:decision});}
    if(decision==='ACCEPTED'&&Date.parse(row.responseAt)>=Date.parse(activitySince)&&Date.parse(row.responseAt)<=Date.parse(asOf)){activityAccepted.push(row.offerId);activityExpiries.push(Date.parse(row.responseAt)+30*86400000+1);}
    if(decision==='ACCEPTED'&&commitments.length<windowSize){const key=row.orderId+':'+row.financialReceipt.assignmentAttempt;if(!attempts.has(key)){attempts.add(key);commitments.push(row);}}
    if(!decision&&inOfferWindow){if(['order_assigned_to_other','financial_withdrawn','withdrawn'].includes(row.responseStatus))withdrawn++;else if(['financial_expired','expired'].includes(row.responseStatus)||Date.parse(row.expiresAt)<=Date.parse(asOf))unconfirmed++;}
   }
  }
  cursor=result.LastEvaluatedKey;pages++;exhausted=!cursor;
  if(decisions.length>=windowSize&&commitments.length>=windowSize&&(rulesVersion<3||activityBoundarySeen))break;
 }while(cursor&&pages<maxPages&&Date.now()-started<15000);
 // A later response to an older offer can reset a newer offer's rejection.
 // At identical timestamps an acceptance wins conservatively; never invent a penalty.
 streakEvents.sort((a,b)=>b.at-a.at||(a.status===b.status?0:a.status==='ACCEPTED'?-1:b.status==='ACCEPTED'?1:0));
 const latestAcceptance=streakEvents.find(e=>e.status==='ACCEPTED');
 for(const event of streakEvents){if(event.status==='ACCEPTED')break;consecutiveRejections++;}
 // All supported financial offers expire within 15 minutes; otherwise require exhaustion.
 streakComplete=exhausted||!!latestAcceptance&&oldestScannedOffer+900000<=latestAcceptance.at;
 const read=async(table,key)=>(await db.send(new GetCommand({TableName:table,Key:key,ConsistentRead:true}))).Item;
 const orderCache=new Map();const readOrder=id=>{if(!orderCache.has(id))orderCache.set(id,read(tables.orders,{PK:'ORDER#'+id,SK:'META'}));return orderCache.get(id);};
 const outcomes=[];
 for(let i=0;i<commitments.length;i+=5)outcomes.push(...await Promise.all(commitments.slice(i,i+5).map(offer=>commitmentDecision(offer,readOrder,(id,sk)=>read(tables.holds,{orderId:id,sk})))));
 const accepted=decisions.filter(x=>x==='ACCEPTED').length,declined=decisions.filter(x=>x==='DECLINED').length,expiredDelivered=decisions.filter(x=>x==='EXPIRED_DELIVERED').length;
 const completed=outcomes.filter(x=>x==='FULFILLED').length,returned=outcomes.filter(x=>x==='FULFILLED_RETURN').length,failed=outcomes.filter(x=>x==='DRIVER_FAILURE').length,review=outcomes.filter(x=>x==='REVIEW').length,inProgress=outcomes.filter(x=>x==='IN_PROGRESS').length,excluded=outcomes.filter(x=>x==='EXCLUDED_NO_FAULT').length;
 const samples=completed+returned+failed,offerComplete=exhausted||decisions.length>=windowSize,commitmentComplete=exhausted||commitments.length>=windowSize;
 const profile=await read(tables.drivers,{driverId});
 const rating=profile?.customerRating,count=profile?.customerRatingCount;
 const ratingValid=typeof rating==='number'&&Number.isFinite(rating)&&rating>=1&&rating<=5&&Number.isSafeInteger(count)&&count>0;
 const extended={};
 if(rulesVersion>=4){extended.ratingWindow=await readRatingWindow({db,GetCommand,QueryCommand,driverId,tables,readOrder,now});}
 if(rulesVersion>=3){
  extended.ratingAllTime={average:ratingValid?rating:null,count:ratingValid?count:0,basis:'ALL_TIME_VERIFIED_CUSTOMER_RATINGS'};
  extended.ratingReview={underReview:Number.isSafeInteger(profile?.customerRatingUnderReviewCount)&&profile.customerRatingUnderReviewCount>=0?profile.customerRatingUnderReviewCount:0,excluded:Number.isSafeInteger(profile?.customerRatingExcludedCount)&&profile.customerRatingExcludedCount>=0?profile.customerRatingExcludedCount:0,basis:'ALL_TIME_VERIFIED_CUSTOMER_RATINGS',affectsEligibility:false};
  const timingEvents=[];
  for(let i=0;i<commitments.length;i+=5)timingEvents.push(...await Promise.all(commitments.slice(i,i+5).map(async offer=>{
   const order=await readOrder(offer.orderId),original=classifyTiming(offer,order,asOf);
   const review=await read(tables.holds,{orderId:offer.orderId,sk:'DRIVER_SERVICE#'+offer.financialReceipt.assignmentAttempt});
   const event=review?.decision?.id&&validId(review.decision.id)?await read(tables.holds,{orderId:offer.orderId,sk:'SERVICE_REVIEW_EVENT#'+review.decision.id}):null;
   return {orderId:offer.orderId,offerId:offer.offerId,attempt:offer.financialReceipt.assignmentAttempt,occurredAt:offer.financialReceipt.acceptedAt||offer.responseAt,...applyTimingReview(original,offer,order,review,event),...(offer.performanceTiming?{targets:{pickupTargetAt:offer.performanceTiming.pickupTargetAt,customerTargetAt:offer.performanceTiming.customerTargetAt,graceSeconds:offer.performanceTiming.graceSeconds}}:{})};
  })));
  const onTime=timingEvents.filter(e=>e.status==='ON_TIME').length,late=timingEvents.filter(e=>e.status==='LATE_OBSERVED').length,timingReview=timingEvents.filter(e=>e.status==='REVIEW').length,excusedExcluded=timingEvents.filter(e=>e.reason==='VERIFIED_DELAY_EXCUSED').length,timingExcluded=timingEvents.filter(e=>e.status==='EXCLUDED'&&e.reason!=='VERIFIED_DELAY_EXCUSED').length,timingPending=timingEvents.filter(e=>e.status==='IN_PROGRESS').length;
  extended.onTimeRate=onTime+late?onTime/(onTime+late):null;
  extended.onTimeRateStatus=onTime+late?(timingReview||timingExcluded||!commitmentComplete?'PROVISIONAL':'AVAILABLE'):'INSUFFICIENT_DATA';
  extended.punctuality={policyVersion:TIMING_POLICY,onTime,lateObserved:late,sampleSize:onTime+late,reviewExcluded:timingReview,unavailableExcluded:timingExcluded,excusedExcluded,inProgress:timingPending,windowSize,windowComplete:commitmentComplete,graceSeconds:300,eventBasis:'SERVER_RECORDED_DRIVER_STATUS',attribution:'OBSERVATION_ONLY_NO_AUTOMATIC_DRIVER_FAULT',affectsEligibility:false};
  const activityComplete=exhausted||activityBoundarySeen;
  extended.activity={periodDays:30,fromInclusive:activitySince,untilInclusive:asOf,nextChangeAt:activityExpiries.length?new Date(Math.min(...activityExpiries)).toISOString():null,accepted:activityAccepted.length,status:!activityComplete?'PARTIAL':activityLegacyExcluded?'PROVISIONAL':'AVAILABLE',coverageComplete:activityComplete,legacyExcluded:activityLegacyExcluded,basis:'VERIFIED_ACCEPTANCES_IN_BOUNDED_OFFER_HISTORY',affectsEligibility:false};
  extended.details={acceptance:offerEvents,completion:commitments.map((o,i)=>({orderId:o.orderId,offerId:o.offerId,attempt:o.financialReceipt.assignmentAttempt,occurredAt:o.financialReceipt.acceptedAt||o.responseAt,status:outcomes[i]})),punctuality:timingEvents,...(rulesVersion>=4?{rating:extended.ratingWindow.events}:{})};
 }
 return {...extended,schemaVersion:1,rulesVersion:rulesVersion>=4?'OBSERVED_DRIVER_PERFORMANCE_V4':rulesVersion>=3?'OBSERVED_DRIVER_PERFORMANCE_V3':rulesVersion===2?RULES:'OBSERVED_DRIVER_PERFORMANCE_V1',updatedAt:asOf,windowSize,readCoverage:{pages,rowsRead,exhausted,offerComplete,commitmentComplete,legacyExcluded:legacy},
  acceptanceRate:decisions.length?accepted/decisions.length:null,acceptanceRateStatus:!decisions.length?'INSUFFICIENT_DATA':!offerComplete||unconfirmed||legacyInWindow?'PROVISIONAL':'AVAILABLE',
  acceptance:{accepted,declined,expiredDelivered,sampleSize:decisions.length,unconfirmedExcluded:unconfirmed,withdrawnExcluded:withdrawn,basis:'VERIFIED_RESPONSES_AND_DEVICE_DISPLAYED_TIMEOUTS',windowComplete:offerComplete},
  completionRate:samples?(completed+returned)/samples:null,completionRateStatus:!samples?'INSUFFICIENT_DATA':review||!commitmentComplete?'PROVISIONAL':'AVAILABLE',
  completion:{completed,returned,driverFailures:failed,sampleSize:samples,acceptedCommitments:commitments.length,inProgress,reviewExcluded:review,noFaultExcluded:excluded,windowComplete:commitmentComplete},
  rejections:{consecutive:consecutiveRejections,windowComplete:streakComplete||exhausted,basis:'VERIFIED_DECLINES_AND_DISPLAYED_TIMEOUTS_SINCE_LAST_ACCEPTANCE',status:streakComplete||exhausted?'AVAILABLE':'PARTIAL'},
  customerRating:rulesVersion>=4?extended.ratingWindow.average:ratingValid?rating:null,customerRatingCount:rulesVersion>=4?extended.ratingWindow.count:ratingValid?count:0,
  dispatchEffect:'EXISTING_CAPTURED_WAVE_RULES_UNCHANGED',notImplemented:rulesVersion>=3?['QUALITY_SCORE','REWARD_TIERS']:['ON_TIME_ATTRIBUTION','QUALITY_SCORE','REWARD_TIERS']};
}
module.exports={readPerformance,offerDecision,commitmentDecision,findingDecision,RULES};
