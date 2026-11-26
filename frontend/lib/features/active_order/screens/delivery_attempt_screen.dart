import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../models/active_order_model.dart';
import '../services/delivery_attempt_service.dart';

class DeliveryAttemptScreen extends StatefulWidget {
  final ActiveOrder order;
  final DeliveryAttemptService? service;
  final Future<Map<String, dynamic>> Function()? locate;
  final Future<bool> Function(String)? call;
  final Duration Function()? elapsed;
  const DeliveryAttemptScreen(
      {super.key,
      required this.order,
      this.service,
      this.locate,
      this.call,
      this.elapsed});
  @override
  State<DeliveryAttemptScreen> createState() => _DeliveryAttemptScreenState();
}

class _DeliveryAttemptScreenState extends State<DeliveryAttemptScreen>
    with WidgetsBindingObserver {
  late final api = widget.service ?? DeliveryAttemptService();
  Map<String, dynamic>? record;
  String? error, pendingContact;
  bool busy = false;
  Timer? timer;
  final clock = Stopwatch();
  DateTime? serverTime;
  int ticks = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (++ticks % 15 == 0 &&
          !busy &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed)
        refresh();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    clock.stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !busy) refresh();
  }

  DateTime? get serverNow =>
      serverTime?.add(widget.elapsed?.call() ?? clock.elapsed);
  int remaining(String? field) {
    final at = DateTime.tryParse(field ?? '');
    final now = serverNow;
    if (at == null || now == null) return 0;
    return ((at.difference(now).inMilliseconds + 999) ~/ 1000).clamp(0, 86400);
  }

  Future<void> run(Future<Map<String, dynamic>> Function() operation) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final value = await operation();
      if (!mounted) return;
      setState(() {
        record = value;
        serverTime = DateTime.tryParse(value['serverNow'] ?? '');
        clock.reset();
        clock.start();
      });
    } catch (e) {
      if (mounted)
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> refresh() => run(
      () => api.send(widget.order.orderId, widget.order.financialAssignment!));
  Future<Map<String, dynamic>> locate() async {
    if (widget.locate != null) return widget.locate!();
    if (!await Geolocator.isLocationServiceEnabled())
      throw Exception('فعّل خدمة الموقع لبدء الانتظار');
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied)
      permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever)
      throw Exception(
          'اسمح بالوصول للموقع، أو تواصل مع الدعم إذا تعذر إثبات الوصول');
    final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)));
    return {
      'latitude': p.latitude,
      'longitude': p.longitude,
      'accuracyMeters': p.accuracy,
      'capturedAt': p.timestamp.toUtc().toIso8601String()
    };
  }

  Future<void> start() => run(() async => api.send(
      widget.order.orderId, widget.order.financialAssignment!,
      action: 'start', position: await locate()));
  Future<void> contact() => run(() async {
        if (pendingContact == null) {
          final phone = widget.order.customerPhone.trim();
          if (phone.isEmpty)
            throw Exception('رقم الزبون غير متاح؛ تواصل مع الدعم');
          final launched = await (widget.call?.call(phone) ??
              launchUrl(Uri(scheme: 'tel', path: phone)));
          if (!launched) throw Exception('تعذر فتح الاتصال؛ لم تُسجل محاولة');
          pendingContact = const Uuid().v4();
        }
        final result = await api.send(
            widget.order.orderId, widget.order.financialAssignment!,
            action: 'contact', eventId: pendingContact);
        pendingContact = null;
        return result;
      });
  @override
  Widget build(BuildContext context) {
    final started = record?['attemptId'] != null;
    final seconds = remaining(record?['deadlineAt']);
    final eligible = record?['noResponseEligible'] == true && error == null;
    final contactReady = started &&
        record?['state'] == 'WAITING' &&
        remaining(record?['nextContactAt']) == 0 &&
        (record?['contactCount'] ?? 0) <
            (record?['requiredContactAttempts'] ?? 0);
    return Scaffold(
        appBar: AppBar(title: const Text('توثيق محاولة التوصيل'), actions: [
          IconButton(
              onPressed: busy ? null : refresh, icon: const Icon(Icons.refresh))
        ]),
        body: Directionality(
            textDirection: TextDirection.rtl,
            child: ListView(padding: const EdgeInsets.all(20), children: [
              const Text(
                  'ابدأ الانتظار بعد الوصول إلى عنوان الزبون. يتحقق الخادم من قرب الموقع ودقته وحداثته.'),
              if (busy) const LinearProgressIndicator(),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
              if (record != null && !started)
                FilledButton(
                    onPressed: busy ? null : start,
                    child: const Text('تأكيد الوصول وبدء الانتظار')),
              if (started) ...[
                Text(
                    'الانتظار المتبقي: ${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}'),
                Text(
                    'محاولات التواصل: ${record!['contactCount']} من ${record!['requiredContactAttempts']}'),
                const Text(
                    'نسجّل بدء الاتصال، وليس تأكيد رد الزبون. لا تُكرر المحاولات دون مهلة.'),
                FilledButton(
                    onPressed: busy || (!contactReady && pendingContact == null)
                        ? null
                        : contact,
                    child: Text(pendingContact != null
                        ? 'إعادة تأكيد تسجيل المحاولة'
                        : 'الاتصال بالزبون وتسجيل المحاولة')),
                if (!contactReady && !eligible)
                  const Text(
                      'انتظر انتهاء المهلة واكتمال محاولات التواصل. التحديث تلقائي.'),
                FilledButton(
                    onPressed: busy || !eligible
                        ? null
                        : () => Navigator.pop(context, true),
                    child: const Text('متابعة إرجاع الطلب لعدم الرد')),
              ],
              const SizedBox(height: 16),
              const Text(
                  'إذا تعذر إثبات الموقع أو واجهت خطرًا، تواصل مع الدعم. لا يبدأ الإرجاع تلقائيًا ولا يُعتمد أي تعويض بمجرد انتهاء المؤقت.'),
            ])));
  }
}
