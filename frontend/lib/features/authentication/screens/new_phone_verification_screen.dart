import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../providers/riverpod/services_provider.dart';
import '../../../services/logging/auth_logger.dart';
import '../../../config/app_config.dart';

import '../../../app_colors.dart';
import '../services/verification_throttle_service.dart';
import '../utils/identity_normalizer.dart';
import '../widgets/verification_code_input.dart';

class NewPhoneVerificationScreen extends ConsumerStatefulWidget {
  final String phoneNumber;
  final bool isNewRegistration;

  const NewPhoneVerificationScreen({
    super.key,
    required this.phoneNumber,
    this.isNewRegistration = false,
  });

  @override
  ConsumerState<NewPhoneVerificationScreen> createState() =>
      _NewPhoneVerificationScreenState();
}

class _NewPhoneVerificationScreenState
    extends ConsumerState<NewPhoneVerificationScreen> {
  bool _isLoading = false;
  bool _isResending = false;
  late final String _normalizedPhone;
  String _currentCode = '';
  String? _errorMessage;
  Key _otpWidgetKey = UniqueKey();

  AuthLogger get _logger => AuthLogger();

  @override
  void initState() {
    super.initState();
    _normalizedPhone = IdentityNormalizer.normalizeIraqiPhone(widget.phoneNumber);
    // Start initial cooldown when arriving (simulate first send already done)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(verificationThrottleProvider.notifier).recordSend(_normalizedPhone);
      _logger.logSendCode(
        identity: _normalizedPhone,
        channel: 'phone',
        purpose: 'signup',
        attempt: 1,
        cooldownSeconds: ref.read(verificationThrottleProvider).identityState(_normalizedPhone).currentCooldownDuration,
      );
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  bool get _isCodeComplete {
    return _currentCode.length == 6 && _currentCode.replaceAll(RegExp(r'\D'), '').length == 6;
  }

  void _onCodeChanged(String code) {
    setState(() {
      _currentCode = code;
      _errorMessage = null;
    });
  }

  void _resetCode() {
    setState(() {
      _currentCode = '';
      _otpWidgetKey = UniqueKey();
    });
  }

  Future<void> _verifyCode() async {
    if (!_isCodeComplete) {
      setState(() {
        _errorMessage = 'يرجى إدخال الرمز كاملاً';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      Map<String, dynamic> result;
      
      if (AppConfig.enableAWSIntegration) {
        // Use CognitoAuthService for AWS integration
        final cognitoService = ref.read(cognitoAuthServiceProvider);
        result = await cognitoService.verifyPhoneNumber(
          phone: widget.phoneNumber, // Use original phone format
          verificationCode: _currentCode,
        );
      } else {
        // Use NewAuthService for mock mode
        final authService = ref.read(newAuthServiceProvider);
        result = await authService.verifyPhoneNumber(
          phone: widget.phoneNumber, // Use original phone format
          verificationCode: _currentCode,
        );
      }

      if (result['success'] == true) {
        // After successful phone verification, check if this is a new registration
        if (widget.isNewRegistration) {
          // For new registrations, navigate to profile setup screen
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم التحقق بنجاح! يرجى إكمال بيانات التسجيل.'),
                backgroundColor: Colors.green,
              ),
            );

            // Wait a moment then navigate to profile setup
            await Future.delayed(const Duration(milliseconds: 1500));
            if (mounted) {
              context.pushReplacement(
                '/driver-profile-setup',
                extra: {'phone': widget.phoneNumber},
              );
            }
          }
        } else {
          // For existing users (unconfirmed account verification), try to sign in
          try {
            // Try to get password from SharedPreferences or use a default approach
            final prefs = await SharedPreferences.getInstance();
            final tempPassword = prefs.getString('temp_registration_password');

            if (tempPassword != null) {
              bool signInSuccess = false;

              if (AppConfig.enableAWSIntegration) {
                // Use CognitoAuthService for login
                final cognitoService = ref.read(cognitoAuthServiceProvider);
                signInSuccess = await cognitoService.loginWithPhone(
                  phone: widget.phoneNumber, // Use original phone format
                  password: tempPassword,
                );
              } else {
                // Use NewAuthService for login
                final authService = ref.read(newAuthServiceProvider);
                signInSuccess = await authService.loginWithPhone(
                  phone: widget.phoneNumber, // Use original phone format
                  password: tempPassword,
                );
              }

              if (signInSuccess) {
                // Clear temporary password
                await prefs.remove('temp_registration_password');

                if (mounted) {
                  // Show success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم التحقق بنجاح! جاري تسجيل الدخول...'),
                      backgroundColor: Colors.green,
                    ),
                  );

                  // Wait a moment then navigate to home page
                  await Future.delayed(const Duration(milliseconds: 1500));
                  if (mounted) {
                    context.go('/');
                  }
                }
              } else {
                // Verification successful but sign-in failed - show success for verification
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم التحقق بنجاح! يرجى تسجيل الدخول.'),
                      backgroundColor: Colors.green,
                    ),
                  );

                  // Wait a moment then navigate to login
                  await Future.delayed(const Duration(milliseconds: 1500));
                  if (mounted) {
                    context.go('/new-login');
                  }
                }
              }
            } else {
              // No password stored - verification successful but need manual login
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم التحقق بنجاح! يرجى تسجيل الدخول.'),
                    backgroundColor: Colors.green,
                  ),
                );

                // Wait a moment then navigate to login
                await Future.delayed(const Duration(milliseconds: 1500));
                if (mounted) {
                  context.go('/new-login');
                }
              }
            }
          } catch (signInError) {
            // Sign-in failed, but verification was successful
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم التحقق بنجاح! يرجى تسجيل الدخول.'),
                  backgroundColor: Colors.green,
                ),
              );

              // Wait a moment then navigate to login
              await Future.delayed(const Duration(milliseconds: 1500));
              if (mounted) {
                context.go('/new-login');
              }
            }
          }
        }
        
        _logger.logVerifyCode(
          identity: _normalizedPhone,
          channel: 'phone',
          purpose: 'signup',
          success: true,
        );
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'الرمز غير صحيح، يرجى المحاولة مرة أخرى';
          _resetCode();
        });
        _logger.logVerifyCode(
          identity: _normalizedPhone,
          channel: 'phone',
          purpose: 'signup',
          success: false,
          failureReason: 'code_mismatch',
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'حدث خطأ أثناء التحقق. يرجى المحاولة مرة أخرى';
        _resetCode();
      });
      _logger.logVerifyCode(
        identity: _normalizedPhone,
        channel: 'phone',
        purpose: 'signup',
        success: false,
        failureReason: 'exception',
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  int get _resendCooldown {
    final throttle = ref.watch(verificationThrottleProvider);
    return throttle.identityState(_normalizedPhone).cooldownRemaining;
  }

  Future<void> _resendCode() async {
    if (_resendCooldown > 0 || _isResending) return;

    setState(() { _isResending = true; _errorMessage = null; });

    final notifier = ref.read(verificationThrottleProvider.notifier);
    notifier.setSending(_normalizedPhone, true);

    try {
      Map<String, dynamic> result;
      
      if (AppConfig.enableAWSIntegration) {
        // Use CognitoAuthService for AWS integration
        final cognitoService = ref.read(cognitoAuthServiceProvider);
        result = await cognitoService.resendConfirmationCode(username: widget.phoneNumber);
      } else {
        // Use NewAuthService for mock mode
        final authService = ref.read(newAuthServiceProvider);
        result = await authService.sendPhoneVerification(phone: widget.phoneNumber); // Use original phone format
      }
      
      if (result['success'] == true) {
        notifier.recordSend(_normalizedPhone);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال رمز التحقق الجديد'), backgroundColor: Colors.green));
        }
        _logger.logSendCode(
          identity: _normalizedPhone,
          channel: 'phone',
          purpose: 'signup',
          attempt: ref.read(verificationThrottleProvider).identityState(_normalizedPhone).recentSends.length,
          cooldownSeconds: ref.read(verificationThrottleProvider).identityState(_normalizedPhone).currentCooldownDuration,
        );
      } else {
        final msg = result['message'] ?? 'فشل في إرسال الرمز. يرجى المحاولة مرة أخرى';
        notifier.setError(_normalizedPhone, msg);
        setState(() { _errorMessage = msg; });
        _logger.logSendCode(
          identity: _normalizedPhone,
          channel: 'phone',
          purpose: 'signup',
          attempt: ref.read(verificationThrottleProvider).identityState(_normalizedPhone).recentSends.length + 1,
          cooldownSeconds: ref.read(verificationThrottleProvider).identityState(_normalizedPhone).currentCooldownDuration,
        );
      }
    } catch (e) {
      notifier.setError(_normalizedPhone, 'حدث خطأ أثناء إرسال الرمز');
      setState(() { _errorMessage = 'حدث خطأ أثناء إرسال الرمز'; });
      _logger.logSendCode(
        identity: _normalizedPhone,
        channel: 'phone',
        purpose: 'signup',
        attempt: ref.read(verificationThrottleProvider).identityState(_normalizedPhone).recentSends.length + 1,
        cooldownSeconds: ref.read(verificationThrottleProvider).identityState(_normalizedPhone).currentCooldownDuration,
      );
    } finally {
      notifier.setSending(_normalizedPhone, false);
      if (mounted) setState(() { _isResending = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/new-login');
            }
          },
        ),
        title: const Text(
          'تحقق من رقم الهاتف',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 40),

            // Phone icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.phone_android,
                size: 40,
                color: AppColors.primary,
              ),
            ),

            const SizedBox(height: 32),

            // Title
            const Text(
              'أدخل رمز التحقق',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 12),

            // Subtitle
            const Text(
              'تم إرسال رمز التحقق المكون من 6 أرقام إلى',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            // Phone number
            Text(
              widget.phoneNumber,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),

            const SizedBox(height: 40),

            // OTP Input replaced with reusable widget
            VerificationCodeInput(
              key: _otpWidgetKey,
              enabled: !_isLoading,
              onChanged: _onCodeChanged,
              onCompleted: (_) => _verifyCode(),
            ),

            const SizedBox(height: 24),

            // Error message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            const SizedBox(height: 32),

            // Verify button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading || !_isCodeComplete ? null : _verifyCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.textSecondary.withAlpha(77),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
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
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 24),

            // Resend code
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'لم تستلم الرمز؟ ',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                GestureDetector(
                  onTap: _resendCooldown > 0 ? null : _resendCode,
                  child: Text(
                    _resendCooldown > 0
                        ? 'إعادة الإرسال خلال $_resendCooldownث'
                        : (_isResending ? 'جاري الإرسال...' : 'إعادة الإرسال'),
                    style: TextStyle(
                      color: _resendCooldown > 0 || _isResending
                          ? AppColors.textSecondary
                          : AppColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            const Spacer(),
          ],
        ),
      ),
    );
  }
}
