import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app_colors.dart';
import '../../../models/profile_status.dart';
import '../../../providers/riverpod/services_provider.dart';
import '../../more/screens/vehicle_info_screen.dart';

class AccountStatusScreen extends ConsumerStatefulWidget {
  const AccountStatusScreen({super.key});

  @override
  ConsumerState<AccountStatusScreen> createState() =>
      _AccountStatusScreenState();
}

class _AccountStatusScreenState extends ConsumerState<AccountStatusScreen>
    with WidgetsBindingObserver {
  ProfileStatus? _profileStatus;
  bool _checking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_checkStatus());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_checkStatus());
  }

  Future<void> _checkStatus() async {
    if (_checking || !mounted) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final profile = await ref
          .read(profileCompletionServiceProvider)
          .checkProfileCompleteness();
      if (!mounted) return;
      if (profile.error != null) {
        setState(() => _error = 'تعذّر تحديث حالة الحساب. أعد المحاولة.');
      } else if (profile.status == ProfileStatusEnum.suspended ||
          profile.status == ProfileStatusEnum.rejected) {
        setState(() => _profileStatus = profile);
      } else {
        context.go('/splash');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذّر تحديث حالة الحساب. أعد المحاولة.');
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profileStatus;
    final suspended = profile?.status == ProfileStatusEnum.suspended;
    final title = profile == null
        ? 'حالة الحساب'
        : suspended
            ? 'حساب معلّق'
            : 'تم رفض طلب الانضمام';
    final theme = Theme.of(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Theme(
        data: theme.copyWith(
          textTheme: theme.textTheme.apply(fontFamily: 'NotoSansArabic'),
        ),
        child: Scaffold(
          backgroundColor: AppColors.white,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 38, 24, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Icon(Icons.manage_accounts_outlined,
                            size: 32, color: AppColors.secondary),
                      ),
                      const SizedBox(height: 16),
                      Semantics(
                        header: true,
                        child: Text(title,
                            style: const TextStyle(
                              color: AppColors.secondaryDark,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            )),
                      ),
                      if (profile != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          suspended
                              ? 'أوقفت الإدارة استقبال الطلبات لهذا الحساب. إذا أعادت اعتماده، يمكنك التحقق من الحالة هنا.'
                              : 'يمكنك الاطلاع على حالة وثائقك وتحديث الوثائق التي تحتاج إلى مراجعة.',
                          style: const TextStyle(
                              color: Color(0xFF52647B), height: 1.65),
                        ),
                      ],
                      if (_error case final error?) ...[
                        const SizedBox(height: 12),
                        Semantics(
                          liveRegion: true,
                          child: Text(error,
                              style: const TextStyle(color: Color(0xFF932628))),
                        ),
                      ],
                      const SizedBox(height: 22),
                      FilledButton.icon(
                        onPressed: _checking ? null : _checkStatus,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.secondaryDark,
                          minimumSize: const Size.fromHeight(52),
                        ),
                        icon: const Icon(Icons.refresh),
                        label: Text(
                            _checking ? 'جارٍ التحقق…' : 'تحديث حالة الحساب'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) => const VehicleInfoScreen()),
                          );
                          if (mounted) await _checkStatus();
                        },
                        icon: const Icon(Icons.directions_car_outlined),
                        label: const Text('مركباتي ووثائقي'),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () async {
                          await ref.read(authServiceProvider).logout();
                          if (context.mounted) context.go('/login');
                        },
                        child: const Text('تسجيل الخروج'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
