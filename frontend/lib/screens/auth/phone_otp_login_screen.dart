import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/driver_auth_provider.dart' as driver_auth;
import '../../services/phone_otp_auth_service.dart';
import '../../utils/iraqi_phone.dart';
import '../../services/profile_completion_service.dart';

/// Staging pilot. The existing login stays available until migration is complete.
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
        final profile =
            await ProfileCompletionService().checkProfileCompleteness();
        if (!mounted) return;
        final status = profile.profileData?['status']?.toString().toUpperCase();
        final target = profile.needsRedirect
            ? (profile.redirectPath ?? '/driver-profile-setup')
            : ['BANNED', 'SUSPENDED', 'REJECTED'].contains(status)
                ? '/account-status?status=$status'
                : profile.profileData?['isVerified'] != true
                    ? '/pending-review'
                    : '/';
        context.go(target, extra: {'phone': _auth.phone});
      } else {
        setState(() => _message = 'الرمز غير صحيح. حاول مجددًا.');
      }
    } on PhoneAuthException catch (e) {
      if (mounted) setState(() => _message = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _message =
            'تعذر التحقق. قد يكون الرمز منتهيًا؛ اطلب رمزًا جديدًا.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(title: const Text('مرحبًا بك في WizzDriver')),
          body: SafeArea(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('أدخل رقم هاتفك العراقي لإرسال رمز التحقق.'),
                      const SizedBox(height: 24),
                      TextField(
                          controller: _phone,
                          enabled: !_sent && !_busy,
                          keyboardType: TextInputType.phone,
                          textDirection: TextDirection.ltr,
                          autofillHints: const [AutofillHints.telephoneNumber],
                          decoration: const InputDecoration(
                              labelText: 'رقم الهاتف',
                              hintText: '077XXXXXXXX',
                              prefixText: '+964  ',
                              helperText: 'أرقام المحمول العراقية فقط')),
                      const SizedBox(height: 16),
                      if (_sent) ...[
                        TextField(
                            controller: _code,
                            enabled: !_busy,
                            keyboardType: TextInputType.number,
                            textDirection: TextDirection.ltr,
                            maxLength: 6,
                            autofillHints: const [AutofillHints.oneTimeCode],
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            decoration:
                                const InputDecoration(labelText: 'رمز التحقق')),
                        FilledButton(
                            onPressed: _busy ? null : _verify,
                            child: const Text('تحقق وادخل')),
                        TextButton(
                            onPressed: _busy || _cooldown > 0 ? null : _send,
                            child: Text(_cooldown > 0
                                ? 'إعادة الإرسال بعد $_cooldown ثانية'
                                : 'إعادة إرسال الرمز')),
                        TextButton(
                            onPressed: _busy
                                ? null
                                : () => setState(() {
                                      _sent = false;
                                      _message = null;
                                      _code.clear();
                                    }),
                            child: const Text('تغيير الرقم')),
                      ] else
                        FilledButton(
                            onPressed: _busy || _cooldown > 0 ? null : _send,
                            child: const Text('إرسال رمز التحقق')),
                      TextButton(
                          onPressed:
                              _busy ? null : () => context.go('/login-legacy'),
                          child: const Text('ربط أو استعادة حساب سابق')),
                      if (_busy)
                        const Center(child: CircularProgressIndicator()),
                      if (_message != null)
                        Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(_message!,
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.error))),
                    ],
                  ))),
        ),
      );
}
