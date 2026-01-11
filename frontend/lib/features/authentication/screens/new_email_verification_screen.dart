import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/riverpod/services_provider.dart';
import '../../../services/logging/auth_logger.dart';

import '../../../app_colors.dart';
import '../../../config/app_config.dart';
import '../services/verification_throttle_service.dart';
import '../utils/identity_normalizer.dart';
import '../widgets/verification_code_input.dart';

/// Unified email verification screen using centralized throttle service
class NewEmailVerificationScreen extends ConsumerStatefulWidget {
  final String username; // Cognito username (could be email or phone canonical)
  final String email; // Display email (may be empty if unknown)
  final String? delivery; // Masked destination from AWS (e.g., e***@d***.com)
  final bool fromSignup;

  const NewEmailVerificationScreen({
    super.key,
    required this.username,
    required this.email,
    this.delivery,
    this.fromSignup = false,
  });

  @override
  ConsumerState<NewEmailVerificationScreen> createState() => _NewEmailVerificationScreenState();
}

class _NewEmailVerificationScreenState extends ConsumerState<NewEmailVerificationScreen> {
  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;
  late final String _normalizedEmail; // identity key for throttle
  String _currentCode = ''; // captured OTP digits
  Key _otpKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _normalizedEmail = IdentityNormalizer.normalizeEmail(widget.email.isNotEmpty ? widget.email : widget.username);
    // Start initial cooldown (assume a code was just sent leading to this screen)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(verificationThrottleProvider.notifier).recordSend(_normalizedEmail);
      // Log initial code send event (implicit from signup / previous action)
      AuthLogger().logSendCode(
        identity: _normalizedEmail,
        channel: 'email',
        purpose: widget.fromSignup ? 'signup' : 'login',
        attempt: 1,
        cooldownSeconds: ref.read(verificationThrottleProvider).identityState(_normalizedEmail).currentCooldownDuration,
      );
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  bool get _isCodeComplete => _currentCode.length == 6 && _currentCode.replaceAll(RegExp(r'\D'), '').length == 6;

  int get _resendCooldown {
    final throttle = ref.watch(verificationThrottleProvider);
    return throttle.identityState(_normalizedEmail).cooldownRemaining;
  }

  Future<void> _verifyCode() async {
    if (!_isCodeComplete || _isVerifying) return;
    setState(() { _isVerifying = true; _errorMessage = null; });

    final code = _currentCode; // actual entered code
    try {
      bool success = false;
      if (AppConfig.enableAWSIntegration) {
        final cognito = ref.read(cognitoAuthServiceProvider);
        
        if (widget.fromSignup) {
          // For signup users, use confirmEmail method
          success = await cognito.confirmEmail(
            email: widget.username, 
            verificationCode: code
          );
        } else {
          // For existing users, use email attribute confirmation
          success = await cognito.confirmEmailAttribute(verificationCode: code);
        }
      } else {
        final newAuth = ref.read(newAuthServiceProvider);
        success = await newAuth.confirmEmail(email: _normalizedEmail, verificationCode: code);
      }

      if (success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم التحقق من البريد الإلكتروني بنجاح'), backgroundColor: AppColors.success));
        // Navigate: if coming from signup maybe to login, else to main navigation
        if (widget.fromSignup) {
          context.go('/new-login');
        } else {
          context.go('/navigation');
        }
      } else {
        setState(() { _errorMessage = 'الرمز غير صحيح، يرجى المحاولة مرة أخرى'; });
        _clearCode();
        AuthLogger().logVerifyCode(
          identity: _normalizedEmail,
          channel: 'email',
          purpose: widget.fromSignup ? 'signup' : 'login',
          success: false,
          failureReason: 'code_mismatch',
        );
      }
    } catch (e) {
      setState(() { _errorMessage = 'تعذر التحقق. الرجاء المحاولة مجدداً'; });
      _clearCode();
      AuthLogger().logVerifyCode(
        identity: _normalizedEmail,
        channel: 'email',
        purpose: widget.fromSignup ? 'signup' : 'login',
        success: false,
        failureReason: 'exception',
      );
    } finally {
      if (mounted) {
        setState(() { _isVerifying = false; });
      }
    }
  }

