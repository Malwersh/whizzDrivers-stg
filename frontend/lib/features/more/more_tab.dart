import '../../legal/application_legal_screen.dart';
import '../../providers/riverpod/tab_provider.dart';
import 'screens/offer_sound_test_sheet.dart';
import 'screens/driver_quality_screen.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
import '../earnings/earnings_screen.dart';
import '../wallet/screens/wallet_home_screen.dart';
import 'screens/account_details_screen.dart';
import 'screens/driver_performance_screen.dart';
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
  final Future<DriverProfile?> Function()? loadProfile;

  const MoreTab(
      {super.key,
      this.onDashStatusChanged,
      this.isDashing = false,
      this.loadProfile});

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
      final profile = await (widget.loadProfile?.call() ??
          DriverService.getDriverProfile());
      if (!mounted) return;
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
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر تحميل بيانات الحساب. حاول التحديث مجددًا.'),
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
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        automaticallyImplyLeading: false,
        leading: IconButton(
            tooltip: 'العودة إلى الخريطة',
            onPressed: () =>
                ref.read(selectedTabProvider.notifier).state = DriverTabs.home,
            icon:
                const Icon(Icons.arrow_back_ios_new, color: Color(0xFF00296B))),
        centerTitle: true,
        title: const Text('المزيد',
            style: TextStyle(
                color: Color(0xFF00296B),
                fontSize: 20,
                fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
              tooltip: 'تحديث الحساب',
              onPressed: _isLoading ? null : _loadDriverProfile,
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF00296B)))
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  HadhirColors.secondary,
                ), // Green loading indicator
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadDriverProfile,
              child: SingleChildScrollView(
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
                                builder: (context) => const WalletHomeScreen(),
                              ),
                            );
                          },
                        ),
                        _buildMenuItem(
                          icon: Icons.attach_money_outlined,
                          title: localizations.earnings,
                          subtitle: localizations.viewDailyAndWeeklyEarnings,
                          iconColor: HadhirColors
                              .secondary, // Green accent for earnings
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const EarningsScreen(),
                              ),
                            );
                          },
                        ),
                        _buildMenuItem(
                          icon: Icons.insights_outlined,
                          title: 'أدائي',
                          subtitle: 'معدلات الأداء وتقييمات العملاء',
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const DriverPerformanceScreen(),
                              )),
                        ),
                        _buildMenuItem(
                          icon: Icons.shield_outlined,
                          title: 'الجودة والسلامة',
                          subtitle: 'الملاحظات والاعتراضات',
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const DriverQualityScreen())),
                        ),
                        if (widget.isDashing)
                          _buildMenuItem(
                            icon: Icons.stop_circle,
                            title: localizations.wizzOff,
                            enabled: false,
                            subtitle: 'أوقف التوفر من الشاشة الرئيسية',
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
                          enabled: false,
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
                          subtitle: 'غير متاح حاليًا',
                          enabled: false,
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
                          title: 'مركباتي',
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
                          enabled: false,
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
                          enabled: false,
                          subtitle:
                              _driverProfile?.phone ?? localizations.notSet,
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
                          enabled: false,
                          iconColor:
                              HadhirColors.secondary, // Green accent for safety
                          onTap: () {
                            _showSafetyDialog();
                          },
                        ),
                        _buildMenuItem(
                          icon: Icons.contact_emergency_outlined,
                          title: localizations.emergencyContacts,
                          enabled: false,
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
                          enabled: false,
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
                          iconColor: HadhirColors
                              .secondary, // Green accent for support
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LiveChatScreen(),
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
                            icon: Icons.policy_outlined,
                            title: 'سياسة الاستخدام',
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const ApplicationLegalScreen(
                                            documentId: 'USAGE')))),
                        _buildMenuItem(
                            icon: Icons.assignment_return_outlined,
                            title: 'التعذر والعودة والسلامة',
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const ApplicationLegalScreen(
                                            documentId: 'CANCELLATION')))),
                        _buildMenuItem(
                          icon: Icons.description_outlined,
                          title: localizations.termsOfService,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ApplicationLegalScreen(
                                      documentId: 'TERMS'))),
                        ),
                        _buildMenuItem(
                          icon: Icons.privacy_tip_outlined,
                          title: localizations.privacyPolicy,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ApplicationLegalScreen(
                                      documentId: 'PRIVACY'))),
                        ),
                      ],
                    ),
                    _buildSection(
                      title: localizations.app,
                      items: [
                        _buildMenuItem(
                            icon: Icons.volume_up_outlined,
                            title: 'اختبار صوت العروض',
                            onTap: () => showOfferSoundTestSheet(context)),
                        _buildMenuItem(
                          icon: Icons.settings_outlined,
                          title: localizations.settings,
                          enabled: false,
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
                        if (kDebugMode)
                          _buildMenuItem(
                            icon: Icons.palette_outlined,
                            title: 'Arctic Cyan Colors',
                            subtitle: 'View the new color system',
                            iconColor: HadhirColors
                                .darkGray, // Dark gray for sub-items
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ArcticCyanDemo(),
                                ),
                              );
                            },
                          ),
                        if (kDebugMode)
                          _buildMenuItem(
                            icon: Icons.apps_rounded,
                            title: 'App Icon Preview',
                            subtitle: 'View Wizz logo app icons',
                            iconColor: HadhirColors
                                .darkGray, // Dark gray for sub-items
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AppIconPreview(),
                                ),
                              );
                            },
                          ),
                        if (kDebugMode)
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
                        if (kDebugMode)
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
                                  builder: (context) =>
                                      const WizzLogoShowcase(),
                                ),
                              );
                            },
                          ),
                        _buildMenuItem(
                          icon: Icons.info_outline,
                          title: localizations.about,
                          subtitle: 'معلومات تطبيق السائق',
                          iconColor:
                              HadhirColors.darkGray, // Dark gray for sub-items
                          onTap: () {
                            _showAboutDialog();
                          },
                        ),
                      ],
                    ),
                    Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                        child: OutlinedButton.icon(
                            onPressed: _showSignOutDialog,
                            icon: const Icon(Icons.logout_rounded, size: 20),
                            label: Text(localizations.signOut),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFB42318),
                                backgroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 52),
                                side:
                                    const BorderSide(color: Color(0xFFF0D6D3)),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14))))),
                    const SizedBox(height: 20),
                  ],
                ),
              )),
    );
  }

  static const _navy = Color(0xFF00296B);
  static const _muted = Color(0xFF667085);

  Widget _buildProfileHeader() {
    final profile = _driverProfile;
    final hasRating = (profile?.customerRatingCount ?? 0) > 0;
    return Container(
        margin: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFEAECF0))),
        clipBehavior: Clip.antiAlias,
        child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AccountDetailsScreen())),
              child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          _buildProfileAvatar(),
                          const SizedBox(width: 14),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(
                                    profile?.name.trim().isNotEmpty == true
                                        ? profile!.name
                                        : 'حساب السائق',
                                    style: const TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF182230))),
                                const SizedBox(height: 5),
                                Text(
                                    profile == null
                                        ? 'تعذر تحميل بيانات الحساب'
                                        : 'عرض معلومات الحساب وتحديثها',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        height: 1.5,
                                        color: _muted)),
                              ])),
                          const SizedBox(width: 6),
                          const Icon(Icons.chevron_left_rounded,
                              textDirection: TextDirection.ltr,
                              color: Color(0xFF98A2B3),
                              size: 20),
                        ]),
                        const SizedBox(height: 16),
                        const Divider(height: 1, color: Color(0xFFEAECF0)),
                        const SizedBox(height: 14),
                        Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (hasRating)
                                Semantics(
                                  label:
                                      'تقييم الزبائن ${profile!.rating.toStringAsFixed(1)} من 5',
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 0, vertical: 4),
                                    child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.star_rounded,
                                              color: Color(0xFFB77900),
                                              size: 19),
                                          const SizedBox(width: 6),
                                          Text(
                                              profile.rating.toStringAsFixed(1),
                                              textDirection: TextDirection.ltr,
                                              style: const TextStyle(
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.w700,
                                                  color: _navy)),
                                        ]),
                                  ),
                                )
                              else
                                Text(
                                    profile == null
                                        ? 'تعذر تحميل التقييم'
                                        : '—',
                                    style: const TextStyle(
                                        fontSize: 12, color: _muted)),
                              if (profile != null)
                                Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                        color: const Color(0xFFF0F4FA),
                                        borderRadius: BorderRadius.circular(7)),
                                    child: Text(_getVerificationStatus(),
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: _navy,
                                            fontWeight: FontWeight.w600))),
                            ]),
                        if (profile?.createdAt != null)
                          Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text('انضممت في ${_getJoinedDate()}',
                                  style: const TextStyle(
                                      fontSize: 11, color: _muted))),
                      ])),
            )));
  }

  String _getJoinedDate() {
    final date = _driverProfile?.createdAt;
    if (date == null) return 'تاريخ غير متاح';
    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _getVerificationStatus() {
    final localizations = AppLocalizations.of(context)!;
    return _driverProfile?.isVerified == true
        ? localizations.verified
        : localizations.pendingVerification;
  }

  Widget _buildProfileAvatar() {
    final photo = _driverProfile?.profilePhoto;
    if (photo == null || photo.isEmpty) return _buildDefaultAvatar();
    final image = photo.startsWith('data:')
        ? Image.memory(_getImageBytesFromDataUrl(photo),
            width: 54,
            height: 54,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildDefaultAvatar())
        : Image.network(photo,
            width: 54,
            height: 54,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildDefaultAvatar(),
            loadingBuilder: (_, child, progress) =>
                progress == null ? child : _buildDefaultAvatar());
    return ClipRRect(borderRadius: BorderRadius.circular(16), child: image);
  }

  Widget _buildDefaultAvatar() => Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
          color: const Color(0xFFF0F4FA),
          borderRadius: BorderRadius.circular(16)),
      child: const Icon(Icons.person_outline_rounded, size: 30, color: _navy));

  Uint8List _getImageBytesFromDataUrl(String dataUrl) {
    try {
      return base64Decode(dataUrl.split(',').last);
    } catch (_) {
      return Uint8List(0);
    }
  }

  Widget _buildSection({required String title, required List<Widget> items}) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _muted))),
          Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFEAECF0))),
              child: Column(children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    const Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: Color(0xFFF0F2F5)),
                  items[i],
                ]
              ])),
        ]),
      );

  Widget _buildMenuItem(
          {required IconData icon,
          required String title,
          String? subtitle,
          Widget? trailing,
          Color? iconColor,
          required VoidCallback onTap,
          bool enabled = true}) =>
      Material(
        color: Colors.white,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              child: Row(children: [
                Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: const Color(0xFFF0F4FA),
                        borderRadius: BorderRadius.circular(11)),
                    child: Icon(icon,
                        size: 20,
                        color: enabled ? _navy : const Color(0xFF98A2B3))),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color:
                                  enabled ? const Color(0xFF182230) : _muted)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(subtitle,
                            style: const TextStyle(
                                fontSize: 12, height: 1.5, color: _muted))
                      ],
                      if (!enabled &&
                          !(subtitle?.contains('غير متاح') ?? false)) ...[
                        const SizedBox(height: 4),
                        const Text('غير متاح حاليًا',
                            style: TextStyle(
                                fontSize: 12, height: 1.5, color: _muted)),
                      ],
                    ])),
                const SizedBox(width: 8),
                if (trailing != null)
                  trailing
                else if (enabled)
                  const Icon(Icons.chevron_left_rounded,
                      textDirection: TextDirection.ltr,
                      size: 18,
                      color: Color(0xFF98A2B3)),
              ])),
        ),
      );

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
                    backgroundColor: success
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

  void _showAboutDialog() {
    final localizations = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.aboutWizzDriver),
        content: const Text(
            'تطبيق ويز للسائق\n\nمتابعة الرحلات والأرباح والمحفظة، والوصول إلى الدعم ومعلومات الحساب.'),
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
        content: Text(
          localizations.signOutConfirmation,
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
