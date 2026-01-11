import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/app_colors.dart';
import '../../../design_system/colors.dart';
import '../../../design_system/design_tokens.dart';
import '../../../widgets/gradient_border_container.dart';

class AppSettingsScreen extends ConsumerStatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  ConsumerState<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends ConsumerState<AppSettingsScreen> {
  bool _pushNotifications = true;
  bool _orderNotifications = true;
  bool _promotionNotifications = false;
  bool _locationServices = true;
  bool _backgroundLocation = true;
  String _selectedTheme = 'System';

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final languageOptions = [
      'العربية',
      'English',
      'کوردی', // Kurdish option
    ];
    
    String currentLanguageLabel = 'العربية'; // Default to Arabic
    return Scaffold(
      backgroundColor: HadhirColors.moonstoneMist,
      appBar: AppBar(
        backgroundColor: HadhirColors.primary,
        elevation: 0,
        shadowColor: HadhirColors.primary.withOpacity(0.3),
        surfaceTintColor: HadhirColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'إعدادات التطبيق',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Notifications Section
            _buildSection(
              title: 'Notifications',
              children: [
                _buildSwitchTile(
                  title: 'Push Notifications',
                  subtitle: 'Receive push notifications from the app',
                  value: _pushNotifications,
                  onChanged: (value) {
                    setState(() {
                      _pushNotifications = value;
                    });
                  },
                ),
                _buildSwitchTile(
                  title: 'Order Notifications',
                  subtitle: 'Get notified about new delivery orders',
                  value: _orderNotifications,
                  onChanged: (value) {
                    setState(() {
                      _orderNotifications = value;
                    });
                  },
                ),
                _buildSwitchTile(
                  title: 'Promotion Notifications',
                  subtitle:
                      'Receive notifications about promotions and bonuses',
                  value: _promotionNotifications,
                  onChanged: (value) {
                    setState(() {
                      _promotionNotifications = value;
                    });
                  },
                ),
              ],
            ),

            // Location Section
            _buildSection(
              title: 'Location Services',
              children: [
                _buildSwitchTile(
                  title: 'Location Services',
                  subtitle: 'Allow app to access your location',
                  value: _locationServices,
                  onChanged: (value) {
                    setState(() {
                      _locationServices = value;
                    });
                  },
                ),
                _buildSwitchTile(
                  title: 'Background Location',
                  subtitle: 'Track location in background for deliveries',
                  value: _backgroundLocation,
                  onChanged: (value) {
                    setState(() {
                      _backgroundLocation = value;
                    });
                  },
                ),
              ],
            ),

            // Language & Region Section
            _buildSection(
              title: 'اللغة',
              children: [
                _buildDropdownTile(
                  title: 'اللغة',
                  subtitle: 'اختر لغة التطبيق',
                  value: currentLanguageLabel,
                  options: languageOptions,
                  onChanged: (value) {
                    // For now, just update the UI - language switching will be implemented later
                    setState(() {
                      currentLanguageLabel = value!;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('تم تحديد اللغة: $value'),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  },
                ),
              ],
            ),

            // Appearance Section
            _buildSection(
              title: 'Appearance',
              children: [
                _buildDropdownTile(
                  title: 'Theme',
                  subtitle: 'App appearance theme',
                  value: _selectedTheme,
                  options: ['Light', 'Dark', 'System'],
                  onChanged: (value) {
                    setState(() {
                      _selectedTheme = value!;
                    });
                  },
                ),
              ],
            ),

            // Privacy Section
            _buildSection(
              title: 'Privacy',
              children: [
                _buildTappableTile(
                  title: 'Privacy Policy',
                  subtitle: 'View our privacy policy',
                  icon: Icons.privacy_tip_outlined,
                  onTap: () {
                    _showPrivacyPolicy();
                  },
                ),
                _buildTappableTile(
                  title: 'Data Usage',
                  subtitle: 'Manage your data preferences',
                  icon: Icons.data_usage,
                  onTap: () {
                    _showDataUsage();
                  },
                ),
              ],
            ),

            // Security Section
            _buildSection(
              title: 'Security',
              children: [
                _buildTappableTile(
                  title: 'Change Password',
                  subtitle: 'Update your account password',
                  icon: Icons.lock_outline,
                  onTap: () {
                    _showChangePassword();
                  },
                ),
                _buildTappableTile(
                  title: 'Two-Factor Authentication',
                  subtitle: 'Enable 2FA for extra security',
                  icon: Icons.security,
                  onTap: () {
                    _showTwoFactorAuth();
                  },
                ),
              ],
            ),

            // Storage Section
            _buildSection(
              title: 'Storage',
              children: [
                _buildTappableTile(
                  title: 'Clear Cache',
                  subtitle: 'Free up storage space',
                  icon: Icons.storage,
                  onTap: () {
                    _showClearCache();
                  },
                ),
                _buildTappableTile(
                  title: 'Download Settings',
                  subtitle: 'Manage offline data downloads',
                  icon: Icons.download,
                  onTap: () {
                    _showDownloadSettings();
                  },
                ),
              ],
            ),

            // About Section
            _buildSection(
              title: 'About',
              children: [
                _buildTappableTile(
                  title: 'App Version',
                  subtitle: '1.0.0 (Build 1)',
                  icon: Icons.info_outline,
                  onTap: () {
                    _showVersionInfo();
                  },
                ),
                _buildTappableTile(
                  title: 'Terms of Service',
                  subtitle: 'Read our terms of service',
                  icon: Icons.description,
                  onTap: () {
                    _showTermsOfService();
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GradientBorderContainer(
        borderWidth: 2,
        borderRadius: DesignTokens.radiusLarge,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
            boxShadow: [
              BoxShadow(
                color: HadhirColors.obsidianCore.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                    color: HadhirColors.obsidianCore,
              ),
            ),
          ),
          ...children,
        ],
      ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, color: HadhirColors.obsidianCore),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 14,
          color: HadhirColors.obsidianCore.withOpacity(0.6),
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return HadhirColors.arcticCyan;
          }
          return null; // Use default
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return HadhirColors.arcticCyan.withOpacity(0.3);
          }
          return null; // Use default
        }),
      ),
    );
  }

  Widget _buildDropdownTile({
    required String title,
    required String subtitle,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, color: HadhirColors.obsidianCore),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 14,
          color: HadhirColors.obsidianCore.withOpacity(0.6),
        ),
      ),
      trailing: DropdownButton<String>(
        value: value,
        underline: Container(),
        items: options.map((option) {
          return DropdownMenuItem<String>(value: option, child: Text(option));
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildTappableTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Icon(icon, color: HadhirColors.arcticCyan),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, color: HadhirColors.obsidianCore),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.grey400),
      onTap: onTap,
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'Privacy Policy for Wizz Driver App\n\n'
            '1. Information Collection\n'
            'We collect information necessary for delivery services including location data, contact information, and payment details.\n\n'
            '2. Data Usage\n'
            'Your data is used to facilitate deliveries, process payments, and improve our services.\n\n'
            '3. Data Sharing\n'
            'We do not share personal information with third parties without consent, except as required by law.\n\n'
            '4. Data Security\n'
            'We implement industry-standard security measures to protect your data.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showDataUsage() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Data Usage'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Data collected by the app:'),
            SizedBox(height: 12),
            Text('• Location data for navigation and delivery tracking'),
            Text('• Contact information for account management'),
            Text('• Vehicle information for delivery assignments'),
            Text('• Payment information for earnings processing'),
            Text('• Device information for app optimization'),
            SizedBox(height: 12),
            Text('You can manage your data preferences in the app settings.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showChangePassword() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement password change logic
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Password changed successfully'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  void _showTwoFactorAuth() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Two-Factor Authentication'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enhance your account security with two-factor authentication.',
            ),
            SizedBox(height: 16),
            Text('Available methods:'),
            SizedBox(height: 8),
            Text('• SMS verification'),
            Text('• Email verification'),
            Text('• Authenticator app'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('2FA setup feature coming soon'),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
            child: const Text('Setup'),
          ),
        ],
      ),
    );
  }

  void _showClearCache() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Cache'),
        content: const Text(
          'This will clear temporary files and may free up storage space. '
          'You may need to re-download some data when using the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cache cleared successfully'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showDownloadSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Download Settings'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Manage offline data downloads:'),
            SizedBox(height: 16),
            Text('• Map data for offline navigation'),
            Text('• Delivery area information'),
            Text('• Restaurant location data'),
            SizedBox(height: 16),
            Text('Download over WiFi only to save mobile data.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showVersionInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('App Version'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Wizz Driver'),
            SizedBox(height: 8),
            Text('Version: 1.0.0'),
            Text('Build: 1 (2024.12.15)'),
            SizedBox(height: 16),
            Text('© 2024 Wizz Delivery'),
            SizedBox(height: 16),
            Text('For support, contact: support@wizz.com'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTermsOfService() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Terms of Service'),
        content: const SingleChildScrollView(
          child: Text(
            'Terms of Service for Wizz Driver App\n\n'
            '1. Acceptance of Terms\n'
            'By using this application, you agree to be bound by these terms.\n\n'
            '2. Driver Responsibilities\n'
            'Drivers must provide safe, reliable, and timely delivery services.\n\n'
            '3. Payment Terms\n'
            'Payments will be processed according to our payment schedule and policies.\n\n'
            '4. Service Standards\n'
            'Maintain professional conduct and follow all traffic laws while delivering.\n\n'
            '5. Account Termination\n'
            'We reserve the right to terminate accounts for violations of these terms.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
