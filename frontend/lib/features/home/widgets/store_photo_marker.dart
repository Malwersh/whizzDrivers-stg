import 'store_marker_halo.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Bounded bitmap cache. Photos never block the first map render; failed images
/// fall back to category icons and are retried after a short cooldown.
class StorePhotoMarkers {
  final _ready = <String, BitmapDescriptor>{};
  final _pending = <String, Future<BitmapDescriptor?>>{};
  final _retryAfter = <String, DateTime>{};
  String _key(String url, double size, int level) => '$size|$level|$url';
  BitmapDescriptor? cached(String? url, double size, {int activityLevel = 0}) =>
      url == null ? null : _ready[_key(url.trim(), size, activityLevel)];

  Future<BitmapDescriptor?> load(String? url, double size,
      {int activityLevel = 0}) {
    final value = url?.trim() ?? '', uri = Uri.tryParse(url?.trim() ?? '');
    if (value.isEmpty ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty) {
      return Future.value(null);
    }
    final key = _key(value, size, activityLevel), cached = _ready[key];
    if (cached != null) return Future.value(cached);
    if (_retryAfter[key]?.isAfter(DateTime.now()) == true)
      return Future.value(null);
    return _pending.putIfAbsent(key, () async {
      try {
        final result = await _draw(value, size, activityLevel);
        if (_ready.length >= 100) _ready.remove(_ready.keys.first);
        _ready[key] = result;
        _retryAfter.remove(key);
        return result;
      } catch (_) {
        if (_retryAfter.length >= 100)
          _retryAfter.remove(_retryAfter.keys.first);
        _retryAfter[key] = DateTime.now().add(const Duration(minutes: 2));
        return null;
      } finally {
        _pending.remove(key);
      }
    });
  }

  Future<BitmapDescriptor> _draw(
      String url, double size, int activityLevel) async {
    final stream = ResizeImage(NetworkImage(url),
            width: 192, height: 192, policy: ResizeImagePolicy.fit)
        .resolve(ImageConfiguration.empty);
    final completed = Completer<ImageInfo>();
    final listener = ImageStreamListener((info, _) {
      if (completed.isCompleted) {
        info.dispose();
      } else {
        completed.complete(info);
      }
    }, onError: (Object error, StackTrace? stack) {
      if (!completed.isCompleted) completed.completeError(error, stack);
    });
    ImageInfo? info;
    ui.Image? raster;
    ui.Picture? picture;
    stream.addListener(listener);
    try {
      info = await completed.future.timeout(const Duration(seconds: 6));
      final recorder = ui.PictureRecorder();
      // Draw at 3x resolution while keeping the map marker's logical size stable.
      final drawing = Canvas(recorder)..scale(3);
      final padding = activityLevel > 0 ? 12.0 : 0.0;
      final side = size + padding * 2;
      final rect = Rect.fromLTWH(padding + 2, padding + 2, size - 4, size - 4);
      paintStoreMarkerHalo(drawing, rect.center, rect.width / 2, activityLevel);
      final path = Path()..addOval(rect);
      drawing.drawShadow(path, const Color(0x55000000), 2, false);
      drawing.save();
      drawing.clipPath(path);
      paintImage(
          canvas: drawing,
          rect: rect,
          image: info.image,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high);
      drawing.restore();
      drawing.drawOval(
          rect,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
      picture = recorder.endRecording();
      raster = await picture.toImage((side * 3).round(), (side * 3).round());
      final bytes = await raster.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('Photo unavailable');
      return BitmapDescriptor.bytes(bytes.buffer.asUint8List(),
          imagePixelRatio: 3, width: side, height: side);
    } finally {
      stream.removeListener(listener);
      info?.dispose();
      raster?.dispose();
      picture?.dispose();
    }
  }
}
