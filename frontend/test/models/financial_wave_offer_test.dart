import 'package:flutter_test/flutter_test.dart';
import 'package:wizz_driver/models/wave_offer.dart';

Map<String, dynamic> money(int minor) => {
      'moneySchemaVersion': 1,
      'currency': 'IQD',
      'scale': 1000,
      'minorAmount': minor
    };
Map<String, dynamic> offer() => {
      'schemaVersion': 1,
      'kind': 'DRIVER_OFFER_PROPOSAL',
      'offerId': 'FINO:abc',
      'offerDigest': 'a' * 64,
      'orderId': 'order_with_underscores',
      'branchId': 'branch1',
      'waveNumber': 2,
      'paymentMethod': 'COD',
      'pickupLocation': {'latitude': 31.9, 'longitude': 44.4},
      'deliveryZoneId': 'zone1',
      'createdAt': '2026-10-16T12:00:00.000Z',
      'expiresAt': '2026-10-16T12:01:00.000Z',
      'totalDistanceMeters': 4000,
      'totalDurationSeconds': 600,
      'customerCashToCollect': money(14500125),
      'driverEarning': money(3000125),
      'driverTip': money(1000000),
      'driverTotalEntitlement': money(4000125),
      'driverWalletHold': money(10500000),
      'driverCashRetained': money(4000125),
      'laterWalletEarningCredit': money(0),
      'laterWalletTipCredit': money(0),
    };
void main() {
  test(
      'financial Money bypasses legacy magnitude normalization and preserves the contract',
      () {
    final raw = offer(), model = WaveOffer.fromJson(raw);
    expect(model.orderTotal, 14500.125);
    expect(model.deliveryFee, 3000.125);
    expect(model.estimatedEarnings, 4000.125);
    expect(model.holdRequiredAmount, 10500);
    expect(model.waveNumber, 2);
    expect(model.orderId, 'order_with_underscores');
    expect(model.toJson(), raw);
    expect(model.financialTerms, isNotNull);
    expect(model.customerAddress, isEmpty);
  });
  test(
      'canonical display carries two pieces, exact IQD unit price, image and restaurant without changing financial amounts',
      () {
    final raw = offer();
    raw['display'] = {
      'schemaVersion': 1,
      'restaurant': {
        'name': 'مطعم فتوش',
        'address': 'المناذرة',
        'imageUrl': null
      },
      'customer': {'name': 'Mohammed Ali', 'address': 'عنوان التوصيل'},
      'lineCount': 1,
      'totalQuantity': 2,
      'items': [
        {
          'itemId': 'item1',
          'name': 'كباب',
          'quantity': 2,
          'unitPrice': money(3500000),
          'imageUrl': 'https://example.com/item.png',
          'notes': 'بدون بصل',
          'modifiers': ['كبير']
        }
      ]
    };
    final model = WaveOffer.fromJson(raw);
    expect(model.itemsCount, 2);
    expect(model.items.single.price, 3500);
    expect(model.customerName, 'Mohammed Ali');
    expect(model.customerAddress, 'عنوان التوصيل');
    expect(model.restaurantName, 'مطعم فتوش');
    expect(model.items.single.imageUrl, 'https://example.com/item.png');
    expect(model.items.single.notes, 'بدون بصل • كبير');
    expect(model.holdRequiredAmount, 10500);
    expect(model.toJson(), raw);
    raw['display']['totalQuantity'] = 1;
    expect(() => WaveOffer.fromJson(raw), throwsFormatException);
  });
  test('duration follows issued deadline and expired offers stay at zero', () {
    final raw = offer();
    final model = WaveOffer.fromJson(raw);
    expect(model.durationSeconds, 60);
    expect(model.remainingSeconds, 0);
  });
  test(
      'invalid scale, schema, prepaid and inconsistent entitlement are rejected',
      () {
    for (final mutation in <void Function(Map<String, dynamic>)>[
      (v) => v['driverWalletHold']['scale'] = 1,
      (v) => v['driverEarning']['minorAmount'] = -1,
      (v) => v['schemaVersion'] = 2,
      (v) => v['paymentMethod'] = 'PREPAID',
      (v) => v['driverTotalEntitlement'] = money(1),
    ]) {
      final value = offer();
      mutation(value);
      expect(() => WaveOffer.fromJson(value), throwsFormatException);
    }
  });
  test(
      'delivery-funded offer retains canonical driver amounts and outer acceptance digest',
      () {
    final raw = offer()
      ..['schemaVersion'] = 2
      ..['kind'] = 'DRIVER_DELIVERY_FUNDED_OFFER';
    final model = WaveOffer.fromJson(raw);
    expect(model.orderTotal, 14500.125);
    expect(model.holdRequiredAmount, 10500);
    expect(model.financialTerms, isNotNull);
    expect(model.toJson(), raw);
    raw['schemaVersion'] = 1;
    expect(() => WaveOffer.fromJson(raw), throwsFormatException);
  });
  test(
      'full cash offer validates collateral and cash entitlement before display',
      () {
    final raw = offer()
      ..['schemaVersion'] = 3
      ..['kind'] = 'DRIVER_FULL_CASH_OFFER'
      ..['settlementModel'] = 'FULL_CASH_AT_DELIVERY_V1'
      ..['collectionRequired'] = true;
    final model = WaveOffer.fromJson(raw);
    expect(model.orderTotal, 14500.125);
    expect(model.estimatedEarnings, 4000.125);
    expect(model.holdRequiredAmount, 10500);
    expect(model.driverCashRetained, 4000.125);
    expect(model.walletCreditAfterDelivery, 0);
    raw['driverWalletHold'] = money(11500000);
    expect(() => WaveOffer.fromJson(raw), throwsFormatException);
  });
}
