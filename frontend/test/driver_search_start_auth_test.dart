import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wizz_driver/services/driver_search_api_service.dart';

void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 test('profile errors do not masquerade as awaiting approval', () async {
  for (final status in [401, 403, 500]) {
   await expectLater(DriverSearchApiService.checkSearchEligibility(
    tokenProvider: () async => 'current',
    client: MockClient((_) async => http.Response('{}', status))),
    throwsA(isA<DriverSearchStartException>().having((e)=>e.code,'code',status==401?'AUTH_REQUIRED':'PROFILE_UNAVAILABLE')));
  }
 });
 test('only a successful explicit unverified profile shows approval refusal', () async {
  await expectLater(DriverSearchApiService.checkSearchEligibility(tokenProvider:()async=>'current',client:MockClient((_)async=>http.Response('{"data":{"isVerified":false}}',200))),throwsA(isA<DriverSearchStartException>().having((e)=>e.code,'code','APPROVAL_REQUIRED')));
  await DriverSearchApiService.checkSearchEligibility(tokenProvider:()async=>'current',client:MockClient((r)async{expect(r.headers['Authorization'],'Bearer current');return http.Response('{"data":{"isVerified":true}}',200);}));
 });
 test('position refresh uses current auth and reports server failure', () async {
  final ok=await DriverSearchApiService.refreshSearchPosition(latitude:31.9,longitude:44.4,tokenProvider:()async=>'current',client:MockClient((r)async{expect(r.url.path,endsWith('/driver/update-location'));expect(r.headers['Authorization'],'Bearer current');expect(jsonDecode(r.body),{'lat':31.9,'lng':44.4});return http.Response('{"success":true}',200);}));
  expect(ok,true);
  expect(await DriverSearchApiService.refreshSearchPosition(latitude:31.9,longitude:44.4,tokenProvider:()async=>'current',client:MockClient((_)async=>http.Response('{}',503))),false);
 });
 test('start search uses the current session instead of stale preferences',()async{
  SharedPreferences.setMockInitialValues({'auth_token':'expired','id_token':'old-id'});
  var requested=0;
  final result=await DriverSearchApiService.startSearching(latitude:31.9,longitude:44.4,tokenProvider:()async=>'fresh-session',client:MockClient((request)async{
   requested++;expect(request.headers['Authorization'],'Bearer fresh-session');expect(jsonDecode(request.body),{'lat':31.9,'lng':44.4});
   return http.Response(jsonEncode({'success':true,'data':{}}),200);
  }));
  expect(result['success'],true);expect(requested,1);
 });
 test('missing current session cannot fall back to the stale token',()async{
  SharedPreferences.setMockInitialValues({'auth_token':'expired'});
  final result=await DriverSearchApiService.startSearching(latitude:31.9,longitude:44.4,tokenProvider:()async=>null,client:MockClient((_)async=>throw StateError('No request expected')));
  expect(result['code'],'AUTH_REQUIRED');expect(result['success'],false);
 });
 test('expired session is reported as authentication failure',()async{
  final result=await DriverSearchApiService.startSearching(latitude:31.9,longitude:44.4,tokenProvider:()async=>'rejected-session',client:MockClient((_)async=>http.Response('{"message":"Unauthorized"}',401)));
  expect(result['code'],'AUTH_REQUIRED');expect(result['message'],contains('جلسة الدخول'));expect(result['message'],isNot(contains('الإنترنت')));
 });
 test('region refusal keeps the server reason instead of claiming network loss',()async{
  final result=await DriverSearchApiService.startSearching(latitude:31.9,longitude:44.4,tokenProvider:()async=>'session',client:MockClient((_)async=>http.Response(jsonEncode({'message':'المنطقة غير متاحة'}),403,headers:{'content-type':'application/json; charset=utf-8'})));
  expect(result['success'],false);expect(result['message'],'المنطقة غير متاحة');
 });
}
