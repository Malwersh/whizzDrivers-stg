import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app_colors.dart';

class OutsideCoverageSheet extends StatefulWidget {
  const OutsideCoverageSheet(
      {super.key,
      required this.latitude,
      required this.longitude,
      required this.onRefresh});
  final double latitude, longitude;
  final VoidCallback onRefresh;
  @override
  State<OutsideCoverageSheet> createState() => _OutsideCoverageSheetState();
}

class _OutsideCoverageSheetState extends State<OutsideCoverageSheet> {
  String? _location;
  @override
  void initState() {
    super.initState();
    _describe();
  }

  Future<void> _describe() async {
    try {
      final label = await const MethodChannel('com.whizz.driver/location_label')
          .invokeMethod<String>('describe', {
        'latitude': widget.latitude,
        'longitude': widget.longitude
      }).timeout(const Duration(seconds: 4));
      if (mounted) setState(() => _location = label);
    } catch (_) {
      /* Coordinates remain available if place names are unavailable. */
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(8))),
                  const SizedBox(height: 22),
                  const CircleAvatar(
                      radius: 30,
                      backgroundColor: Color(0xFFF0F4FA),
                      child: Icon(Icons.location_off_outlined,
                          size: 30, color: AppColors.secondary)),
                  const SizedBox(height: 16),
                  const Text('أنت خارج مناطق الخدمة حاليًا',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondary)),
                  const SizedBox(height: 12),
                  const Text(
                      'عذرًا، استقبال الطلبات غير متاح من موقعك الحالي. يمكنك متابعة حسابك ومحفظتك، والعودة للبحث عندما تكون داخل منطقة مخدومة.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 14, height: 1.7, color: Color(0xFF526078))),
                  const SizedBox(height: 18),
                  Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: const Color(0xFFF5F7FB),
                          borderRadius: BorderRadius.circular(14)),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('موقعك الحالي',
                                style: TextStyle(
                                    fontSize: 12, color: Color(0xFF526078))),
                            if (_location != null)
                              Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(_location!,
                                      style: const TextStyle(
                                          color: AppColors.secondary,
                                          fontSize: 15))),
                            const SizedBox(height: 6),
                            Text(
                                '${widget.latitude.toStringAsFixed(5)}, ${widget.longitude.toStringAsFixed(5)}',
                                textDirection: TextDirection.ltr,
                                style: const TextStyle(
                                    color: Color(0xFF526078), fontSize: 12)),
                          ])),
                  const SizedBox(height: 20),
                  SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.secondary,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14))),
                          onPressed: widget.onRefresh,
                          child: const Text('تحديث موقعي'))),
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.secondary),
                      child: const Text('حسنًا')),
                ]),
              )),
        ),
      );
}
