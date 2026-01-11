import 'package:flutter/material.dart';
import '../widgets/wizz_logo.dart';
import '../widgets/gradient_border_container.dart';
import '../design_system/colors.dart';

/// Demo screen to showcase the WizzLogo implementation
class WizzLogoDemo extends StatefulWidget {
  const WizzLogoDemo({super.key});

  @override
  State<WizzLogoDemo> createState() => _WizzLogoDemoState();
}

class _WizzLogoDemoState extends State<WizzLogoDemo>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HadhirColors.background,
      appBar: AppBar(
        title: const Text('WIZZ Logo Demo'),
        backgroundColor: HadhirColors.primary,
        leading: const Padding(
          padding: EdgeInsets.all(8.0),
          child: WizzLogoCompact(size: 32),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Hero Logo
            const Center(child: WizzLogo(size: 200)),
            const SizedBox(height: 32),

            // Logo Variations Section
            GradientBorderContainer(
              borderWidth: 2,
              borderRadius: 16,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Logo Variations',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Different sizes
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildLogoCard('Large', const WizzLogo(size: 80)),
                        _buildLogoCard('Medium', const WizzLogo(size: 60)),
                        _buildLogoCard('Small', const WizzLogo(size: 40)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Compact versions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildLogoCard(
                          'Compact\nLarge',
                          const WizzLogoCompact(size: 60),
                        ),
                        _buildLogoCard(
                          'Compact\nMedium',
                          const WizzLogoCompact(size: 40),
                        ),
                        _buildLogoCard(
                          'Compact\nSmall',
                          const WizzLogoCompact(size: 24),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // App Icon Sizes Section
            GradientBorderContainer(
              borderWidth: 2,
              borderRadius: 16,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'App Icon Sizes',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // iOS sizes simulation
                    const Text(
                      'iOS App Icons:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildAppIcon(20, '20pt'),
                        _buildAppIcon(29, '29pt'),
                        _buildAppIcon(40, '40pt'),
                        _buildAppIcon(60, '60pt'),
                        _buildAppIcon(76, '76pt'),
                        _buildAppIcon(83.5, '83.5pt'),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Android sizes simulation
                    const Text(
                      'Android App Icons:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildAppIcon(36, 'ldpi'),
                        _buildAppIcon(48, 'mdpi'),
                        _buildAppIcon(72, 'hdpi'),
                        _buildAppIcon(96, 'xhdpi'),
                        _buildAppIcon(144, 'xxhdpi'),
                        _buildAppIcon(192, 'xxxhdpi'),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Animation Demo Section
            GradientBorderContainer(
              borderWidth: 2,
              borderRadius: 16,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Animated Logo',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),
                    AnimatedBuilder(
                      animation: _rotationController,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _rotationController.value * 2 * 3.14159,
                          child: const WizzLogo(size: 100),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Perfect for splash screens!',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Brand Colors Section
            GradientBorderContainer(
              borderWidth: 2,
              borderRadius: 16,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Brand Colors',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildColorSwatch(
                      'Viridian Green',
                      const Color(0xFF1299A1),
                    ),
                    _buildColorSwatch(
                      'Portland Orange',
                      const Color(0xFFFD5933),
                    ),
                    _buildColorSwatch('Royal Orange', const Color(0xFFEF9A4E)),
                    _buildColorSwatch('Bone', const Color(0xFFE6D8CF)),
                    _buildColorSwatch(
                      'Raspberry Pink',
                      const Color(0xFFE84F99),
                    ),
                    _buildColorSwatch('Royal Purple', const Color(0xFF7E4E9E)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoCard(String title, Widget logo) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: logo,
        ),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildAppIcon(double size, String label) {
    return Column(
      children: [
        Container(
          width: size.clamp(24, 80),
          height: size.clamp(24, 80),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.15),
            child: WizzLogo(size: size.clamp(24, 80), showText: size >= 40),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildColorSwatch(String name, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey[300]!),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            name,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          Text(
            '#${color.value.toRadixString(16).substring(2).toUpperCase()}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
