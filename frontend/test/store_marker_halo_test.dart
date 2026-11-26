import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wizz_driver/features/home/widgets/store_marker_halo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('activity glow hugs the marker, with no halo for inactive stores',
      () async {
    final recorder = ui.PictureRecorder();
    final draw = Canvas(recorder);
    draw.drawPaint(Paint()..color = const Color(0xFFF1F3F5));
    for (var i = 0; i < 3; i++) {
      final c = Offset(60 + i * 110, 60);
      paintStoreMarkerHalo(draw, c, 22, i);
      draw.drawCircle(c, 22, Paint()..color = Colors.white);
      draw.drawCircle(c, 17, Paint()..color = const Color(0xFF375C85));
    }
    final pic = recorder.endRecording(),
        img = await pic.toImage(340, 120),
        rgba = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    // At 26px from the center the ring is visible; at 45px the map is clear.
    int red(int x) => rgba!.getUint8((60 * 340 + x) * 4);
    int green(int x) => rgba!.getUint8((60 * 340 + x) * 4 + 1);
    expect(red(280 + 26), greaterThan(230));
    expect(green(280 + 26), lessThan(120));
    expect(red(280 + 45), 241);
    expect(green(280 + 45), 243);
    expect(green(170 + 26), greaterThan(130));
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File('/private/tmp/github-sync333/halo-preview.png')
        .writeAsBytesSync(png!.buffer.asUint8List());
    img.dispose();
    pic.dispose();
  });
}
