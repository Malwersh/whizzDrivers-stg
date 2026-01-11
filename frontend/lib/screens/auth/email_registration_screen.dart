// Email Registration Screen
// Allows users to register with email and password
// Version: 1.0
// Date: 2025-10-18

import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app_colors.dart';

class EmailRegistrationScreen extends ConsumerStatefulWidget {
  const EmailRegistrationScreen({super.key});

  @override
  ConsumerState<EmailRegistrationScreen> createState() =>
      _EmailRegistrationScreenState();
}

class _EmailRegistrationScreenState
    extends ConsumerState<EmailRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreedToTerms = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'الرجاء إدخال البريد الإلكتروني';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'البريد الإلكتروني غير صحيح';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'الرجاء إدخال كلمة المرور';
    }
    if (value.length < 8) {
      return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'يجب أن تحتوي على حرف كبير';
    }
    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'يجب أن تحتوي على حرف صغير';
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'يجب أن تحتوي على رقم';
    }
    if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'يجب أن تحتوي على رمز خاص';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'الرجاء تأكيد كلمة المرور';
    }
    if (value != _passwordController.text) {
      return 'كلمة المرور غير متطابقة';
    }
    return null;
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب الموافقة على الشروط والأحكام'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Call backend API for email registration
      final response = await _registerWithBackend(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      setState(() => _isLoading = false);

      if (!mounted) return;

      if (response['success'] == true) {
        debugPrint('✅ Email registration successful');

        context.push(
          '/email-verification',
          extra: {
            'email': _emailController.text.trim(),
            // Use email as the Cognito username for email-based signup.
            // The User Pool supports email sign-in, and this ensures the code is delivered via email (not SMS).
            'username': _emailController.text.trim(),
            'delivery': response['delivery'],
            'fromSignup': true,
            'isEmailAuth': true,
          },
        );
      } else if (response['requiresVerification'] == true) {
        // User exists but unconfirmed - go to verification
        debugPrint(
          '⚠️ User exists but unconfirmed - redirecting to verification',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response['message'] ?? 'يرجى التحقق من بريدك الإلكتروني',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );

        context.push(
          '/email-verification',
          extra: {
            'email': _emailController.text.trim(),
            // Existing but UNCONFIRMED users still need confirmSignUp.
            // Use email as username to force email delivery.
            'username': _emailController.text.trim(),
            'delivery': response['delivery'],
            'fromSignup': true,
            'isEmailAuth': true,
          },
        );
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['error'] ?? 'فشل التسجيل'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;

      debugPrint('❌ Registration error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في الاتصال: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<Map<String, dynamic>> _registerWithBackend({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('📧 Starting email registration with Amplify Auth');
      debugPrint('📧 Email: $email');

      // ✅ Use email as username for email-based signup.
      // Using a phone-like username causes Cognito to treat it as phone_number and often deliver codes via SMS.
      final username = email;

      final signUpResult = await Amplify.Auth.signUp(
        username: username,
        password: password,
        options: SignUpOptions(
          userAttributes: {
            AuthUserAttributeKey.email: email,
            AuthUserAttributeKey.name: 'Driver',
            AuthUserAttributeKey.preferredUsername: email,
          },
        ),
      );

      debugPrint('✅ SignUp result: ${signUpResult.isSignUpComplete}');
      debugPrint('✅ Next step: ${signUpResult.nextStep.signUpStep}');

          final deliveryDetails = signUpResult.nextStep.codeDeliveryDetails;
          final deliveryDestination = deliveryDetails?.destination;
          final deliveryMedium = deliveryDetails?.deliveryMedium;
          debugPrint('📨 Code delivery medium: ${deliveryMedium?.name ?? "unknown"}');
          debugPrint('📨 Code delivery destination: ${deliveryDestination ?? "unknown"}');

      if (signUpResult.nextStep.signUpStep == AuthSignUpStep.confirmSignUp) {
        debugPrint('📧 Email verification required');
        return {
          'success': true,
          'requiresVerification': true,
          'message': 'تم إرسال رمز التحقق إلى بريدك الإلكتروني',
          // Backward compatible key used by the caller as the username for verification.
          'phoneUsername': username,
          'delivery': deliveryDestination,
        };
      } else if (signUpResult.isSignUpComplete) {
        debugPrint('✅ Registration complete without verification');
        return {
          'success': true,
          'message': 'تم التسجيل بنجاح',
          'phoneUsername': username,
        };
      } else {
        return {'success': false, 'error': 'خطأ غير متوقع في عملية التسجيل'};
      }
    } on UsernameExistsException catch (e) {
      debugPrint('⚠️ User already exists: ${e.message}');
      return {
        'success': false,
        'requiresVerification': true,
        // If user exists but is UNCONFIRMED, the verification flow should use email as username.
        'phoneUsername': email,
        'error': 'البريد الإلكتروني مستخدم بالفعل',
        'message': 'إذا لم تكن قد أكملت التحقق، يرجى المحاولة مرة أخرى',
      };
    } on InvalidPasswordException catch (e) {
      debugPrint('❌ Invalid password: ${e.message}');
      return {'success': false, 'error': 'كلمة المرور لا تستوفي المتطلبات'};
    } on AuthException catch (e) {
      debugPrint('❌ Auth error: ${e.message}');
      return {'success': false, 'error': e.message};
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      return {'success': false, 'error': 'خطأ غير متوقع: ${e.toString()}'};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'التسجيل بالبريد الإلكتروني',
          style: TextStyle(color: Colors.black87),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Icon
                const Icon(Icons.email_outlined, size: 80, color: AppColors.primary),
                const SizedBox(height: 24),

                // Title
                const Text(
                  'أنشئ حسابك',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                Text(
                  'املأ البيانات أدناه للتسجيل',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Email field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                  decoration: InputDecoration(
                    labelText: 'البريد الإلكتروني',
                    hintText: 'example@email.com',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
                const SizedBox(height: 16),

                // Password field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  validator: _validatePassword,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
                const SizedBox(height: 8),

                // Password requirements
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'متطلبات كلمة المرور:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900],
                        ),
                      ),
                      const SizedBox(height: 4),
                      _PasswordRequirement(
                        text: '8 أحرف على الأقل',
                        met: _passwordController.text.length >= 8,
                      ),
                      _PasswordRequirement(
                        text: 'حرف كبير (A-Z)',
                        met: _passwordController.text.contains(
                          RegExp(r'[A-Z]'),
                        ),
                      ),
                      _PasswordRequirement(
                        text: 'حرف صغير (a-z)',
                        met: _passwordController.text.contains(
                          RegExp(r'[a-z]'),
                        ),
                      ),
                      _PasswordRequirement(
                        text: 'رقم (0-9)',
                        met: _passwordController.text.contains(
                          RegExp(r'[0-9]'),
                        ),
                      ),
                      _PasswordRequirement(
                        text: 'رمز خاص (!@#\$%)',
                        met: _passwordController.text.contains(
                          RegExp(r'[!@#$%^&*(),.?":{}|<>]'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Confirm password field
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  validator: _validateConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'تأكيد كلمة المرور',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(
                          () => _obscureConfirmPassword =
                              !_obscureConfirmPassword,
                        );
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
                const SizedBox(height: 16),

                // Terms and conditions
                Row(
                  children: [
                    Checkbox(
                      value: _agreedToTerms,
                      onChanged: (value) {
                        setState(() => _agreedToTerms = value ?? false);
                      },
                      activeColor: AppColors.primary,
                    ),
                    Expanded(
                      child: Text(
                        'أوافق على الشروط والأحكام وسياسة الخصوصية',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Register button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'تسجيل',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
                const SizedBox(height: 16),

                // Already have account
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'لديك حساب بالفعل؟ ',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text(
                        'تسجيل الدخول',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordRequirement extends StatelessWidget {
  final String text;
  final bool met;

  const _PasswordRequirement({required this.text, required this.met});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: met ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: met ? Colors.green[700] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
