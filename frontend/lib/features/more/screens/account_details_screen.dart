import 'package:flutter/material.dart';
import '../../../models/driver_profile.dart';
import '../../../services/driver_service.dart';
import 'delete_account_screen.dart';
import 'driver_performance_screen.dart';

class AccountDetailsScreen extends StatefulWidget {
  final Future<DriverProfile?> Function()? loadProfile;
  final Future<bool> Function(DriverProfile)? saveProfile;
  const AccountDetailsScreen({super.key, this.loadProfile, this.saveProfile});
  @override
  State<AccountDetailsScreen> createState() => _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends State<AccountDetailsScreen> {
  static const navy = Color(0xFF00296B);
  DriverProfile? _profile;
  bool _loading = true, _saving = false, _editing = false;
  final _name = TextEditingController(), _city = TextEditingController();
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    DriverProfile? result;
    try {
      result = await (widget.loadProfile?.call() ??
          DriverService.getDriverProfile());
    } catch (_) {/* Show retry below. */}
    if (!mounted) return;
    setState(() {
      _profile = result;
      _loading = false;
      _reset();
    });
  }

  void _reset() {
    _name.text = _profile?.name ?? '';
    _city.text = _profile?.city ?? '';
  }

  Future<void> _save() async {
    if (_saving || _profile == null) return;
    if (_name.text.trim().isEmpty || _city.text.trim().isEmpty) {
      _notice('أدخل الاسم والمدينة قبل الحفظ.');
      return;
    }
    setState(() => _saving = true);
    final updated =
        _profile!.copyWith(name: _name.text.trim(), city: _city.text.trim());
    bool ok = false;
    try {
      ok = await (widget.saveProfile?.call(updated) ??
          DriverService.updateDriverProfile(updated, accountBasicsOnly: true));
    } catch (_) {/* Keep edit state. */}
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) _editing = false;
    });
    if (ok) {
      await _load();
      if (mounted) _notice('تم الحفظ وإعادة تحميل بيانات الحساب.');
    } else {
      _notice('تعذر حفظ التعديلات. حاول مرة أخرى.');
    }
  }

  void _notice(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));
  String _value(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ||
            ['pending', 'null', 'undefined', 'n/a'].contains(text.toLowerCase())
        ? 'غير مسجل'
        : text;
  }

  String _status(String? value) => switch (value?.toUpperCase()) {
        'APPROVED' || 'ACTIVE' => 'معتمد',
        'SUSPENDED' || 'BLOCKED' => 'موقوف',
        'REJECTED' => 'غير معتمد',
        'PENDING' || 'PENDING_PROFILE' || 'PENDING_REVIEW' => 'قيد المراجعة',
        _ => 'غير محدد',
      };
  Widget _section(String title, List<Widget> children) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: navy)),
          const SizedBox(height: 16),
          ...children,
        ]),
      );
  Widget _field(String label, String? value, IconData icon,
          {bool ltr = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: navy, size: 21),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF667085))),
                const SizedBox(height: 5),
                Text(_value(value),
                    textDirection: ltr ? TextDirection.ltr : TextDirection.rtl,
                    style: const TextStyle(
                        fontSize: 16, color: Color(0xFF182230))),
              ])),
        ]),
      );
  Widget _editField(String label, TextEditingController controller) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
            controller: controller,
            enabled: !_saving,
            maxLength: label == 'الاسم الكامل' ? 100 : 80,
            decoration: InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
                counterText: '')),
      );
  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FA),
        appBar: AppBar(
            title: const Text('الملف الشخصي'),
            backgroundColor: Colors.white,
            foregroundColor: navy,
            actions: [
              if (_profile != null && !_loading)
                TextButton(
                    onPressed: _saving
                        ? null
                        : () {
                            setState(() {
                              _editing = !_editing;
                              _reset();
                            });
                          },
                    child: Text(_editing ? 'إلغاء' : 'تعديل'))
            ]),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _profile == null
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('تعذر تحميل الملف الشخصي'),
                    TextButton(
                        onPressed: _load, child: const Text('إعادة المحاولة'))
                  ]))
                : RefreshIndicator(
                    onRefresh: _editing ? () async {} : _load,
                    child:
                        ListView(padding: const EdgeInsets.all(20), children: [
                      _section('بيانات السائق', [
                        _field('الاسم', _profile!.name, Icons.person_outline),
                        const SizedBox(height: 12),
                        const Text('تقييم الزبائن · كامل السجل',
                            style: TextStyle(
                                fontSize: 13, color: Color(0xFF667085))),
                        const SizedBox(height: 8),
                        if (_profile!.customerRatingCount > 0) ...[
                          Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 0, vertical: 4),
                                    child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.star_rounded,
                                              color: Color(0xFFB77900),
                                              size: 19),
                                          const SizedBox(width: 6),
                                          Text(
                                              _profile!.rating
                                                  .toStringAsFixed(1),
                                              textDirection: TextDirection.ltr,
                                              style: const TextStyle(
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.w700,
                                                  color: navy)),
                                          const SizedBox(width: 5),
                                          const Text('/ 5',
                                              textDirection: TextDirection.ltr,
                                              style: TextStyle(
                                                  color: Color(0xFF667085))),
                                        ])),
                                Text(
                                    'عدد التقييمات: ${_profile!.customerRatingCount}',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF667085))),
                              ]),
                        ] else
                          const Text('—', semanticsLabel: 'لا توجد تقييمات زبائن موثقة بعد'),
                        ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('أدائي وتفاصيل التقييم'),
                            trailing:
                                const Icon(Icons.chevron_left, color: navy),
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                    builder: (_) =>
                                        const DriverPerformanceScreen()))),
                      ]),
                      _section('المعلومات الشخصية', [
                        if (_editing) ...[
                          _editField('الاسم الكامل', _name),
                          _editField('المدينة', _city)
                        ] else ...[
                          _field('الاسم الكامل', _profile!.name,
                              Icons.person_outline),
                          _field('المدينة', _profile!.city,
                              Icons.location_city_outlined)
                        ],
                        _field(
                            'رقم الهاتف', _profile!.phone, Icons.phone_outlined,
                            ltr: true),
                        _field('البريد الإلكتروني', _profile!.email,
                            Icons.email_outlined,
                            ltr: true),
                        if (_editing) ...[
                          const Text(
                              'تعديل رقم الهاتف والبريد والصورة غير متاح من هذه الصفحة حاليًا.',
                              style: TextStyle(
                                  color: Color(0xFF667085), height: 1.6)),
                          const SizedBox(height: 16),
                          FilledButton(
                              onPressed: _saving ? null : _save,
                              style: FilledButton.styleFrom(
                                  backgroundColor: navy,
                                  foregroundColor: Colors.white),
                              child: Text(
                                  _saving ? 'جارٍ الحفظ…' : 'حفظ التعديلات')),
                        ],
                      ]),
                      _section('الحساب والوثائق', [
                        _field('حالة الحساب', _status(_profile!.status),
                            Icons.account_circle_outlined),
                        _field(
                            'التحقق من الوثائق',
                            _profile!.documentsVerified == true
                                ? 'موثقة'
                                : _profile!.documentsVerified == false
                                    ? 'لم يكتمل التحقق'
                                    : 'لا تتوفر نتيجة تحقق موثقة',
                            Icons.verified_user_outlined),
                        _field('رقم الهوية', _profile!.nationalId,
                            Icons.badge_outlined),
                        _field('رقم إجازة السوق', _profile!.licenseNumber,
                            Icons.credit_card_outlined),
                        _field('صلاحية إجازة السوق', _profile!.licenseExpiry,
                            Icons.event_outlined),
                        if (_profile!.createdAt != null)
                          _field(
                              'تاريخ الانضمام',
                              '${_profile!.createdAt!.day}/${_profile!.createdAt!.month}/${_profile!.createdAt!.year}',
                              Icons.calendar_month_outlined),
                        const Text(
                            'اعتماد الحساب لا يعني تأكيد صلاحية جميع الوثائق.',
                            style: TextStyle(
                                color: Color(0xFF667085), height: 1.6)),
                      ]),
                      _section('إدارة الحساب', [
                        ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            title: const Text('طلب حذف الحساب'),
                            trailing: const Icon(Icons.chevron_left),
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                    builder: (_) =>
                                        const DeleteAccountScreen()))),
                      ]),
                    ])),
      ));
}
