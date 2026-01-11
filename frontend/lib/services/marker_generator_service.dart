import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../widgets/custom_store_marker.dart';

/// Service to convert Flutter widgets to BitmapDescriptor for Google Maps
class MarkerGeneratorService {
  /// Generate a BitmapDescriptor from CustomStoreMarker widget
  /// 
  /// This converts the custom Flutter widget to a PNG image that can be used
  /// as a marker icon on Google Maps
  static Future<BitmapDescriptor> createCustomMarker({
    required String storeType,
    required int hotScore,
    required bool isCoreRegion,
    double size = 120, // Higher resolution for better quality
  }) async {
    // Create the widget
    final widget = CustomStoreMarker(
      storeType: storeType,
      hotScore: hotScore,
      isCoreRegion: isCoreRegion,
      size: size,
    );

    // Convert to image
    final ui.Image image = await _widgetToImage(widget, size: size);
    
    // Convert to bytes
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    // Create BitmapDescriptor
    return BitmapDescriptor.fromBytes(bytes);
  }

  /// Convert a Flutter widget to ui.Image
  static Future<ui.Image> _widgetToImage(Widget widget, {required double size}) async {
    final RenderRepaintBoundary repaintBoundary = RenderRepaintBoundary();
    
    final RenderView renderView = RenderView(
      view: ui.PlatformDispatcher.instance.views.first,
      child: RenderPositionedBox(
        alignment: Alignment.center,
        child: repaintBoundary,
      ),
      configuration: ViewConfiguration(
        logicalConstraints: BoxConstraints.tight(Size(size, size)),
        devicePixelRatio: 3.0, // High DPI for crisp markers
      ),
    );

    final PipelineOwner pipelineOwner = PipelineOwner();
    final BuildOwner buildOwner = BuildOwner(focusManager: FocusManager());

    pipelineOwner.rootNode = renderView;
    renderView.prepareInitialFrame();

    final RenderObjectToWidgetElement<RenderBox> rootElement = 
        RenderObjectToWidgetAdapter<RenderBox>(
      container: repaintBoundary,
      child: Directionality(
        textDirection: TextDirection.rtl, // Arabic support
        child: Material(
          color: Colors.transparent,
          child: widget,
        ),
      ),
    ).attachToRenderTree(buildOwner);

    buildOwner.buildScope(rootElement);
    buildOwner.finalizeTree();

    pipelineOwner.flushLayout();
    pipelineOwner.flushCompositingBits();
    pipelineOwner.flushPaint();

    final ui.Image image = await repaintBoundary.toImage(pixelRatio: 3.0);
    
    return image;
  }

  /// Create cached markers for all store types and hot scores
  /// This improves performance by pre-generating common marker variations
  static Future<Map<String, BitmapDescriptor>> generateMarkerCache() async {
    final Map<String, BitmapDescriptor> cache = {};
    
    // Store types
    final storeTypes = ['restaurant', 'store', 'cafe', 'default'];
    
    // Hot score ranges: 0 (no glow), 3 (orange), 7 (light red), 12 (strong red)
    final hotScores = [0, 3, 7, 12];
    
    // Core region variants
    final coreVariants = [true, false];

    print('🎨 Generating marker cache...');
    
    for (final type in storeTypes) {
      for (final score in hotScores) {
        for (final isCore in coreVariants) {
          final key = _getCacheKey(type, score, isCore);
          cache[key] = await createCustomMarker(
            storeType: type,
            hotScore: score,
            isCoreRegion: isCore,
          );
        }
      }
    }

    print('✅ Generated ${cache.length} marker variations');
    return cache;
  }

  /// Get cache key for a marker configuration
  static String _getCacheKey(String storeType, int hotScore, bool isCore) {
    // Round hot score to nearest cache level
    int scoreLevel;
    if (hotScore == 0) {
      scoreLevel = 0;
    } else if (hotScore < 5) {
      scoreLevel = 3;
    } else if (hotScore < 10) {
      scoreLevel = 7;
    } else {
      scoreLevel = 12;
    }
    
    return '${storeType}_${scoreLevel}_${isCore ? 'core' : 'extended'}';
  }

  /// Get marker from cache or generate new one
  static Future<BitmapDescriptor> getMarker({
    required String storeType,
    required int hotScore,
    required bool isCoreRegion,
    Map<String, BitmapDescriptor>? cache,
  }) async {
    if (cache != null) {
      final key = _getCacheKey(storeType, hotScore, isCoreRegion);
      if (cache.containsKey(key)) {
        return cache[key]!;
      }
    }

    // Fallback: generate on-demand
    return createCustomMarker(
      storeType: storeType,
      hotScore: hotScore,
      isCoreRegion: isCoreRegion,
    );
  }
}
