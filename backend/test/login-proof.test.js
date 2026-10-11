const {test}=require('node:test');
const assert=require('node:assert/strict');
const {newProof,proofMatches}=require('../phone-auth/login-proof');
test('short-lived login proof is bound to identity and is single-use',()=>{
 const {answer,record}=newProof('secret','driver',100);
 assert.equal(proofMatches('secret',record,'driver',answer,101),true);
 assert.equal(proofMatches('secret',record,'other',answer,101),false);
 assert.equal(proofMatches('secret',record,'driver',answer,190),false);
 assert.equal(proofMatches('secret',{...record,used:true},'driver',answer,101),false);
 assert.equal(proofMatches('secret',record,'driver','123456',101),false);
 assert.notEqual(record.digest,answer);
});
