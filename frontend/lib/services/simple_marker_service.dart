import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Simple service to create colored markers with emojis for store types
class SimpleMarkerService {
  /// Create a simple colored marker with emoji based on store properties
  static Future<BitmapDescriptor> createMarker({
    required String storeType,
    required int hotScore,
    required bool isCoreRegion,
    required bool isOpen,
  }) async {
    // Choose emoji based on store type
    String emoji = _getStoreEmoji(storeType);
    
    // Choose color based on hot score and status
    Color markerColor = _getMarkerColor(hotScore, isOpen, isCoreRegion);
    
    // Create a simple text-based marker
    return _createTextMarker(emoji, markerColor, hotScore);
  }
  
  /// Get emoji for store type
  static String _getStoreEmoji(String storeType) {
    switch (storeType.toLowerCase()) {
      case 'restaurant':
        return '🍽️';
      case 'cafe':
        return '☕';
      case 'store':
      case 'market':
        return '🏪';
      case 'grocery':
        return '🛒';
      default:
        return '🏪';
    }
  }
  
  /// Get color based on hot score and status
  static Color _getMarkerColor(int hotScore, bool isOpen, bool isCoreRegion) {
    if (!isOpen) {
      return Colors.grey[600]!; // Closed stores
    }
    
    if (hotScore >= 10) {
      return Colors.red[700]!; // Very hot
    } else if (hotScore >= 5) {
      return Colors.orange[600]!; // Hot
    } else if (hotScore > 0) {
      return Colors.yellow[700]!; // Warm
    } else if (isCoreRegion) {
      return Colors.green[600]!; // Core region
    } else {
      return Colors.blue[600]!; // Extended region
    }
  }
  
  /// Create a text-based marker with background circle
  static Future<BitmapDescriptor> _createTextMarker(
    String emoji, 
    Color backgroundColor, 
    int hotScore
  ) async {
    const double size = 80.0;
    
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    // Draw background circle
    final paint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(
      const Offset(size / 2, size / 2), 
      size / 2 - 4, 
      paint,
    );
    
    // Draw white border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    
    canvas.drawCircle(
      const Offset(size / 2, size / 2), 
      size / 2 - 4, 
      borderPaint,
    );
    
    // Draw hot score glow if hot
    if (hotScore > 0) {
      final glowPaint = Paint()
        ..color = Colors.red.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(
        const Offset(size / 2, size / 2), 
        size / 2 + 8, 
        glowPaint,
      );
    }
    
    // Draw emoji
    final textPainter = TextPainter(
      text: TextSpan(
        text: emoji,
        style: const TextStyle(
          fontSize: 32,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    textPainter.paint(
      canvas, 
      Offset(
        (size - textPainter.width) / 2,
        (size - textPainter.height) / 2,
      ),
    );
    
    // Draw hot score number if hot
    if (hotScore > 0) {
      final scorePainter = TextPainter(
        text: TextSpan(
          text: hotScore.toString(),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.8),
                offset: const Offset(1, 1),
                blurRadius: 2,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      
      scorePainter.layout();
      scorePainter.paint(
        canvas,
        Offset(
          size - scorePainter.width - 8,
          8,
        ),
      );
    }
    
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }
  
  /// Cache for markers to avoid recreating same ones
  static final Map<String, BitmapDescriptor> _cache = {};
  
  /// Get marker from cache or create new one
  static Future<BitmapDescriptor> getMarker({
    required String storeType,
    required int hotScore,
    required bool isCoreRegion,
    required bool isOpen,
  }) async {
    final key = '${storeType}_${hotScore}_${isCoreRegion}_$isOpen';
    
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }
    
    final marker = await createMarker(
      storeType: storeType,
      hotScore: hotScore,
      isCoreRegion: isCoreRegion,
      isOpen: isOpen,
    );
    
    _cache[key] = marker;
    return marker;
  }
  
  /// Clear cache if needed
  static void clearCache() {
    _cache.clear();
  }
}