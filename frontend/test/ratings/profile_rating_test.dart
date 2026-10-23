import 'package:flutter_test/flutter_test.dart';
import 'package:wizz_driver/models/driver_profile.dart';
void main(){
 test('verified customer rating wins over legacy profile rating and survives cache/copy',(){
  final p=DriverProfile.fromJson({'driverId':'d','name':'سائق','rating':4.9,'customerRating':3.5,'customerRatingCount':2});
  expect(p.rating,3.5);expect(p.customerRatingCount,2);
  expect(DriverProfile.fromJson(p.toJson()).rating,3.5);
  expect(p.copyWith(name:'updated').customerRatingCount,2);
 });
}
