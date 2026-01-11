import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../design_system/app_colors.dart';
import '../models/order_marker.dart';

class MapFallbackWidget extends StatelessWidget {
  final bool isOnline;
  final LatLng initialLocation;
  final LatLng? driverLocation;
  final List<Map<String, dynamic>> hotspots;
  final OrderMarker? activeNavigationOrder;
  final bool isNavigating;
  final VoidCallback? onLocationPressed;
  final VoidCallback? onDashPressed;

  const MapFallbackWidget({
    super.key,
    required this.isOnline,
    required this.initialLocation,
    this.driverLocation,
    this.hotspots = const [],
    this.activeNavigationOrder,
    this.isNavigating = false,
    this.onLocationPressed,
    this.onDashPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          // Fallback map representation
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Map View',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Mapbox not available on this platform\n(Development Mode)',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
                if (driverLocation != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Current Location',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Lat: ${driverLocation!.latitude.toStringAsFixed(6)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          'Lng: ${driverLocation!.longitude.toStringAsFixed(6)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
                if (hotspots.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Hotspots Available',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${hotspots.length} hotspot(s) in area',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
                if (activeNavigationOrder != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Navigation Active',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Order: ${activeNavigationOrder!.id}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Status indicator
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isOnline ? AppColors.primary : Colors.grey,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isOnline ? 'Online' : 'Offline',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // Bottom buttons
          Positioned(
            bottom: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Dash button
                if (onDashPressed != null) ...[
                  FloatingActionButton(
                    mini: true,
                    backgroundColor: AppColors.primary,
                    heroTag: "dash",
                    onPressed: onDashPressed,
                    child: const Icon(Icons.dashboard, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                ],
                // Location button
                if (onLocationPressed != null)
                  FloatingActionButton(
                    mini: true,
                    backgroundColor: Colors.white,
                    heroTag: "location",
                    onPressed: onLocationPressed,
                    child: const Icon(Icons.my_location),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
