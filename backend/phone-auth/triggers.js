'use strict';
const crypto = require('node:crypto');
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, GetCommand, PutCommand, UpdateCommand, TransactWriteCommand } = require('@aws-sdk/lib-dynamodb');
const { SecretsManagerClient, GetSecretValueCommand } = require('@aws-sdk/client-secrets-manager');
const { CognitoIdentityProviderClient, AdminUpdateUserAttributesCommand } = require('@aws-sdk/client-cognito-identity-provider');
const cognito = new CognitoIdentityProviderClient({});
const { proofMatches } = require('./login-proof');
const { normalizeIraqiPhone } = require('./iraqi-phone');
const { defineChallenge, digest, matches, MAX_ATTEMPTS, TTL_SECONDS } = require('./challenge-policy');
const db = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const secrets = new SecretsManagerClient({});
let secretCache;
async function config() {
  if (!secretCache) {
    const value = await secrets.send(new GetSecretValueCommand({SecretId:process.env.OTP_SECRET_ARN}));
    const parsed = JSON.parse(value.SecretString);
    if (!parsed.apiKey || !parsed.hmacKey) throw new Error('OTP configuration unavailable');
    secretCache=parsed;
  }
  return secretCache;
}
const now = () => Math.floor(Date.now()/1000);
async function create(event) {
  if (event.request.userNotFound) throw new Error('Unable to start authentication');
  if (event.request.userAttributes.phone_number_verified !== 'true') {
    throw new Error('Phone enrollment required before custom authentication');
  }
  const phone = normalizeIraqiPhone(event.request.userAttributes.phone_number);
  const {Item:login} = await db.send(new GetCommand({TableName:process.env.OTP_TABLE,Key:{id:`LOGIN#${event.userName}`},ConsistentRead:true}));
  if (login && login.expiresAt > now()) {
    const {Item:proof} = await db.send(new GetCommand({TableName:process.env.OTP_TABLE,Key:{id:login.proofId},ConsistentRead:true}));
    if (proof && proof.username===event.userName && proof.purpose==='login-proof' && !proof.used && proof.expiresAt>now()) {
      event.response.privateChallengeParameters={id:proof.id};
      event.response.publicChallengeParameters={method:'verified-phone'};
      event.response.challengeMetadata=proof.id;
      return event;
    }
  }
  const previous = (event.request.session || []).at(-1);
  if (previous) {
    // Incorrect answers continue the same challenge: no additional SMS or new lifetime.
    const id = previous.challengeMetadata;
    const {Item} = await db.send(new GetCommand({TableName:process.env.OTP_TABLE,Key:{id},ConsistentRead:true}));
    if (!Item || Item.username !== event.userName || Item.expiresAt <= now()) throw new Error('Challenge expired');
    event.response.privateChallengeParameters={id};
    event.response.publicChallengeParameters={phoneNumber:phone,expiresAt:String(Item.expiresAt)};
    event.response.challengeMetadata=id;
    return event;
  }
  const secret=await config(); const time=now();
  // Atomic phone cooldown also stops bypass through direct Cognito InitiateAuth.
  await db.send(new TransactWriteCommand({TransactItems:[
    {Update:{TableName:process.env.OTP_TABLE,Key:{id:`COOLDOWN#${phone}`},
      UpdateExpression:'SET nextAllowedAt = :next, expiresAt = :ttl',
      ConditionExpression:'attribute_not_exists(nextAllowedAt) OR nextAllowedAt <= :now',
      ExpressionAttributeValues:{':next':time+60,':ttl':time+86400,':now':time}}},
    {Update:{TableName:process.env.OTP_TABLE,Key:{id:`DAILY#${Math.floor(time/86400)}#${phone}`},
      UpdateExpression:'SET expiresAt = :ttl ADD sends :one',
      ConditionExpression:'attribute_not_exists(sends) OR sends < :limit',
      ExpressionAttributeValues:{':ttl':time+172800,':one':1,':limit':10}}}
  ]}));
  const id=crypto.randomUUID(); const code=String(crypto.randomInt(0,1000000)).padStart(6,'0');
  const record={id,username:event.userName,phone,expiresAt:time+TTL_SECONDS,attempts:0,used:false,digest:digest(secret.hmacKey,id,event.userName,code)};
  await db.send(new PutCommand({TableName:process.env.OTP_TABLE,Item:record,ConditionExpression:'attribute_not_exists(id)'}));
  const response=await fetch('https://api.otpiq.com/api/sms',{method:'POST',headers:{Authorization:`Bearer ${secret.apiKey}`,'Content-Type':'application/json'},
    body:JSON.stringify({phoneNumber:phone.slice(1),smsType:'verification',provider:'whatsapp-telegram-sms',verificationCode:code}),signal:AbortSignal.timeout(3500)});
  if (!response.ok) throw new Error('Unable to deliver verification code');
  event.response.privateChallengeParameters={id};
  event.response.publicChallengeParameters={phoneNumber:phone,expiresAt:String(record.expiresAt)};
  event.response.challengeMetadata=id;
  return event;
}
async function verify(event) {
  event.response.answerCorrect=false;
  const id=event.request.privateChallengeParameters?.id;
  if (!id || event.request.userNotFound) return event;
  const {Item:record}=await db.send(new GetCommand({TableName:process.env.OTP_TABLE,Key:{id},ConsistentRead:true}));
  const secret=await config(); const time=now();
  const correct=record?.purpose==='login-proof'
    ? proofMatches(secret.hmacKey,record,event.userName,event.request.challengeAnswer,time)
    : matches(secret.hmacKey,record,event.userName,event.request.challengeAnswer,time);
  if (!record || record.username!==event.userName) return event;
  try {
    await db.send(new UpdateCommand({TableName:process.env.OTP_TABLE,Key:{id},
      UpdateExpression:correct?'SET used = :true ADD attempts :one':'ADD attempts :one',
      ConditionExpression:'username = :username AND used = :false AND expiresAt > :now AND attempts < :max',
      ExpressionAttributeValues:{':username':event.userName,':false':false,':now':time,':max':MAX_ATTEMPTS,':one':1,...(correct?{':true':true}:{})}}));
    if (correct) {
      await cognito.send(new AdminUpdateUserAttributesCommand({UserPoolId:event.userPoolId,Username:event.userName,
        UserAttributes:[{Name:'phone_number_verified',Value:'true'}]}));
    }
    event.response.answerCorrect=correct;
  } catch(error) { if(error.name!=='ConditionalCheckFailedException') throw error; }
  return event;
}
exports.handler=async event => {
  if (event.triggerSource==='DefineAuthChallenge_Authentication') return defineChallenge(event);
  if (event.triggerSource==='CreateAuthChallenge_Authentication') return create(event);
  if (event.triggerSource==='VerifyAuthChallengeResponse_Authentication') return verify(event);
  throw new Error('Unsupported authentication trigger');
};
