import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/verification_throttle_service.dart';
import '../utils/identity_normalizer.dart';
import '../widgets/verification_code_input.dart';
import '../../../services/logging/auth_logger.dart';
import '../../../app_colors.dart';
import '../../../services/auth_service.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _phoneController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _isResending = false; // maintained for button state
  bool _codeSent = false;
  bool _codeVerified = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String _currentCode = ''; // holds latest OTP input
  Key _otpKey = UniqueKey();
  String? _normalizedPhone; // set upon first send

  @override
  void dispose() {
    _phoneController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendVerificationCode() async {
    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال رقم الهاتف'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!RegExp(
      r'^(\+964|0)(7[0-9]{9})$',
    ).hasMatch(_phoneController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('رقم الهاتف غير صحيح'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final phoneRaw = _phoneController.text.trim();
    _normalizedPhone = IdentityNormalizer.normalizeIraqiPhone(phoneRaw);
    final throttleNotifier = ref.read(verificationThrottleProvider.notifier);
    final throttleState = ref.read(verificationThrottleProvider).identityState(_normalizedPhone!);
    if (throttleState.cooldownRemaining > 0 || throttleState.isSending) {
      return; // ignore spam taps
    }
    throttleNotifier.setSending(_normalizedPhone!, true);
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await AuthService.sendVerificationCode(phoneRaw);
      if (result['success'] == true) {
        throttleNotifier.recordSend(_normalizedPhone!);
        AuthLogger().logSendCode(
          identity: _normalizedPhone!,
          channel: 'phone',
          purpose: 'password_reset',
          attempt: ref.read(verificationThrottleProvider).identityState(_normalizedPhone!).recentSends.length,
          cooldownSeconds: ref.read(verificationThrottleProvider).identityState(_normalizedPhone!).currentCooldownDuration,
        );
      } else {
        throttleNotifier.setError(_normalizedPhone!, result['message'] ?? 'فشل في إرسال الرمز');
        AuthLogger().logSendCode(
          identity: _normalizedPhone!,
          channel: 'phone',
          purpose: 'password_reset',
          attempt: ref.read(verificationThrottleProvider).identityState(_normalizedPhone!).recentSends.length + 1,
          cooldownSeconds: ref.read(verificationThrottleProvider).identityState(_normalizedPhone!).currentCooldownDuration,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'فشل في إرسال رمز التحقق'), backgroundColor: AppColors.error),
          );
        }
        return;
      }
      setState(() {
        _codeSent = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال رمز التحقق'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في إرسال رمز التحقق: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (_normalizedPhone != null) {
        throttleNotifier.setSending(_normalizedPhone!, false);
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool get _isCodeComplete => _currentCode.length == 6 && _currentCode.replaceAll(RegExp(r'\D'), '').length == 6; // standardized to 6 digits

  Future<void> _verifyCode() async {
    if (!_isCodeComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال رمز التحقق المكون من 6 أرقام'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await AuthService.verifyPhone(
        phone: _phoneController.text.trim(),
        code: _currentCode,
      );

      if (result['success']) {
        setState(() {
          _codeVerified = true;
        });
        if (_normalizedPhone != null) {
          AuthLogger().logVerifyCode(
            identity: _normalizedPhone!,
            channel: 'phone',
            purpose: 'password_reset',
            success: true,
          );
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم التحقق من الرمز بنجاح'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'رمز التحقق غير صحيح'),
              backgroundColor: AppColors.error,
            ),
          );
          // reset OTP widget
          setState(() { _otpKey = UniqueKey(); _currentCode = ''; });
          if (_normalizedPhone != null) {
            AuthLogger().logVerifyCode(
              identity: _normalizedPhone!,
              channel: 'phone',
              purpose: 'password_reset',
              success: false,
              failureReason: 'code_mismatch',
            );
          }
        }
      }
    } catch (e) {
      if (_normalizedPhone != null) {
        AuthLogger().logVerifyCode(
          identity: _normalizedPhone!,
          channel: 'phone',
          purpose: 'password_reset',
          success: false,
          failureReason: 'exception',
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في التحقق: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    if (_newPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال كلمة المرور الجديدة'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_newPasswordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('كلمة المرور يجب أن تكون 6 أحرف على الأقل'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('كلمة المرور غير متطابقة'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final code = _currentCode; // use captured OTP instead of removed _codeControllers
      final result = await AuthService.resetPassword(
        phone: _phoneController.text.trim(),
        code: code,
        newPassword: _newPasswordController.text,
      );

      if (result['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تغيير كلمة المرور بنجاح'),
              backgroundColor: AppColors.success,
            ),
          );
          context.pop(); // Return to login screen
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'فشل في تغيير كلمة المرور'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تغيير كلمة المرور: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resendCode() async {
    if (_normalizedPhone == null) return; // can't resend before first send
    final identity = _normalizedPhone!;
    final throttle = ref.read(verificationThrottleProvider);
    final state = throttle.identityState(identity);
    if (state.cooldownRemaining > 0 || state.isSending) return;

    setState(() {
      _isResending = true;
    });

    try {
      final result = await AuthService.sendVerificationCode(_phoneController.text.trim());
      final notifier = ref.read(verificationThrottleProvider.notifier);
      if (result['success'] == true) {
        notifier.recordSend(identity);
        AuthLogger().logSendCode(
          identity: identity,
          channel: 'phone',
          purpose: 'password_reset',
          attempt: ref.read(verificationThrottleProvider).identityState(identity).recentSends.length,
          cooldownSeconds: ref.read(verificationThrottleProvider).identityState(identity).currentCooldownDuration,
        );
      } else {
        notifier.setError(identity, result['message'] ?? 'فشل في إعادة الإرسال');
        AuthLogger().logSendCode(
          identity: identity,
          channel: 'phone',
          purpose: 'password_reset',
          attempt: ref.read(verificationThrottleProvider).identityState(identity).recentSends.length + 1,
          cooldownSeconds: ref.read(verificationThrottleProvider).identityState(identity).currentCooldownDuration,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال رمز التحقق مرة أخرى'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في إعادة الإرسال: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  void _onOtpChanged(String code) {
    setState(() { _currentCode = code; });
    if (_isCodeComplete && !_codeVerified) {
      _verifyCode();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cooldown = _normalizedPhone == null
        ? 0
        : ref.watch(verificationThrottleProvider).identityState(_normalizedPhone!).cooldownRemaining;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('نسيت كلمة المرور'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              // Icon and header
              const Icon(Icons.lock_reset, size: 80, color: AppColors.primary),
              const SizedBox(height: 24),
              const Text(
                'استعادة كلمة المرور',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _codeSent
                    ? 'أدخل رمز التحقق وكلمة المرور الجديدة'
                    : 'أدخل رقم هاتفك لاستلام رمز التحقق',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),

              // Phone number field
              TextFormField(
                controller: _phoneController,
                enabled: !_codeSent,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف',
                  hintText: '07XX XXX XXXX',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              if (!_codeSent) ...[
                // Send code button
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendVerificationCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'إرسال رمز التحقق',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ] else ...[
                // OTP input fields
                const Text('رمز التحقق', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                VerificationCodeInput(
                  key: _otpKey,
                  length: 6, // switched to 6-digit standard
                  enabled: !_codeVerified && !_isLoading,
                  onChanged: _onOtpChanged,
                  autoSubmit: false,
                ),
                const SizedBox(height: 16),

                // Resend code
                TextButton(
                  onPressed: (_isResending || _codeVerified || cooldown > 0) ? null : _resendCode,
                  child: _isResending
                      ? const CircularProgressIndicator()
                      : Text(
                          cooldown > 0 ? 'إعادة الإرسال خلال ${cooldown}s' : 'إعادة إرسال الرمز',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),

                if (_codeVerified) ...[
                  const SizedBox(height: 24),

                  // New password field
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: _obscureNewPassword,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور الجديدة',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNewPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureNewPassword = !_obscureNewPassword;
                          });
                        },
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Confirm new password field
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'تأكيد كلمة المرور الجديدة',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Reset password button
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _resetPassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'تغيير كلمة المرور',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ] else if (_codeSent) ...[
                  const SizedBox(height: 24),

                  // Verify code button
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _verifyCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'تحقق من الرمز',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
