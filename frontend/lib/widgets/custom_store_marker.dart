import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Custom circular marker widget for stores on map
/// Features:
/// - Yellow circular background (AppColors.primary)
/// - Blue icon inside based on store type (AppColors.secondary)
/// - Red/Orange glow based on hotScore
/// - "Core" badge for core regions
class CustomStoreMarker extends StatelessWidget {
  final String storeType; // 'restaurant', 'store', 'cafe'
  final int hotScore; // 0-20+
  final bool isCoreRegion;
  final double size; // Default 60

  const CustomStoreMarker({
    super.key,
    required this.storeType,
    required this.hotScore,
    this.isCoreRegion = false,
    this.size = 60,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Glow effect (if hot)
        if (hotScore > 0) _buildGlow(),
        
        // Main circular icon
        _buildMainCircle(),
        
        // Core region badge
        if (isCoreRegion) _buildCoreBadge(),
      ],
    );
  }

  /// Build glow effect based on hotScore
  Widget _buildGlow() {
    Color glowColor;
    double glowSize;
    
    if (hotScore >= 10) {
      // Very hot - Strong red glow
      glowColor = const Color(0xFFFF0000).withOpacity(0.4);
      glowSize = size * 1.6;
    } else if (hotScore >= 5) {
      // Hot - Light red glow
      glowColor = const Color(0xFFFF6666).withOpacity(0.3);
      glowSize = size * 1.4;
    } else {
      // Warm - Orange glow
      glowColor = const Color(0xFFFFA500).withOpacity(0.25);
      glowSize = size * 1.3;
    }
    
    return Container(
      width: glowSize,
      height: glowSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: glowColor,
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
    );
  }

  /// Build main circular icon with store type icon
  Widget _buildMainCircle() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFFDC500), // AppColors.primary (Yellow)
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          _getIconForStoreType(),
          size: size * 0.5,
          color: const Color(0xFF00296B), // AppColors.secondary (Blue)
        ),
      ),
    );
  }

  /// Get icon based on store type
  IconData _getIconForStoreType() {
    switch (storeType.toLowerCase()) {
      case 'restaurant':
        return Icons.restaurant; // 🍴 Fork and knife
      case 'store':
      case 'grocery':
      case 'supermarket':
        return Icons.shopping_cart; // 🛒 Shopping cart
      case 'cafe':
      case 'coffee':
        return Icons.local_cafe; // ☕ Coffee cup
      case 'bakery':
        return Icons.bakery_dining; // 🥖 Bakery
      case 'fastfood':
        return Icons.fastfood; // 🍔 Fast food
      default:
        return Icons.store; // 🏪 Generic store
    }
  }

  /// Build "Core" badge for core regions
  Widget _buildCoreBadge() {
    return Positioned(
      bottom: -4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.amber[700],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star,
              size: 12,
              color: Colors.white,
            ),
            SizedBox(width: 2),
            Text(
              'Core',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper class to convert CustomStoreMarker widget to BitmapDescriptor
/// for use with Google Maps
class MarkerIconGenerator {
  static Future<BitmapDescriptor> createCustomMarker({
    required String storeType,
    required int hotScore,
    bool isCoreRegion = false,
    double size = 60,
  }) async {
    // This would use a proper widget-to-image conversion
    // For now, return default marker (we'll implement proper conversion next)
    return BitmapDescriptor.defaultMarkerWithHue(
      BitmapDescriptor.hueYellow,
    );
    
    // TODO: Implement widget-to-image conversion using:
    // 1. RepaintBoundary + RenderRepaintBoundary
    // 2. toImage() + toByteData()
    // 3. BitmapDescriptor.fromBytes()
  }
}
