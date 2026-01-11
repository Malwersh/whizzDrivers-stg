import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../design_system/colors.dart';
import '../widgets/wizz_logo.dart';

class WizzLogoShowcase extends StatelessWidget {
  const WizzLogoShowcase({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HadhirColors.background,
      appBar: AppBar(
        title: const Text('WIZZ Logo Showcase'),
        backgroundColor: HadhirColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('🎨 Official WIZZ Logo (SVG)'),
            const SizedBox(height: 16),
            _buildLogoGrid([
              _buildLogoCard(
                'SVG - Large',
                const WizzLogo(size: 120, useSvgAsset: true),
              ),
              _buildLogoCard(
                'SVG - Medium',
                const WizzLogo(size: 80, useSvgAsset: true),
              ),
              _buildLogoCard(
                'SVG - Small',
                const WizzLogo(size: 60, useSvgAsset: true),
              ),
              _buildLogoCard(
                'SVG - Tiny',
                const WizzLogo(size: 40, useSvgAsset: true),
              ),
            ]),

            const SizedBox(height: 32),
            _buildSectionTitle('🌈 Gradient WIZZ Logo (Programmatic)'),
            const SizedBox(height: 16),
            _buildLogoGrid([
              _buildLogoCard(
                'Gradient - Large',
                const WizzLogo(size: 120, showText: true),
              ),
              _buildLogoCard(
                'Gradient - Medium',
                const WizzLogo(size: 80, showText: true),
              ),
              _buildLogoCard(
                'Gradient - Small',
                const WizzLogo(size: 60, showText: true),
              ),
              _buildLogoCard(
                'Gradient - Compact',
                const WizzLogoCompact(size: 40),
              ),
            ]),

            const SizedBox(height: 32),
            _buildSectionTitle('📱 App Icon Versions'),
            const SizedBox(height: 16),
            _buildAppIconGrid(),

            const SizedBox(height: 32),
            _buildSectionTitle('🎯 Usage Examples'),
            const SizedBox(height: 16),
            _buildUsageExamples(),

            const SizedBox(height: 32),
            _buildSectionTitle('🔧 Implementation Guide'),
            const SizedBox(height: 16),
            _buildImplementationGuide(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildLogoGrid(List<Widget> cards) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: cards,
    );
  }

  Widget _buildLogoCard(String title, Widget logo) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          logo,
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black54,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAppIconGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        _buildAppIconPreview('1024x1024', 80),
        _buildAppIconPreview('180x180', 60),
        _buildAppIconPreview('120x120', 50),
        _buildAppIconPreview('76x76', 40),
        _buildAppIconPreview('60x60', 35),
        _buildAppIconPreview('40x40', 30),
        _buildAppIconPreview('29x29', 25),
        _buildAppIconPreview('20x20', 20),
      ],
    );
  }

  Widget _buildAppIconPreview(String size, double displaySize) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            'assets/images/wizz_logo.svg',
            width: displaySize,
            height: displaySize,
          ),
          const SizedBox(height: 4),
          Text(
            size,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageExamples() {
    return Column(
      children: [
        _buildUsageExample(
          'App Bar Logo',
          'Use WizzLogoCompact in app bars',
          AppBar(
            backgroundColor: HadhirColors.primary,
            leading: const WizzLogoCompact(size: 32),
            title: const Text('WIZZ Driver'),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () {},
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildUsageExample(
          'Splash Screen',
          'Use full WIZZ logo with SVG for best quality',
          Container(
            height: 200,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [HadhirColors.background, Colors.white],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  WizzLogo(size: 100, useSvgAsset: true),
                  SizedBox(height: 16),
                  Text(
                    'WIZZ Driver',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUsageExample(String title, String description, Widget example) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          ClipRRect(borderRadius: BorderRadius.circular(8), child: example),
        ],
      ),
    );
  }

  Widget _buildImplementationGuide() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.code, color: Colors.blue.shade600),
              const SizedBox(width: 8),
              Text(
                'Implementation Guide',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '• Use WizzLogo(useSvgAsset: true) for high-quality SVG rendering\n'
            '• Use WizzLogo() for programmatic gradient version\n'
            '• Use WizzLogoCompact() for app bars and small spaces\n'
            '• App icons are automatically generated in all required sizes\n'
            '• SVG assets are located in assets/images/wizz_logo.svg',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}
