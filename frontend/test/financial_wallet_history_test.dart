import 'package:flutter_test/flutter_test.dart';
import 'package:wizz_driver/models/wallet_transaction.dart';
Map<String,dynamic> row(String bucket, String category, int amount) => {
  'walletId':'WALLET#DRIVER#d','sk':'ts#2026-10-17T22:47:00Z#$bucket#operation',
  'type':amount<0?'DEBIT':'CREDIT','category':category,'amount':amount,
  'createdAt':'2026-10-17T22:47:00Z','relatedEntityType':'ORDER','relatedEntityId':'order1',
  'metadata':{'balanceType':bucket,'financialSchemaVersion':2,'orderId':'order1'},
};
void main(){
 test('a financial hold has two balanced accounting rows but one visible neutral driver event',(){
  final rows=[WalletTransaction.fromJson(row('AVAILABLE','HOLD_CREATED',-7500)),WalletTransaction.fromJson(row('LOCKED','HOLD_CREATED',7500))];
  final visible=WalletTransaction.driverVisible(rows);expect(visible.length,1);expect(visible.single.amount,7500);expect(visible.single.amountSign,'');
  expect(WalletTransaction.fromJson(rows.last.toJson()).isInternalMirror,isTrue);
 });
 test('financial completion labels capture and does not hide the real deduction',(){
  final t=WalletTransaction.fromJson(row('LOCKED','COD_COMPLETED',-7500));expect(t.isHoldCaptured,isTrue);expect(t.isInternalMirror,isFalse);
  expect(t.statusLabel,'خُصم عند التسليم');expect(t.amountSign,'-');expect(t.relatedOrderId,'order1');
 });
 test('ordinary locked credits are not hidden as hold mirrors',(){
  final t=WalletTransaction.fromJson(row('LOCKED','TRANSFER',7500));expect(t.isInternalMirror,isFalse);
 });
}
