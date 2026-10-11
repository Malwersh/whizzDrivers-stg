const { test } = require('node:test');
const assert = require('node:assert/strict');
const { defineChallenge, digest, matches } = require('../phone-auth/challenge-policy');
const event = session => ({request:{session},response:{}});
test('only successful custom challenges can issue tokens', () => {
  assert.equal(defineChallenge(event([])).response.challengeName, 'CUSTOM_CHALLENGE');
  assert.equal(defineChallenge(event([{challengeName:'CUSTOM_CHALLENGE',challengeResult:true}])).response.issueTokens, true);
  assert.equal(defineChallenge(event([{challengeName:'PASSWORD_VERIFIER',challengeResult:true}])).response.failAuthentication, true);
  assert.equal(defineChallenge(event(Array(5).fill({challengeName:'CUSTOM_CHALLENGE',challengeResult:false}))).response.failAuthentication, true);
  const missing=event([{challengeName:'CUSTOM_CHALLENGE',challengeResult:true}]); missing.request.userNotFound=true;
  assert.equal(defineChallenge(missing).response.issueTokens,false);
});
test('OTP binds to identity and session, expires, and cannot be reused', () => {
  const key='test-key'; const record={id:'session',username:'driver',expiresAt:300,attempts:0};
  record.digest=digest(key,record.id,record.username,'123456');
  assert.equal(matches(key,record,'driver','123456',299),true);
  for (const [patch,user,code,time] of [[{},'other','123456',1],[{},'driver','654321',1],[{},'driver','123456',300],[{used:true},'driver','123456',1],[{attempts:5},'driver','123456',1],[{id:'other-session'},'driver','123456',1]]) {
    assert.equal(matches(key,{...record,...patch},user,code,time),false);
  }
});
