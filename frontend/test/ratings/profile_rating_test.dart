import 'package:flutter_test/flutter_test.dart';
import 'package:wizz_driver/models/driver_profile.dart';
void main(){
 test('verified customer rating wins over legacy profile rating and survives cache/copy',(){
  final p=DriverProfile.fromJson({'driverId':'d','name':'سائق','rating':4.9,'customerRating':3.5,'customerRatingCount':2});
  expect(p.rating,3.5);expect(p.customerRatingCount,2);
  expect(DriverProfile.fromJson(p.toJson()).rating,3.5);
  expect(p.copyWith(name:'updated').customerRatingCount,2);
 });
 test('count alone cannot turn an old rating into a verified customer rating', () {
   final p = DriverProfile.fromJson({'driverId':'d','rating':4.9,'customerRatingCount':10});
   expect(p.customerRatingCount, 0);
 });
 test('malformed average/count cannot produce a verified rating', () {
   for (final avg in [0,6,double.nan,'5',null]) {
     final p = DriverProfile.fromJson({'driverId':'d','rating':4.9,'customerRating':avg is num ? avg : null,'customerRatingCount':2});
     expect(p.customerRatingCount, 0);
   }
 });
}
