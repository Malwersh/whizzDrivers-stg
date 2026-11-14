const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
test('driver response wrapper removes internal rollout pins from individual and nested order responses',async()=>{
 const source=fs.readFileSync(path.resolve(__dirname,'../lambda_driver_api_v2.js'),'utf8'),a=source.indexOf('exports.handler = event => driverRequestContext.run('),b=source.indexOf('const handleRequest = async',a),exports={};
 const response={statusCode:200,body:JSON.stringify({order:{orderId:'o',financeRollout:{scopeId:'PRIVATE'}},orders:[{orderId:'o',financeRollout:{scopeId:'PRIVATE'}}]})};
 vm.runInNewContext(source.slice(a,b),{exports,driverRequestContext:{run:(_,fn)=>fn()},handleRequest:async()=>response});
 const result=JSON.parse((await exports.handler({})).body);assert.equal(result.order.financeRollout,undefined);assert.equal(result.orders[0].financeRollout,undefined);assert.equal(result.order.orderId,'o');
});
