import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/riverpod/services_provider.dart';

import '../../design_system/app_colors.dart';
import '../../design_system/arctic_cyan_demo.dart';
import '../../design_system/colors.dart';
import '../../l10n/app_localizations.dart';
import '../../models/driver_profile.dart';
import '../../screens/wizz_logo_demo.dart';
import '../../screens/wizz_logo_showcase.dart';
import '../../services/driver_service.dart';
import '../../utils/app_icon_generator.dart';
import '../../widgets/gradient_border_container.dart';
import '../../widgets/wizz_logo.dart';
import '../earnings/earnings_tab.dart';
// import '../wallet/screens/wallet_screen.dart'; // TODO: إضافة المحفظة الجديدة
import 'screens/account_details_screen.dart';
import 'screens/app_settings_screen.dart';
import 'screens/delivery_equipment_screen.dart';
import 'screens/emergency_contacts_screen.dart';
import 'screens/identity_verification_screen.dart';
import 'screens/live_chat_screen.dart';
import 'screens/payment_methods_screen.dart';
import 'screens/vehicle_info_screen.dart';

class MoreTab extends ConsumerStatefulWidget {
  final ValueChanged<bool>? onDashStatusChanged;
  final bool isDashing;

  const MoreTab({super.key, this.onDashStatusChanged, this.isDashing = false});

  @override
  ConsumerState<MoreTab> createState() => _MoreTabState();
}

class _MoreTabState extends ConsumerState<MoreTab> {
  DriverProfile? _driverProfile;
  bool _isLoading = true;
  bool _didRetryLoad = false;

  @override
  void initState() {
    super.initState();
    _loadDriverProfile();
  }

