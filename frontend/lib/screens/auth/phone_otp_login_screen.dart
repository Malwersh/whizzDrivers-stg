import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app_colors.dart';
import '../../providers/driver_auth_provider.dart' as driver_auth;
import '../../services/phone_otp_auth_service.dart';
import '../../utils/iraqi_phone.dart';
import '../../services/account_deletion_service.dart';
import '../../features/more/screens/delete_account_screen.dart';

/// Phone sign-in for new and returning drivers.
class PhoneOtpLoginScreen extends ConsumerStatefulWidget {
  const PhoneOtpLoginScreen({super.key});
  @override
  ConsumerState<PhoneOtpLoginScreen> createState() =>
      _PhoneOtpLoginScreenState();
}

class _PhoneOtpLoginScreenState extends ConsumerState<PhoneOtpLoginScreen> {
  final _auth = PhoneOtpAuthService();
  final _phone = TextEditingController();
  final _code = TextEditingController();
  Timer? _timer;
  bool _busy = false;
  bool _sent = false;
  int _cooldown = 0;
  String? _message;
  final Future<bool> _savedDeletionReceipt =
      AccountDeletionService.hasSavedReceipt();

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy || _cooldown > 0) return;
    if (!IraqiPhone.isValid(_phone.text)) {
      setState(() => _message = 'أدخل رقم هاتف عراقي صحيح (+964)');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await _auth.requestCode(_phone.text);
      if (!mounted) return;
      setState(() {
        _sent = true;
        _cooldown = 60;
        _code.clear();
      });
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() => _cooldown--);
        if (_cooldown <= 0) timer.cancel();
      });
    } on PhoneAuthException catch (e) {
      if (mounted) setState(() => _message = e.message);
    } catch (_) {
      if (mounted) {
        setState(
            () => _message = 'تعذر إرسال الرمز. تحقق من الرقم وحاول لاحقًا.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    if (_busy) return;
    if (_code.text.length != 6) {
      setState(() => _message = 'أدخل رمز التحقق المكوّن من ٦ أرقام.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final success = await _auth.verifyCode(_code.text);
      if (!mounted) return;
      if (success) {
        ref.invalidate(driver_auth.currentDriverIdProvider);
        ref.invalidate(driver_auth.driverAuthStatusProvider);
        context.go('/splash', extra: {'phone': _auth.phone});
      } else {
        setState(() => _message = 'الرمز غير صحيح. حاول مجددًا.');
      }
    } on PhoneAuthException catch (e) {
      if (mounted) setState(() => _message = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _message =
            'تعذر إكمال تسجيل الدخول. أعد المحاولة أو اطلب رمزًا جديدًا.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static const _borderColor = Color(0xFFD9E2EE);
  static const _descriptionColor = Color(0xFF52647B);

  InputDecoration _inputDecoration({
    required String hint,
    Widget? prefixIcon,
  }) {
    OutlineInputBorder border(Color color, {double width = 1}) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      hintText: hint,
      border: border(_borderColor),
      enabledBorder: border(_borderColor),
      disabledBorder: border(_borderColor),
      focusedBorder: border(AppColors.secondary, width: 2),
      hintStyle: const TextStyle(color: Color(0xFF63758C)),
      filled: true,
      fillColor: const Color(0xFFF6F8FB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      prefixIcon: prefixIcon,
    );
  }

  void _editPhone() {
    setState(() {
      _sent = false;
      _message = null;
      _code.clear();
    });
  }

  Widget _brand() => Column(
        children: [
          Image.asset(
            'assets/images/wizz-wordmark-blue.png',
            width: 108,
            height: 46,
            fit: BoxFit.contain,
            semanticLabel: 'Wizz',
          ),
          const SizedBox(height: 8),
          const Text(
            'شركة الانطلاق الخاطف',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.secondary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
        ],
      );

  Widget _phoneField() => Directionality(
        textDirection: TextDirection.ltr,
        child: TextField(
          key: const ValueKey('driver-login-phone'),
          controller: _phone,
          enabled: !_busy,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _send(),
          autofillHints: const [AutofillHints.telephoneNumber],
          style: const TextStyle(
            color: AppColors.secondaryDark,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
          decoration: _inputDecoration(
            hint: '7XX XXX XXXX',
            prefixIcon: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Text(
                '+964',
                style: TextStyle(
                  color: AppColors.secondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      );

  Widget _codeField() => TextField(
        key: const ValueKey('driver-login-code'),
        controller: _code,
        enabled: !_busy,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLength: 6,
        onSubmitted: (_) => _verify(),
        autofillHints: const [AutofillHints.oneTimeCode],
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
          color: AppColors.secondaryDark,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 6,
        ),
        decoration: _inputDecoration(
          hint: '● ● ● ● ● ●',
        ).copyWith(counterText: ''),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heading = theme.textTheme.headlineMedium?.copyWith(
      color: AppColors.secondaryDark,
      fontSize: 26,
      height: 1.4,
      fontWeight: FontWeight.w800,
    );
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Theme(
        data: theme.copyWith(
          textTheme: theme.textTheme.apply(fontFamily: 'NotoSansArabic'),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: AppColors.secondary),
          ),
        ),
        child: Scaffold(
          backgroundColor: AppColors.white,
          body: SafeArea(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _brand(),
                        const SizedBox(height: 28),
                        Semantics(
                          header: true,
                          child: Text(
                            _sent ? 'التحقق من رقم الهاتف' : 'مرحبًا بك',
                            style: heading?.copyWith(
                              fontFamily: 'NotoSansArabic',
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _sent
                              ? 'أدخل الرمز الذي أرسلناه إلى رقمك.'
                              : 'أدخل رقم هاتفك لإرسال رمز التحقق.',
                          style: const TextStyle(
                            color: _descriptionColor,
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),
                        if (_sent) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                _auth.phone ?? _phone.text.trim(),
                                textDirection: TextDirection.ltr,
                                style: const TextStyle(
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextButton(
                                onPressed: _busy ? null : _editPhone,
                                child: const Text('تغيير الرقم'),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 20),
                        Text(
                          _sent ? 'رمز التحقق' : 'رقم الهاتف العراقي',
                          style: const TextStyle(
                            color: AppColors.secondaryDark,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Semantics(
                          label: _sent ? 'رمز التحقق' : 'رقم الهاتف العراقي',
                          child: _sent ? _codeField() : _phoneField(),
                        ),
                        if (_message case final message?) ...[
                          const SizedBox(height: 10),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              message,
                              style: const TextStyle(
                                color: Color(0xFFA62E32),
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            foregroundColor: AppColors.secondaryDark,
                            backgroundColor: AppColors.primary,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: const TextStyle(
                              fontFamily: 'NotoSansArabic',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: _busy || (!_sent && _cooldown > 0)
                              ? null
                              : _sent
                                  ? _verify
                                  : _send,
                          child: _busy
                              ? const SizedBox.square(
                                  dimension: 19,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(_sent ? 'تحقق وادخل' : 'إرسال رمز التحقق'),
                        ),
                        if (_sent || _cooldown > 0)
                          TextButton(
                            onPressed: _busy || _cooldown > 0 ? null : _send,
                            child: Text(_cooldown > 0
                                ? 'إعادة الإرسال بعد $_cooldown ثانية'
                                : 'إعادة إرسال الرمز'),
                          ),
                        const SizedBox(height: 14),
                        TextButton(
                          onPressed:
                              _busy ? null : () => context.go('/login-legacy'),
                          child: const Text('ربط أو استعادة حساب سابق'),
                        ),
                        FutureBuilder<bool>(
                          future: _savedDeletionReceipt,
                          builder: (context, snapshot) => snapshot.data == true
                              ? TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => Navigator.of(context).push(
                                            MaterialPageRoute<void>(
                                              builder: (_) =>
                                                  const DeleteAccountScreen(),
                                            ),
                                          ),
                                  child: const Text('متابعة طلب حذف الحساب'),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
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
