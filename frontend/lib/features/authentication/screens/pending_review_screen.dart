// Pending Review Screen
// Shown when driver profile is under admin review
// Version: 1.0

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../services/push_notifications_service.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/riverpod/services_provider.dart';

class PendingReviewScreen extends ConsumerStatefulWidget {
  const PendingReviewScreen({super.key});

  @override
  ConsumerState<PendingReviewScreen> createState() =>
      _PendingReviewScreenState();
}

class _PendingReviewScreenState extends ConsumerState<PendingReviewScreen>
    with WidgetsBindingObserver {
  StreamSubscription<dynamic>? _events;
  bool _checking = false;
  bool _checkAgain = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _events =
        PushNotificationsService.profileEvents.listen((_) => _checkStatus());
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkStatus());
  }

  @override
  void dispose() {
    _events?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkStatus();
  }

  Future<void> _checkStatus() async {
    if (!mounted) return;
    if (_checking) {
      _checkAgain = true;
      return;
    }
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final status = await ref
          .read(profileCompletionServiceProvider)
          .checkProfileCompleteness();
      if (!mounted) return;
      if (status.error != null) {
        setState(() => _error = 'تعذر التحقق من الحالة. أعد المحاولة.');
      } else if (status.canAccessMainApp) {
        context.go('/');
      } else if (status.status.name == 'rejected' ||
          status.status.name == 'suspended') {
        context.go('/account-status');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذر التحقق من الحالة. أعد المحاولة.');
      }
    } finally {
      if (mounted) {
        setState(() => _checking = false);
        if (_checkAgain) {
          _checkAgain = false;
          unawaited(_checkStatus());
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Pending icon
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.hourglass_empty,
                      size: 60,
                      color: Colors.blue.shade600,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Title
                  Text(
                    'تحت المراجعة',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Message
                  Text(
                    'ملفك الشخصي قيد المراجعة من قبل الإدارة\n'
                    'سيتم إشعارك عند اكتمال المراجعة',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey.shade700,
                          height: 1.5,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Info card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.blue.shade700),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'معلومات هامة',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '• عادة ما تستغرق المراجعة 1-3 أيام عمل\n'
                          '• تأكد من أن رقم هاتفك صحيح\n'
                          '• قد نتواصل معك في حالة الحاجة لمعلومات إضافية',
                          style: TextStyle(
                            color: Colors.blue.shade900,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  if (_error != null)
                    Text(_error!, textAlign: TextAlign.center),
                  TextButton.icon(
                    onPressed: _checking ? null : _checkStatus,
                    icon: const Icon(Icons.refresh),
                    label: Text(
                        _checking ? 'جاري التحقق…' : 'التحقق من حالة الطلب'),
                  ),
                  // Logout button
                  OutlinedButton(
                    onPressed: () async {
                      final authService = ref.read(authServiceProvider);
                      await authService.logout();
                      if (context.mounted) {
                        context.go('/login');
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: const Text('تسجيل الخروج'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
