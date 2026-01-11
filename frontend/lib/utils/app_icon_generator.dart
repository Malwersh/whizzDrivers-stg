import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import '../widgets/wizz_logo.dart';

/// Utility class for generating app icons from the WizzLogo
class AppIconGenerator {
  /// Generate different sized app icons
  static Future<Uint8List> generateIcon({
    double size = 1024,
    bool includeText = true,
  }) async {
    final recorder = ui.PictureRecorder();

    // Create the logo widget
    final logo = RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: WizzLogo(size: size, showText: includeText),
      ),
    );

    // Convert widget to image
    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  /// Standard iOS app icon sizes
  static const List<int> iosIconSizes = [
    20, // iPhone Settings 2x
    29, // iPhone Settings 3x
    40, // iPhone Spotlight 2x
    58, // iPhone Settings 3x
    60, // iPhone Spotlight 3x
    80, // iPhone Spotlight 2x
    87, // iPhone Settings 3x
    120, // iPhone App 2x
    180, // iPhone App 3x
    1024, // App Store
  ];

  /// Standard Android app icon sizes
  static const List<int> androidIconSizes = [
    36, // ldpi
    48, // mdpi
    72, // hdpi
    96, // xhdpi
    144, // xxhdpi
    192, // xxxhdpi
    512, // Play Store
  ];
}

/// Widget for previewing different app icon sizes
class AppIconPreview extends StatefulWidget {
  const AppIconPreview({super.key});

  @override
  State<AppIconPreview> createState() => _AppIconPreviewState();
}

class _AppIconPreviewState extends State<AppIconPreview> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Icon Preview'),
        backgroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'iOS App Icons',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildIconGrid(AppIconGenerator.iosIconSizes),
            const SizedBox(height: 32),
            const Text(
              'Android App Icons',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildIconGrid(AppIconGenerator.androidIconSizes),
            const SizedBox(height: 32),
            const Text(
              'Logo Variations',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildLogoVariations(),
          ],
        ),
      ),
    );
  }

  Widget _buildIconGrid(List<int> sizes) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: sizes.map((size) => _buildIconPreview(size)).toList(),
    );
  }

  Widget _buildIconPreview(int size) {
    final displaySize = (size / 4).clamp(40.0, 120.0);
    return Column(
      children: [
        Container(
          width: displaySize,
          height: displaySize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(displaySize * 0.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(displaySize * 0.2),
            child: WizzLogo(size: displaySize, showText: size >= 60),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${size}px',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildLogoVariations() {
    return const Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Column(
              children: [
                WizzLogo(size: 80, showText: true),
                SizedBox(height: 8),
                Text('With Text', style: TextStyle(fontSize: 12)),
              ],
            ),
            Column(
              children: [
                WizzLogo(size: 80, showText: false),
                SizedBox(height: 8),
                Text('Icon Only', style: TextStyle(fontSize: 12)),
              ],
            ),
            Column(
              children: [
                WizzLogoCompact(size: 80, animated: false),
                SizedBox(height: 8),
                Text('Compact', style: TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
        SizedBox(height: 24),
        Text(
          'The WizzLogo uses a SweepGradient with brand colors:\n'
          '• Viridian Green (#1299A1)\n'
          '• Portland Orange (#FD5933)\n'
          '• Royal Orange (#EF9A4E)\n'
          '• Bone (#E6D8CF)\n'
          '• Raspberry Pink (#E84F99)\n'
          '• Royal Purple (#7E4E9E)',
          style: TextStyle(fontSize: 14, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
