import 'package:flutter/material.dart';
import '../../../services/driver_offer_audio.dart';

Future<void> showOfferSoundTestSheet(BuildContext context) =>
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const OfferSoundTestSheet());

class OfferSoundTestSheet extends StatefulWidget {
  final Future<Map<String, dynamic>> Function()? play;
  const OfferSoundTestSheet({super.key, this.play});
  @override
  State<OfferSoundTestSheet> createState() => _OfferSoundTestSheetState();
}

class _OfferSoundTestSheetState extends State<OfferSoundTestSheet> {
  bool _busy = false;
  String? _message;
  Future<void> _play() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    Map<String, dynamic> result;
    try {
      result = await (widget.play ?? DriverOfferAudio.preview)();
    } catch (_) {
      result = {'playing': false};
    }
    if (!mounted) return;
    final volume = result['volume'];
    setState(() {
      _busy = false;
      _message = result['silent'] == true
          ? 'صوت العروض مكتوم من إعدادات المنصة.'
          : volume is num && volume <= 0.01
              ? 'مستوى صوت الوسائط منخفض جدًا. ارفعه بأزرار الصوت ثم أعد الاختبار.'
              : result['playing'] == true
                  ? 'تم تشغيل صوت العرض. إذا لم تسمعه، تحقّق من مستوى الصوت والسماعات المتصلة.'
                  : 'تعذر تشغيل الصوت. أعد المحاولة أو تواصل مع الدعم.';
    });
  }

  @override
  Widget build(BuildContext context) => SafeArea(
          child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.volume_up_outlined,
              color: Color(0xFF00296B), size: 30),
          const SizedBox(height: 12),
          const Text('اختبار صوت العروض',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF00296B))),
          const SizedBox(height: 12),
          const Text(
              'يُشغّل الصوت نفسه المستخدم عند وصول عرض جديد، دون إنشاء طلب أو التأثير على أدائك.',
              textAlign: TextAlign.center),
          if (_message != null)
            Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_message!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Color(0xFF00296B), height: 1.5))),
          const SizedBox(height: 20),
          SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _play,
                icon: Icon(_busy ? Icons.hourglass_empty : Icons.play_arrow),
                label: Text(_busy ? 'جارٍ التشغيل…' : 'تشغيل الصوت'),
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFDC500),
                    foregroundColor: const Color(0xFF00296B),
                    padding: const EdgeInsets.symmetric(vertical: 13)),
              )),
        ]),
      ));
}
