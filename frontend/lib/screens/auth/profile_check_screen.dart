import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A failed lookup is not evidence that an existing driver must register again.
class ProfileCheckScreen extends StatelessWidget {
  const ProfileCheckScreen({super.key});
  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
            body: SafeArea(
                child: Center(
                    child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_outlined,
                size: 48, color: Color(0xFF00296B)),
            const SizedBox(height: 20),
            const Text('تعذر التحقق من حسابك الآن',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 21, color: Color(0xFF00296B))),
            const SizedBox(height: 12),
            const Text(
                'تحقق من الاتصال ثم أعد المحاولة. لا تحتاج إلى إنشاء حساب جديد.',
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(
                onPressed: () => context.go('/splash'),
                child: const Text('إعادة المحاولة')),
          ]),
        )))),
      );
}
