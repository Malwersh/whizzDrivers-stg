import 'package:flutter/material.dart';
import 'application_legal_bundle.dart';
import 'application_legal_service.dart';
import 'application_legal_screen.dart';

class ApplicationLegalConsent extends StatefulWidget {
  final ValueChanged<ApplicationLegalBundle?> onChanged;
  final ApplicationLegalService? service;
  final bool enabled;
  const ApplicationLegalConsent(
      {super.key, required this.onChanged, this.service, this.enabled = true});
  @override
  State<ApplicationLegalConsent> createState() =>
      _ApplicationLegalConsentState();
}

class _ApplicationLegalConsentState extends State<ApplicationLegalConsent> {
  ApplicationLegalBundle? bundle;
  bool checked = false, busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      checked = false;
      bundle = null;
      error = null;
    });
    try {
      final b = await (widget.service ?? ApplicationLegalService.instance)
          .load(refresh: true);
      if (mounted) setState(() => bundle = b);
    } catch (_) {
      if (mounted)
        setState(() => error = 'تعذر تحميل السياسات المنشورة. أعد المحاولة.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (busy) const LinearProgressIndicator(color: Color(0xFF00296B)),
        if (error != null)
          Text(error!, style: const TextStyle(color: Color(0xFF00296B))),
        if (error != null)
          TextButton(
              onPressed: () {
                widget.onChanged(null);
                load();
              },
              child: const Text('إعادة تحميل السياسات',
                  style: TextStyle(color: Color(0xFF00296B)))),
        CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: checked,
            activeColor: const Color(0xFF00296B),
            onChanged: widget.enabled && bundle != null
                ? (v) {
                    setState(() => checked = v ?? false);
                    widget.onChanged(checked ? bundle : null);
                  }
                : null,
            title: const Text(
                'أوافق على سياسة الاستخدام والشروط والأحكام، وأقر باطلاعي على سياسة الخصوصية وسياسة الإلغاء والإرجاع.',
                style: TextStyle(
                    fontSize: 14, height: 1.6, color: Color(0xFF00296B)))),
        if (bundle != null)
          Wrap(children: [
            for (final d in bundle!.documents)
              TextButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ApplicationLegalScreen(
                              documentId: d['id'], bundle: bundle))),
                  child: Text(d['title'],
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF00296B))))
          ]),
      ]);
}
