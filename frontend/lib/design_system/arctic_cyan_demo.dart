// Arctic Cyan Color System Demo
// This file demonstrates the Arctic Cyan color system implementation
import 'package:flutter/material.dart';
import 'package:wizz_driver/design_system/colors.dart';
import 'package:wizz_driver/design_system/design_tokens.dart';
import 'package:wizz_driver/design_system/theme_extensions.dart';

class ArcticCyanDemo extends StatelessWidget {
  const ArcticCyanDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Arctic Cyan Color System'),
        backgroundColor: HadhirColors.moonstoneMist,
        foregroundColor: HadhirColors.obsidianCore,
      ),
      backgroundColor: HadhirColors.moonstoneMist,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(DesignTokens.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Primary Color Section
            const _ColorSection(
              title: 'Primary Colors',
              colors: [
                _ColorItem(
                  name: 'Arctic Cyan',
                  description: 'Hyper-clean and futuristic',
                  color: HadhirColors.arcticCyan,
                  hexCode: '#00E5FF',
                ),
              ],
            ),

            const SizedBox(height: DesignTokens.spacingLarge),

            // Accent Colors Section
            const _ColorSection(
              title: 'Accent Colors',
              colors: [
                _ColorItem(
                  name: 'Ultraviolet Pulse',
                  description: 'Bold and mysterious',
                  color: HadhirColors.ultravioletPulse,
                  hexCode: '#B300FF',
                ),
                _ColorItem(
                  name: 'Acid Kiwi',
                  description: 'Sharp and urgent',
                  color: HadhirColors.acidKiwi,
                  hexCode: '#C6FF00',
                ),
              ],
            ),

            const SizedBox(height: DesignTokens.spacingLarge),

            // Monochrome System
            const _ColorSection(
              title: 'Monochrome Base System',
              colors: [
                _ColorItem(
                  name: 'Pure White',
                  description: 'Primary background & cards',
                  color: Colors.white,
                  hexCode: '#FFFFFF',
                ),
                _ColorItem(
                  name: 'Pure Black',
                  description: 'Text & primary elements',
                  color: Colors.black,
                  hexCode: '#000000',
                ),
              ],
            ),

            const SizedBox(height: DesignTokens.spacingLarge),

            // Branding Accent Colors
            const _ColorSection(
              title: 'Branding Accent Colors (Borders Only)',
              colors: [
                _ColorItem(
                  name: 'Branding Yellow',
                  description: 'For card & profile borders',
                  color: HadhirColors.brandingYellow,
                  hexCode: '#FFFC00',
                ),
                _ColorItem(
                  name: 'Branding Green',
                  description: 'For card & profile borders',
                  color: HadhirColors.brandingGreen,
                  hexCode: '#32C759',
                ),
              ],
            ),

            const SizedBox(height: DesignTokens.spacingLarge),

            // Status Colors Section
            const _ColorSection(
              title: 'Status Colors',
              colors: [
                _ColorItem(
                  name: 'Success',
                  description: 'Using Acid Kiwi for positive actions',
                  color: HadhirColors.success,
                  hexCode: 'Acid Kiwi',
                ),
                _ColorItem(
                  name: 'Warning',
                  description: 'Clean orange for attention',
                  color: HadhirColors.warning,
                  hexCode: '#FF9800',
                ),
                _ColorItem(
                  name: 'Error',
                  description: 'Clear red for errors',
                  color: HadhirColors.error,
                  hexCode: '#FF1744',
                ),
              ],
            ),

            const SizedBox(height: DesignTokens.spacingLarge),

            // Interactive Examples
            Card(
              child: Padding(
                padding: const EdgeInsets.all(DesignTokens.spacingMedium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Monochrome Design Examples',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: HadhirColors.obsidianCore,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: DesignTokens.spacingMedium),

                    // Monochrome Button with Yellow Border
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        side: const BorderSide(
                          color: HadhirColors.brandingYellow,
                          width: 2,
                        ),
                      ),
                      child: const Text('Monochrome with Yellow Border'),
                    ),

                    const SizedBox(height: DesignTokens.spacingSmall),

                    // Secondary Button with Green Border
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        side: const BorderSide(
                          color: HadhirColors.brandingGreen,
                          width: 2,
                        ),
                      ),
                      child: const Text('Monochrome with Green Border'),
                    ),

                    const SizedBox(height: DesignTokens.spacingMedium),

                    // Demo Card with Monochrome Design
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: HadhirColors.brandingYellow,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: HadhirColors.brandingGreen,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.person,
                              color: Colors.black,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Instagram-like Monochrome',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'White/black base with branding accents',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorSection extends StatelessWidget {
  final String title;
  final List<_ColorItem> colors;

  const _ColorSection({required this.title, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: HadhirColors.obsidianCore,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: DesignTokens.spacingMedium),
            ...colors.map(
              (color) => Padding(
                padding: const EdgeInsets.only(
                  bottom: DesignTokens.spacingSmall,
                ),
                child: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorItem extends StatelessWidget {
  final String name;
  final String description;
  final Color color;
  final String hexCode;

  const _ColorItem({
    required this.name,
    required this.description,
    required this.color,
    required this.hexCode,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = ArcticCyanUtils.getTextColorForBackground(color);

    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        border: Border.all(
          color: HadhirColors.outline.withOpacity(0.3),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(DesignTokens.spacingMedium),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: textColor.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spacingSmall,
              vertical: DesignTokens.spacingXSmall,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
            ),
            child: Text(
              hexCode,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: textColor,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Extension method for the color system utilities
extension ColorSystemUtils on BuildContext {
  /// Get Arctic Cyan themed colors from context
  ArcticCyanColors get arcticColors =>
      Theme.of(this).extension<ArcticCyanColors>() ??
      (Theme.of(this).brightness == Brightness.light
          ? ArcticCyanColors.light
          : ArcticCyanColors.dark);
}