  Future<void> _resendCode() async {
    if (_resendCooldown > 0 || _isResending) return;
    setState(() { _isResending = true; _errorMessage = null; });
    final notifier = ref.read(verificationThrottleProvider.notifier);
    notifier.setSending(_normalizedEmail, true);

    try {
      bool success = false;
      String? message;

      if (AppConfig.enableAWSIntegration) {
        final cognito = ref.read(cognitoAuthServiceProvider);
        
        // Use email-specific verification for existing users to ensure email delivery
        if (!widget.fromSignup) {
          final res = await cognito.sendEmailVerificationCode(email: _normalizedEmail);
          success = res['success'] == true;
          message = res['delivery_message'] ?? res['message'];
        } else {
          // For signup, use resend signup code (this may still go to SMS if both email/phone registered)
          final res = await cognito.resendConfirmationCodeWithDetails(username: widget.username);
          success = res['success'] == true;
          message = res['delivery_message'] ?? res['message'];
        }
      } else {
        // Mock resend in offline mode
        await Future.delayed(const Duration(milliseconds: 400));
        success = true;
        message = 'تم إرسال رمز التحقق إلى بريدك الإلكتروني';
      }

      if (success) {
        notifier.recordSend(_normalizedEmail);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(message ?? 'تم إرسال رمز التحقق الجديد إلى بريدك الإلكتروني'), 
            backgroundColor: AppColors.success
          ));
        }
        AuthLogger().logSendCode(
          identity: _normalizedEmail,
          channel: 'email',
          purpose: widget.fromSignup ? 'signup' : 'login',
          attempt: ref.read(verificationThrottleProvider).identityState(_normalizedEmail).recentSends.length,
          cooldownSeconds: ref.read(verificationThrottleProvider).identityState(_normalizedEmail).currentCooldownDuration,
        );
      } else {
        final msg = message ?? 'فشل في إعادة إرسال الرمز';
        notifier.setError(_normalizedEmail, msg);
        setState(() { _errorMessage = msg; });
        AuthLogger().logSendCode(
          identity: _normalizedEmail,
          channel: 'email',
          purpose: widget.fromSignup ? 'signup' : 'login',
          attempt: ref.read(verificationThrottleProvider).identityState(_normalizedEmail).recentSends.length + 1,
          cooldownSeconds: ref.read(verificationThrottleProvider).identityState(_normalizedEmail).currentCooldownDuration,
        );
      }
    } catch (e) {
      const msg = 'حدث خطأ أثناء إعادة الإرسال';
      notifier.setError(_normalizedEmail, msg);
      setState(() { _errorMessage = msg; });
      AuthLogger().logSendCode(
        identity: _normalizedEmail,
        channel: 'email',
        purpose: widget.fromSignup ? 'signup' : 'login',
        attempt: ref.read(verificationThrottleProvider).identityState(_normalizedEmail).recentSends.length + 1,
        cooldownSeconds: ref.read(verificationThrottleProvider).identityState(_normalizedEmail).currentCooldownDuration,
      );
    } finally {
      notifier.setSending(_normalizedEmail, false);
      if (mounted) setState(() { _isResending = false; });
    }
  }

  void _clearCode() {
    // regenerate key to rebuild VerificationCodeInput and clear all fields
    setState(() { _currentCode = ''; _otpKey = UniqueKey(); });
  }

  String get _displayEmail {
    // Prefer delivery (masked) if present, else provided email/username
    if (widget.delivery != null && widget.delivery!.isNotEmpty) return widget.delivery!;
    if (widget.email.isNotEmpty) return widget.email;
    return widget.username; // fallback (may already be email)
  }

  @override
  Widget build(BuildContext context) {
    // Watch throttle ticks to update countdown
    ref.watch(verificationThrottleProvider);

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
            onPressed: () => context.go('/new-login'),
        ),
        title: const Text(
          'التحقق من البريد',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 8),
              const Icon(Icons.mark_email_read_outlined, size: 72, color: AppColors.primary),
              const SizedBox(height: 16),
              const Text(
                'أدخل رمز التحقق المكون من 6 أرقام المرسل إلى بريدك الإلكتروني',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                _displayEmail,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Code input boxes
              VerificationCodeInput(
                key: _otpKey,
                onCompleted: (_) => _verifyCode(),
                onChanged: (code) { setState(() { _currentCode = code; _errorMessage = null; }); },
              ),
              const SizedBox(height: 24),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),

              const SizedBox(height: 8),

              // Verify button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isVerifying || !_isCodeComplete ? null : _verifyCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.textSecondary.withAlpha(77),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isVerifying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                          ),
                        )
                      : const Text(
                          'تأكيد',
                          style: TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // Resend code link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'لم تستلم الرمز؟ ',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                  GestureDetector(
                    onTap: _resendCooldown > 0 ? null : _resendCode,
                    child: Text(
                      _resendCooldown > 0
                          ? 'إعادة الإرسال خلال $_resendCooldownث'
                          : (_isResending ? 'جاري الإرسال...' : 'إعادة الإرسال'),
                      style: TextStyle(
                        color: _resendCooldown > 0 || _isResending ? AppColors.textSecondary : AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              TextButton(
                onPressed: () => context.go('/new-login'),
                child: const Text(
                  'العودة لتسجيل الدخول',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14, decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
