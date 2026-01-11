import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_colors.dart';
import '../../config/app_config.dart';
import '../../providers/riverpod/services_provider.dart';
import '../../features/authentication/utils/smart_input_detector.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  String _detectedInputType = 'unknown';
  bool _obscurePassword = true;
  bool _isLoading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward();
    
    // Listen to input changes for smart detection
    _usernameController.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    final newType = SmartInputDetector.detectInputType(
      _usernameController.text,
    );
    if (newType != _detectedInputType) {
      setState(() {
        _detectedInputType = newType;
      });
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final username = _usernameController.text.trim();
      final password = _passwordController.text;
      final inputType = SmartInputDetector.detectInputType(username);

      bool success = false;
      String message = 'An unknown error occurred.';

      if (AppConfig.enableAWSIntegration) {
        // Use AWS Cognito for authentication with detailed messages
        final cognitoService = ref.read(cognitoAuthServiceProvider);

        if (inputType == 'email') {
          final res = await cognitoService.loginWithEmailDetailed(
            email: username,
            password: password,
          );
          success = res['success'] == true;
          message = res['message'] ?? (success ? 'تم تسجيل الدخول بنجاح' : 'فشل في تسجيل الدخول');
        } else if (inputType == 'phone') {
          final normalizedPhone = SmartInputDetector.normalizePhone(username);
          final res = await cognitoService.loginWithPhoneDetailed(
            phone: normalizedPhone,
            password: password,
          );
          success = res['success'] == true;
          message = res['message'] ?? (success ? 'تم تسجيل الدخول بنجاح' : 'فشل في تسجيل الدخول');
        } else {
          message = 'يرجى إدخال بريد إلكتروني صحيح أو رقم هاتف عراقي';
        }
      } else {
        // Use mock auth service for offline mode
        final authService = ref.read(newAuthServiceProvider);

        if (inputType == 'email') {
          success = await authService.loginWithEmail(
            email: username,
            password: password,
          );
          message = success ? 'تم تسجيل الدخول بنجاح' : 'فشل في تسجيل الدخول';
        } else if (inputType == 'phone') {
          final normalizedPhone = SmartInputDetector.normalizePhone(username);
          success = await authService.loginWithPhone(
            phone: normalizedPhone,
            password: password,
          );
          message = success ? 'تم تسجيل الدخول بنجاح' : 'فشل في تسجيل الدخول';
        } else {
          message = 'يرجى إدخال بريد إلكتروني صحيح أو رقم هاتف عراقي';
        }
      }

      if (mounted) {
        if (success) {
          _showMessage(message, true);
          // إضافة معالجة خاصة لحل مشكلة "a user is already signed in"
          await _handlePostLogin();
          context.go('/');
        } else {
          _showMessage(message, false);
        }
      }
    } catch (e) {
      if (mounted) {
        _showMessage('خطأ في تسجيل الدخول: ${e.toString()}', false);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// معالجة ما بعد تسجيل الدخول لحل مشكلة الجلسات المتضاربة
  Future<void> _handlePostLogin() async {
    try {
      final cognitoService = ref.read(cognitoAuthServiceProvider);
      
      // تحديث حالة التطبيق وحفظ معلومات الجلسة
      await cognitoService.getCurrentDriver();
      
      debugPrint('✅ تم تسجيل الدخول وحفظ الجلسة بنجاح');
    } catch (e) {
      debugPrint('⚠️ خطأ في معالجة ما بعد تسجيل الدخول: $e');
    }
  }

  /// Show message to user
  void _showMessage(String message, bool isSuccess) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isSuccess ? AppColors.success : AppColors.error,
          duration: Duration(seconds: isSuccess ? 2 : 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      // Compact logo
                      Align(
                        alignment: Alignment.center,
                        child: Container(
                          height: 64,
                          width: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withAlpha(31),
                          ),
                          child: const Icon(
                            Icons.delivery_dining,
                            size: 34,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Titles
                      const Text(
                        'أهلاً بعودتك',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'سجّل دخولك للمتابعة',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Smart input field (auto-detects email or phone)
                      TextFormField(
                        controller: _usernameController,
                        keyboardType: SmartInputDetector.getKeyboardType(
                          _detectedInputType,
                        ),
                        decoration: InputDecoration(
                          labelText: SmartInputDetector.getLabelText(
                            _detectedInputType,
                          ),
                          hintText: SmartInputDetector.getHintText(
                            _detectedInputType,
                          ),
                          prefixIcon: Icon(
                            SmartInputDetector.getIcon(_detectedInputType),
                            color: AppColors.primary,
                          ),
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 12,
                          ),
                        ),
                        validator: (value) {
                          final inputType = SmartInputDetector.detectInputType(
                            value ?? '',
                          );
                          return SmartInputDetector.validateInput(
                            value ?? '',
                            inputType,
                          );
                        },
                      ),

                      const SizedBox(height: 12),

                      // Password field (compact)
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور',
                          prefixIcon: const Icon(
                            Icons.lock,
                            color: AppColors.primary,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 12,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'يرجى إدخال كلمة المرور';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 8),

                      // Forgot password (right aligned, compact)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => context.push('/forgot-password'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'نسيت كلمة المرور؟',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Primary action: Login
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.primary
                                .withAlpha(153),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'تسجيل الدخول',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Secondary action: Create account (always visible, compact)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => context.push('/register-method'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'إنشاء حساب جديد',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),
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