  Future<void> _loadDriverProfile() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }
      final profile = await DriverService.getDriverProfile();
      setState(() {
        _driverProfile = profile;
        _isLoading = false;
      });

      // If the first fetch happened before the auth session was fully restored,
      // we can end up with null here. Retry once after a short delay.
      if (profile == null && !_didRetryLoad && mounted) {
        _didRetryLoad = true;
        await Future.delayed(const Duration(milliseconds: 900));
        if (mounted) {
          await _loadDriverProfile();
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load profile: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: HadhirColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: HadhirColors.primary,
        scrolledUnderElevation: 0,
        surfaceTintColor: HadhirColors.primary,
        shadowColor: HadhirColors.primary.withOpacity(0.3),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        toolbarHeight: 50, // Thin app bar
        automaticallyImplyLeading: false, // Remove back button
        centerTitle: true,
        titleSpacing: 20,
        leading: const Padding(
          padding: EdgeInsets.all(8.0),
          child: WizzLogoCompact(size: 32),
        ),
        title: const Text(
          'المزيد',
          style: TextStyle(
            color: HadhirColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 0.5,
            color: Colors.black.withOpacity(0.1),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  HadhirColors.secondary,
                ), // Green loading indicator
              ),
            )
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildProfileHeader(),
                  _buildSection(
                    title: localizations.driverTools,
                    items: [
                      _buildMenuItem(
                        icon: Icons.account_balance_wallet,
                        title: localizations.wallet,
                        subtitle: localizations.viewEarningsAndBalance,
                        iconColor:
                            HadhirColors.secondary, // Green accent for wallet
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const Center(child: Text('المحفظة قيد البناء')),
                            ),
                          );
                        },
                      ),
                      _buildMenuItem(
                        icon: Icons.attach_money_outlined,
                        title: localizations.earnings,
                        subtitle: localizations.viewDailyAndWeeklyEarnings,
                        iconColor:
                            HadhirColors.secondary, // Green accent for earnings
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const EarningsTab(),
                            ),
                          );
                        },
                      ),
                      if (widget.isDashing)
                        _buildMenuItem(
                          icon: Icons.stop_circle,
                          title: localizations.wizzOff,
                          subtitle: localizations.endYourDashSession,
                          onTap: _showStopDashDialog,
                        ),
                    ],
                  ),
                  _buildSection(
                    title: localizations.account,
                    items: [
                      _buildMenuItem(
                        icon: Icons.payment_outlined,
                        title: localizations.paymentMethods,
                        iconColor:
                            HadhirColors.darkGray, // Dark gray for sub-items
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const PaymentMethodsScreen(),
                            ),
                          );
                        },
                      ),
                      _buildMenuItem(
                        icon: Icons.account_balance_wallet_outlined,
                        title: localizations.instantPay,
                        subtitle: localizations.getPaidInstantly,
                        iconColor: HadhirColors
                            .secondary, // Green accent for instant pay
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Instant payment setup would open here',
                              ),
                              backgroundColor:
                                  HadhirColors.secondary, // Green snackbar
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  _buildSection(
                    title: localizations.vehicleAndEquipment,
                    items: [
                      _buildMenuItem(
                        icon: Icons.directions_car_outlined,
                        title: localizations.vehicleInformation,
                        iconColor:
                            HadhirColors.darkGray, // Dark gray for sub-items
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const VehicleInfoScreen(),
                            ),
                          );
                        },
                      ),
                      _buildMenuItem(
                        icon: Icons.local_shipping_outlined,
                        title: localizations.deliveryEquipment,
                        iconColor:
                            HadhirColors.darkGray, // Dark gray for sub-items
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const DeliveryEquipmentScreen(),
                            ),
                          );
                        },
                      ),
                      _buildMenuItem(
                        icon: Icons.phone_android_outlined,
                        title: localizations.phoneNumber,
                        subtitle: _driverProfile?.phone ?? localizations.notSet,
                        iconColor:
                            HadhirColors.darkGray, // Dark gray for sub-items
                        onTap: () {
                          _showPhoneUpdateDialog();
                        },
                      ),
                    ],
                  ),
                  _buildSection(
                    title: localizations.safety,
                    items: [
                      _buildMenuItem(
                        icon: Icons.security_outlined,
                        title: localizations.safetyToolkit,
                        iconColor:
                            HadhirColors.secondary, // Green accent for safety
                        onTap: () {
                          _showSafetyDialog();
                        },
                      ),
                      _buildMenuItem(
                        icon: Icons.contact_emergency_outlined,
                        title: localizations.emergencyContacts,
                        iconColor:
                            HadhirColors.darkGray, // Dark gray for sub-items
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const EmergencyContactsScreen(),
                            ),
                          );
                        },
                      ),
                      _buildMenuItem(
                        icon: Icons.verified_user_outlined,
                        title: localizations.identityVerification,
                        subtitle: _getVerificationStatus(),
                        iconColor:
                            HadhirColors.darkGray, // Dark gray for sub-items
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const IdentityVerificationScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  _buildSection(
                    title: localizations.support,
                    items: [
                      _buildMenuItem(
                        icon: Icons.chat_bubble_outline,
                        title: localizations.liveChat,
                        subtitle: localizations.chatWithOurSupportTeam,
                        iconColor:
                            HadhirColors.secondary, // Green accent for support
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const LiveChatScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  _buildSection(
                    title: localizations.legal,
                    items: [
                      _buildMenuItem(
                        icon: Icons.description_outlined,
                        title: localizations.termsOfService,
                        iconColor:
                            HadhirColors.darkGray, // Dark gray for sub-items
                        onTap: () {
                          _showTermsDialog();
                        },
                      ),
                      _buildMenuItem(
                        icon: Icons.privacy_tip_outlined,
                        title: localizations.privacyPolicy,
                        iconColor:
                            HadhirColors.darkGray, // Dark gray for sub-items
                        onTap: () {
                          _showPrivacyDialog();
                        },
                      ),
                      _buildMenuItem(
                        icon: Icons.gavel_outlined,
                        title: localizations.occupationalAccidentPolicy,
                        iconColor:
                            HadhirColors.darkGray, // Dark gray for sub-items
                        onTap: () {
                          _showAccidentPolicyDialog();
                        },
                      ),
                    ],
                  ),
                  _buildSection(
                    title: localizations.app,
                    items: [
                      _buildMenuItem(
                        icon: Icons.settings_outlined,
                        title: localizations.settings,
                        iconColor:
                            HadhirColors.darkGray, // Dark gray for sub-items
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AppSettingsScreen(),
                            ),
                          );
                        },
                      ),
                      _buildMenuItem(
                        icon: Icons.palette_outlined,
                        title: 'Arctic Cyan Colors',
                        subtitle: 'View the new color system',
                        iconColor:
                            HadhirColors.darkGray, // Dark gray for sub-items
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ArcticCyanDemo(),
                            ),
                          );
                        },
                      ),
                      _buildMenuItem(
                        icon: Icons.apps_rounded,
                        title: 'App Icon Preview',
                        subtitle: 'View Wizz logo app icons',
                        iconColor:
                            HadhirColors.darkGray, // Dark gray for sub-items
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AppIconPreview(),
                            ),
                          );
                        },
                      ),
                      _buildMenuItem(
                        icon: Icons.auto_awesome,
                        title: 'WIZZ Logo Demo',
                        subtitle: 'Complete logo showcase',
                        iconColor:
                            HadhirColors.brandingOrange, // Orange for demo
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const WizzLogoDemo(),
                            ),
                          );
                        },
                      ),
                      _buildMenuItem(
                        icon: Icons.photo_library,
                        title: 'WIZZ Logo Showcase',
                        subtitle: 'Official SVG & App Icons',
                        iconColor: HadhirColors
                            .secondary, // Green for official showcase
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const WizzLogoShowcase(),
                            ),
                          );
                        },
                      ),
                      _buildMenuItem(
                        icon: Icons.info_outline,
                        title: localizations.about,
                        subtitle: '${localizations.version} 1.0.0',
                        iconColor:
                            HadhirColors.darkGray, // Dark gray for sub-items
                        onTap: () {
                          _showAboutDialog();
                        },
                      ),
                    ],
                  ),
                  Container(
                    margin: const EdgeInsets.all(16),
                    width: double.infinity,
                    height: 56,
                    child: GradientBorderContainer(
                      borderWidth: 2,
                      borderRadius: 28,
                      child: OutlinedButton(
                        onPressed: () {
                          _showSignOutDialog();
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: Text(
                          localizations.signOut,
                          style: const TextStyle(
                            color: HadhirColors.darkGray,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: GradientBorderContainer(
        borderWidth: 2,
        borderRadius: 16,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.white, // Monochrome: pure white background
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: 0.03,
                ), // Subtle monochrome shadow
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AccountDetailsScreen(),
            ),
          );
        },
        child: Row(
          children: [
            _buildProfileAvatar(),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _driverProfile?.name ?? 'Driver Name',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.star,
                        color: AppColors.warning,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_driverProfile?.rating.toStringAsFixed(1) ?? '4.9'} • Driver since ${_getJoinedDate()}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.grey400),
          ],
        ),
      ),
        ),
      ),
    );
  }

  String _getJoinedDate() {
    if (_driverProfile?.joinDate != null) {
      final date = _driverProfile!.joinDate;
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[date.month - 1]} ${date.year}';
    }
    return 'Nov 2023';
  }

  String _getVerificationStatus() {
    final localizations = AppLocalizations.of(context)!;
    if (_driverProfile?.isVerified == true) {
      return localizations.verified;
    }
    return localizations.pendingVerification;
  }

  Widget _buildProfileAvatar() {
    final profilePhoto = _driverProfile?.profilePhoto;

    if (profilePhoto != null && profilePhoto.isNotEmpty) {
      return GradientBorderContainer.circular(
        borderWidth: 3,
        child: Container(
          width: 60,
          height: 60,
          decoration: const BoxDecoration(shape: BoxShape.circle),
          child: ClipOval(
            child: profilePhoto.startsWith('data:')
                ? Image.memory(
                    _getImageBytesFromDataUrl(profilePhoto),
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildDefaultAvatar();
                    },
                  )
                : Image.network(
                    profilePhoto,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildDefaultAvatar();
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return _buildDefaultAvatar();
                    },
                  ),
          ),
        ),
      );
    }

    return _buildDefaultAvatar();
  }

  Widget _buildDefaultAvatar() {
    return GradientBorderContainer.circular(
      borderWidth: 3,
      child: Container(
        width: 60,
        height: 60,
        decoration: const BoxDecoration(
          color: Colors.white, // Monochrome: white background
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.person,
          size: 30,
          color: Colors.black, // Monochrome: black icon
        ),
      ),
    );
  }

  Uint8List _getImageBytesFromDataUrl(String dataUrl) {
    // Extract base64 part from data URL (data:image/jpeg;base64,...)
    final base64String = dataUrl.split(',').last;
    return base64Decode(base64String);
  }

  Widget _buildSection({required String title, required List<Widget> items}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GradientBorderContainer(
        borderWidth: 2,
        borderRadius: 16,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white, // Monochrome: pure white background
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: 0.03,
                ), // Subtle monochrome shadow
                blurRadius: 10,
                offset: const Offset(0, 2),
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
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              ...items,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? AppColors.textSecondary, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing,
            if (trailing == null)
              const Icon(Icons.chevron_right, color: AppColors.grey400),
          ],
        ),
      ),
    );
  }

  void _showPhoneUpdateDialog() {
    final TextEditingController phoneController = TextEditingController();
    // Capture the parent context to safely use after awaits
    final parentContext = context;
    showDialog(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Update Phone Number'),
        content: TextField(
          controller: phoneController,
          decoration: const InputDecoration(
            labelText: 'Phone Number',
            hintText: '+964 123 456 7890',
            prefixText: '+964 ',
          ),
          keyboardType: TextInputType.phone,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (phoneController.text.isNotEmpty) {
                Navigator.pop(dialogContext);
                final success = await DriverService.updatePhoneNumber(
                  phoneController.text,
                );
                if (!parentContext.mounted) return;
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Phone number updated successfully'
                          : 'Failed to update phone number',
                    ),
                    backgroundColor:
                        success
                        ? HadhirColors.secondary
                        : AppColors.error, // Green for success
                  ),
                );
                if (success) _loadDriverProfile();
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showSafetyDialog() {
    final localizations = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.safetyToolkit),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.phone, color: AppColors.error),
              title: Text(localizations.emergencyCall),
              subtitle: Text(localizations.call911),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Emergency calling feature'),
                    backgroundColor: AppColors.error,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_on, color: AppColors.primary),
              title: Text(localizations.shareLocation),
              subtitle: Text(localizations.shareWithEmergencyContact),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Location sharing enabled')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.report, color: AppColors.warning),
              title: Text(localizations.reportIssue),
              subtitle: Text(localizations.reportSafetyConcern),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report safety issue')),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.close),
          ),
        ],
      ),
    );
  }

  void _showTermsDialog() {
    final localizations = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.termsOfService),
        content: const SingleChildScrollView(
          child: Text(
            'Here would be the Terms of Service content...\n\n'
            'This would contain the full legal terms and conditions for using the Hadhir Driver app.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.close),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog() {
    final localizations = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.privacyPolicy),
        content: const SingleChildScrollView(
          child: Text(
            'Here would be the Privacy Policy content...\n\n'
            'This would contain information about how user data is collected, used, and protected.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.close),
          ),
        ],
      ),
    );
  }

  void _showAccidentPolicyDialog() {
    final localizations = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.occupationalAccidentPolicy),
        content: const SingleChildScrollView(
          child: Text(
            'Here would be the Occupational Accident Policy content...\n\n'
            'This would contain information about accident coverage and procedures.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.close),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    final localizations = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.aboutWizzDriver),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${localizations.version}: 1.0.0'),
            const SizedBox(height: 8),
            Text('${localizations.build}: 2024.12.15'),
            const SizedBox(height: 8),
            const Text('© 2024 Wizz, Inc.'),
            const SizedBox(height: 8),
            Text(localizations.madeForIraqiDrivers),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.close),
          ),
        ],
      ),
    );
  }

  void _showSignOutDialog() {
    final localizations = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.signOut),
        content: Text(localizations.signOutConfirmation,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _signOut();
            },
            child: Text(
              localizations.signOut,
              style: const TextStyle(color: HadhirColors.darkGray),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      );

      // Enhanced logout using CognitoAuthService
      try {
        debugPrint('🚪 Starting enhanced logout process...');
        
        // Use auth service for proper logout
        final authService = ref.read(authServiceProvider);
        await authService.logout();
        
        debugPrint('✅ Auth service logout completed successfully');
        
        // Small delay to ensure cleanup is complete
        await Future.delayed(const Duration(milliseconds: 500));
        
      } catch (e) {
        debugPrint('⚠️ Error during logout cleanup: $e');
        // Continue with navigation even if cleanup fails
      }

      if (mounted) Navigator.pop(context); // Close loading dialog

      // Navigate to login screen using go_router
      if (mounted) {
        context.go('/login');
        debugPrint('🔄 Navigated to /login after logout');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading dialog
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تسجيل الخروج: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showStopDashDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.stop_circle, color: AppColors.error),
            SizedBox(width: 8),
            Text('WIZZ off'),
          ],
        ),
        content: const Text(
          'Are you sure you want to stop your dash? You won\'t receive any new delivery opportunities.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _stopDash();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
            ),
            child: const Text('WIZZ off'),
          ),
        ],
      ),
    );
  }

  void _stopDash() {
    if (widget.onDashStatusChanged != null) {
      widget.onDashStatusChanged!(false);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Dash stopped. Have a great day!'),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 3),
      ),
    );
  }
}
