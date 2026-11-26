import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class DriverLocationAccess {
  const DriverLocationAccess(
      {required this.serviceEnabled, required this.permission});
  final bool serviceEnabled;
  final LocationPermission permission;
  bool get ready => serviceEnabled && permission == LocationPermission.always;
  static Future<DriverLocationAccess> read() async => DriverLocationAccess(
        serviceEnabled: await Geolocator.isLocationServiceEnabled(),
        permission: await Geolocator.checkPermission(),
      );
}

/// Reads real device permission, independently of map position/test coordinates.
/// It requests no permission and does not change availability or dispatch priority.
class LocationPermissionNotice extends StatefulWidget {
  const LocationPermissionNotice(
      {super.key,
      this.readAccess,
      this.openAppSettings,
      this.openLocationSettings});
  final Future<DriverLocationAccess> Function()? readAccess;
  final Future<bool> Function()? openAppSettings;
  final Future<bool> Function()? openLocationSettings;
  @override
  State<LocationPermissionNotice> createState() =>
      _LocationPermissionNoticeState();
}

class _LocationPermissionNoticeState extends State<LocationPermissionNotice>
    with WidgetsBindingObserver {
  DriverLocationAccess? _access;
  bool _error = false, _opening = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final generation = ++_generation;
    try {
      final access =
          await (widget.readAccess?.call() ?? DriverLocationAccess.read());
      if (!mounted || generation != _generation) return;
      setState(() {
        _access = access;
        _error = false;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = true;
          _access = null;
        });
      }
    }
  }

  Future<void> _openSettings() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final opened = _access?.serviceEnabled == false
          ? await (widget.openLocationSettings?.call() ??
              Geolocator.openLocationSettings())
          : await (widget.openAppSettings?.call() ??
              Geolocator.openAppSettings());
      if (!mounted) return;
      if (!opened) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'تعذر فتح الإعدادات. يمكنك فتحها يدويًا من إعدادات الهاتف.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تعذر فتح إعدادات الموقع. حاول مجددًا.')));
      }
    } finally {
      if (mounted) {
        setState(() => _opening = false);
        _refresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_error && (_access == null || _access!.ready)) {
      return const SizedBox.shrink();
    }
    final disabled = _access?.serviceEnabled == false;
    final needsRetry = _error ||
        (!disabled &&
            _access?.permission == LocationPermission.unableToDetermine);
    final foreground = _access?.permission == LocationPermission.whileInUse;
    final title = needsRetry
        ? 'تعذر فحص صلاحيات الموقع'
        : disabled
            ? 'خدمات الموقع متوقفة'
            : foreground
                ? 'الموقع متاح أثناء استخدام التطبيق'
                : 'السماح بالوصول إلى الموقع';
    final description = needsRetry
        ? 'أعد التحقق من حالة الموقع على هاتفك.'
        : disabled
            ? 'فعّل خدمات الموقع من إعدادات الهاتف ليتمكن التطبيق من تحديث موقعك.'
            : foreground
                ? 'للسماح بتحديث موقعك أثناء قفل الشاشة أو استخدام تطبيق آخر، اختر «دائمًا» أو «السماح طوال الوقت» من صلاحيات الموقع في إعدادات التطبيق.'
                : 'اسمح للتطبيق باستخدام الموقع من إعدادات الهاتف. صلاحية الموقع تساعد على تحديث موقعك أثناء توفرّك للعمل.';
    const navy = Color(0xFF00296B);
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD6DEEB))),
      child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _opening
                ? null
                : needsRetry
                    ? _refresh
                    : _openSettings,
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                              color: const Color(0xFFF0F4FA),
                              borderRadius: BorderRadius.circular(10)),
                          child: Icon(
                              disabled
                                  ? Icons.location_off_outlined
                                  : Icons.location_on_outlined,
                              color: navy,
                              size: 22)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                            Text(title,
                                style: const TextStyle(
                                    color: navy,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Text(description,
                                style: const TextStyle(
                                    color: Color(0xFF475467),
                                    fontSize: 12,
                                    height: 1.7)),
                            const SizedBox(height: 10),
                            Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(
                                    _opening
                                        ? 'جارٍ فتح الإعدادات…'
                                        : needsRetry
                                            ? 'إعادة التحقق'
                                            : disabled
                                                ? 'فتح إعدادات الموقع'
                                                : 'فتح إعدادات التطبيق',
                                    style: const TextStyle(
                                        color: navy,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700))),
                          ])),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_left_rounded,
                          textDirection: TextDirection.ltr,
                          color: navy,
                          size: 18),
                    ])),
          )),
    );
  }
}
