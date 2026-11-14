import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wizz_driver/design_system/app_theme.dart';
import 'package:wizz_driver/features/more/screens/driver_performance_screen.dart';

void main() {
  testWidgets('portrait summary separates metric values from explanations',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final loader = FontLoader('PerformancePreviewArabic')
      ..addFont(rootBundle.load('assets/fonts/NotoSansArabic.ttf'));
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final theme = AppTheme.lightTheme;
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme.copyWith(
                textTheme: theme.textTheme
                    .apply(fontFamily: 'PerformancePreviewArabic')),
            home: DriverPerformanceScreen(
                load: () async => {
                      'updatedAt': '2026-10-24T20:00:00Z',
                      'acceptanceRate': 1.0,
                      'acceptanceRateStatus': 'PROVISIONAL',
                      'acceptance': {
                        'accepted': 21,
                        'declined': 0,
                        'expiredDelivered': 0,
                        'sampleSize': 21,
                        'unconfirmedExcluded': 5,
                        'withdrawnExcluded': 0
                      },
                      'completionRate': 1.0,
                      'completionRateStatus': 'PROVISIONAL',
                      'completion': {
                        'completed': 17,
                        'returned': 1,
                        'driverFailures': 0,
                        'sampleSize': 18,
                        'inProgress': 0,
                        'reviewExcluded': 3,
                        'noFaultExcluded': 0
                      },
                      'onTimeRateStatus': 'INSUFFICIENT_DATA',
                      'activity': {
                        'accepted': 21,
                        'coverageComplete': true,
                        'legacyExcluded': 0
                      },
                      'customerRatingCount': 0,
                    }))));
    await tester.pumpAndSettle();
    expect(find.text('100.0٪'), findsNWidgets(2));
    expect(find.text('مبدئي'), findsNWidgets(2));
    expect(find.textContaining('قبلت 21'), findsNothing);
    expect(find.textContaining('تم تسليم 17'), findsNothing);
    expect(tester.takeException(), isNull);
    final output = Platform.environment['PERFORMANCE_SCREENSHOT'];
    if (output != null) {
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File(output).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
