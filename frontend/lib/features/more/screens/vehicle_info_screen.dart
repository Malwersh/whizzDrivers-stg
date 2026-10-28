import '../../../services/driver_search_api_service.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../services/driver_vehicle_service.dart';
import '../../../services/document_upload_service.dart';
import '../../../widgets/file_upload_widget.dart';
import 'registration_details_widgets.dart';

const _navy = Color(0xFF00296B);
const _gold = Color(0xFFFDC500);

class VehicleInfoScreen extends StatefulWidget {
  const VehicleInfoScreen(
      {super.key, this.loadVehicles, this.perform, this.stopSearching});
  final Future<Map<String, dynamic>> Function()? loadVehicles;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>)? perform;
  final Future<Map<String, dynamic>> Function()? stopSearching;
  @override
  State<VehicleInfoScreen> createState() => _VehicleInfoScreenState();
}

class _VehicleInfoScreenState extends State<VehicleInfoScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true, _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var data =
          await (widget.loadVehicles?.call() ?? DriverVehicleService.request());
      final vehicles = (data['vehicles'] as List? ?? [])
          .where((v) => v['removedAt'] == null)
          .toList();
      if (data['activeId'] == null &&
          vehicles.length == 1 &&
          vehicles.single['effectiveStatus'] == 'APPROVED') {
        // Backfill an already reviewed sole vehicle through the versioned API.
        // The server independently checks the count and never changes a selection.
        try {
          final body = {
            'action': 'SELECT_DEFAULT',
            'expectedVersion': data['version']
          };
          data = await (widget.perform?.call(body) ??
              DriverVehicleService.request(body));
        } catch (_) {
          data = await (widget.loadVehicles?.call() ??
              DriverVehicleService.request());
        }
      }
      if (mounted) setState(() => _data = data);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر تحميل مركباتك. حاول مجددًا.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _notice(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  Future<void> _perform(String action,
      {Map<String, dynamic>? vehicle, String? vehicleId}) async {
    if (_busy || _data == null) return;
    setState(() => _busy = true);
    try {
      final body = {
        'action': action,
        'expectedVersion': _data!['version'],
        if (vehicle != null) 'vehicle': vehicle,
        if (vehicleId != null) 'vehicleId': vehicleId
      };
      final data = await (widget.perform?.call(body) ??
          DriverVehicleService.request(body));
      if (!mounted) return;
      setState(() => _data = data);
      _notice(action == 'SELECT'
          ? 'تم اختيار المركبة للعمل.'
          : action == 'REMOVE'
              ? 'أُزيلت المركبة من الاستخدام وحُفظ سجلها.'
              : 'أُرسلت البيانات للمراجعة.');
    } catch (e) {
      if (mounted)
        _notice(e is StateError
            ? e.message.toString()
            : 'تعذر إكمال العملية. حاول مجددًا.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stopForVehicleChange() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await (widget.stopSearching?.call() ??
          DriverSearchApiService.stopSearching());
      if (!mounted) return;
      _notice(result['success'] == true
          ? 'تم إيقاف استقبال الطلبات. يمكنك اختيار مركبة معتمدة الآن.'
          : result['message']?.toString() ??
              'تعذر الإيقاف. أكمل الطلب الجاري ثم حاول مجددًا.');
    } catch (_) {
      if (mounted) _notice('تعذر إيقاف استقبال الطلبات. حاول مجددًا.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _status(String? s) => switch (s) {
        'APPROVED' => 'معتمدة',
        'REJECTED' => 'تحتاج إلى تصحيح',
        'EXPIRED' => 'منتهية الصلاحية',
        'REMOVED' => 'مؤرشفة',
        _ => 'قيد المراجعة',
      };
  Future<void> _edit([Map<String, dynamic>? vehicle]) async {
    if (_busy) return;
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(builder: (_) => _VehicleEditor(vehicle: vehicle)));
    if (result != null && mounted)
      await _perform(vehicle == null ? 'ADD' : 'UPDATE', vehicle: result);
  }

  Future<void> _remove(Map<String, dynamic> vehicle) async {
    final yes = await showModalBottomSheet<bool>(
        context: context,
        builder: (context) => SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('إزالة المركبة',
                      style: TextStyle(
                          fontSize: 20,
                          color: _navy,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  const Text(
                      'ستتوقف هذه المركبة عن استقبال الطلبات، ويُحفظ سجل الرحلات السابقة. إذا كانت مركبتك الوحيدة، ستحتاج إلى اعتماد مركبة أخرى قبل العودة للعمل.',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(
                        child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                                foregroundColor: _navy,
                                side:
                                    const BorderSide(color: Color(0xFFCCD6E6))),
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('تراجع'))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: FilledButton(
                            style: FilledButton.styleFrom(
                                backgroundColor: _navy,
                                foregroundColor: Colors.white),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('إزالة المركبة')))
                  ]),
                ]))));
    if (yes == true && mounted)
      await _perform('REMOVE', vehicleId: vehicle['id']);
  }

  Future<void> _renewDocument(Map<String, dynamic> doc) async {
    final uploaded = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => _PersonalDocumentEditor(kind: doc['kind'])));
    if (uploaded == true && mounted) {
      await _load();
      if (mounted) _notice('رُفعت الوثيقة الجديدة وتحتاج إلى مراجعة الإدارة.');
    }
  }

  Widget _vehicle(Map<String, dynamic> v) {
    final active = v['id'] == _data!['activeId'],
        removed = v['effectiveStatus'] == 'REMOVED';
    final review = v['review'] as Map<String, dynamic>?;
    return RegistrationCard(
        title:
            '${registrationVehicleName(v['type'] ?? '')} · ${v['plateNumber']?.isNotEmpty == true ? v['plateNumber'] : 'اللوحة غير مسجلة'}',
        children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            Chip(
                label: Text(_status(v['effectiveStatus'])),
                backgroundColor: const Color(0xFFF0F3F8),
                side: BorderSide.none),
            if (active)
              const Chip(
                  label: Text('المختارة للعمل'),
                  backgroundColor: Color(0xFFFFF4C6),
                  side: BorderSide.none),
          ]),
          if ((v['make'] ?? '').toString().isNotEmpty)
            RegistrationField('المركبة', '${v['make']} ${v['model'] ?? ''}',
                Icons.directions_car_outlined),
          RegistrationField('سنوية المركبة', _status(v['effectiveStatus']),
              Icons.description_outlined),
          if (review?['reason'] != null)
            Text(review!['reason'],
                style: const TextStyle(color: Color(0xFF667085), height: 1.6)),
          if (review?['expiresAt'] != null)
            Text(
                'صالحة حتى ${DateTime.parse(review!['expiresAt']).toUtc().add(const Duration(hours: 3)).subtract(const Duration(days: 1)).toIso8601String().substring(0, 10)}',
                style: const TextStyle(color: Color(0xFF667085))),
          if (!removed)
            Wrap(spacing: 8, runSpacing: 4, children: [
              if (!active && v['effectiveStatus'] == 'APPROVED')
                TextButton(
                    style: TextButton.styleFrom(foregroundColor: _navy),
                    onPressed: _busy
                        ? null
                        : () => _perform('SELECT', vehicleId: v['id']),
                    child: const Text('استخدام للعمل')),
              TextButton(
                  style: TextButton.styleFrom(foregroundColor: _navy),
                  onPressed: _busy ? null : () => _edit(v),
                  child: const Text('تحديث البيانات والسنوية')),
              TextButton(
                  style: TextButton.styleFrom(foregroundColor: _navy),
                  onPressed: _busy ? null : () => _remove(v),
                  child: const Text('إزالة المركبة')),
            ]),
        ]);
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FA),
        appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            title: const Text('مركباتي'),
            foregroundColor: _navy),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!),
                    TextButton(
                        style: TextButton.styleFrom(foregroundColor: _navy),
                        onPressed: _load,
                        child: const Text('إعادة المحاولة')),
                  ]))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                        padding: const EdgeInsets.all(20),
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          if (_busy)
                            const LinearProgressIndicator(color: _navy),
                          RegistrationCard(
                              title: 'المركبة المستخدمة للعمل',
                              children: [
                                Text(
                                    _data!['eligibility']?['eligible'] == true
                                        ? 'مركبتك ووثائقك معتمدة للعمل.'
                                        : DriverVehicleService.message(
                                            _data!['eligibility']?['code'] ??
                                                ''),
                                    style: const TextStyle(
                                        color: _navy, height: 1.7)),
                                const SizedBox(height: 10),
                                const Text(
                                    'يمكنك إضافة أكثر من مركبة واختيار مركبة معتمدة واحدة للعمل. أوقف استقبال الطلبات وأكمل طلبك الجاري قبل التبديل.',
                                    style: TextStyle(
                                        color: Color(0xFF667085), height: 1.6)),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                      foregroundColor: _navy,
                                      side: const BorderSide(
                                          color: Color(0xFFCCD6E6))),
                                  onPressed:
                                      _busy ? null : _stopForVehicleChange,
                                  icon:
                                      const Icon(Icons.pause_rounded, size: 18),
                                  label: const Text(
                                      'إيقاف استقبال الطلبات للتبديل'),
                                ),
                              ]),
                          SizedBox(
                              height: 48,
                              child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                      backgroundColor: _gold,
                                      foregroundColor: _navy),
                                  onPressed: _busy ? null : () => _edit(),
                                  icon: const Icon(Icons.add),
                                  label: const Text('إضافة مركبة'))),
                          const SizedBox(height: 16),
                          for (final v in (_data!['vehicles'] as List)
                              .cast<Map<String, dynamic>>()
                              .where((v) => v['effectiveStatus'] != 'REMOVED'))
                            _vehicle(v),
                          RegistrationCard(title: 'وثائق السائق', children: [
                            for (final doc in (_data!['documents'] as List)
                                .cast<Map<String, dynamic>>())
                              ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(doc['kind'] == 'nationalId'
                                      ? 'البطاقة الوطنية'
                                      : 'إجازة السوق / رخصة القيادة'),
                                  subtitle: Text(doc['uploaded'] == true
                                      ? _status(doc['status'])
                                      : 'لم تُرفع الوثيقة'),
                                  trailing: TextButton(
                                      style: TextButton.styleFrom(
                                          foregroundColor: _navy),
                                      onPressed: _busy
                                          ? null
                                          : () => _renewDocument(doc),
                                      child: const Text('تحديث'))),
                          ]),
                          if ((_data!['vehicles'] as List)
                              .any((v) => v['effectiveStatus'] == 'REMOVED'))
                            ExpansionTile(
                                title: const Text('المركبات المؤرشفة'),
                                children: [
                                  for (final v in (_data!['vehicles'] as List)
                                      .cast<Map<String, dynamic>>()
                                      .where((v) =>
                                          v['effectiveStatus'] == 'REMOVED'))
                                    _vehicle(v),
                                ]),
                        ])),
      ));
}

class _VehicleEditor extends StatefulWidget {
  const _VehicleEditor({this.vehicle});
  final Map<String, dynamic>? vehicle;
  @override
  State<_VehicleEditor> createState() => _VehicleEditorState();
}

class _VehicleEditorState extends State<_VehicleEditor> {
  final _form = GlobalKey<FormState>();
  late final String _id = widget.vehicle?['id'] ?? const Uuid().v4();
  late final _plate =
      TextEditingController(text: widget.vehicle?['plateNumber'] ?? '');
  late final _make = TextEditingController(text: widget.vehicle?['make'] ?? '');
  late final _model =
      TextEditingController(text: widget.vehicle?['model'] ?? '');
  late final _color =
      TextEditingController(text: widget.vehicle?['color'] ?? '');
  late String _type = widget.vehicle?['type'] == 'car' ? 'car' : 'motorcycle';
  Map<String, dynamic>? _file;
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _plate.dispose();
    _make.dispose();
    _model.dispose();
    _color.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (_file == null) {
      setState(() => _error = 'أرفق صورة سنوية المركبة.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await DocumentUploadService().uploadDocumentFromData(
          fileName: _file!['name'],
          contentType: _file!['type'],
          base64Content: _file!['content'],
          documentType: 'registration_paper',
          phoneNumber: '',
          vehicleId: _id);
      if (r['success'] != true || r['documentUrl'] is! String)
        throw StateError(r['message'] ?? 'تعذر رفع السنوية');
      if (mounted)
        Navigator.pop(context, <String, dynamic>{
          'id': _id,
          'type': _type,
          'plateNumber': _plate.text.trim(),
          'make': _make.text.trim(),
          'model': _model.text.trim(),
          'color': _color.text.trim(),
          'registrationUrl': r['documentUrl']
        });
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر رفع الوثيقة. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            title:
                Text(widget.vehicle == null ? 'إضافة مركبة' : 'تحديث المركبة'),
            foregroundColor: _navy),
        body: AbsorbPointer(
            absorbing: _busy,
            child: Form(
                key: _form,
                child: ListView(padding: const EdgeInsets.all(20), children: [
                  const Text(
                      'تحتاج المركبة والسنوية إلى مراجعة الإدارة قبل استخدامها للعمل.',
                      style: TextStyle(color: _navy, height: 1.7)),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                      initialValue: _type,
                      decoration:
                          const InputDecoration(labelText: 'نوع المركبة'),
                      items: const [
                        DropdownMenuItem(value: 'car', child: Text('سيارة')),
                        DropdownMenuItem(
                            value: 'motorcycle', child: Text('دراجة نارية'))
                      ],
                      onChanged: (v) => setState(() => _type = v!)),
                  TextFormField(
                      controller: _plate,
                      maxLength: 40,
                      decoration:
                          const InputDecoration(labelText: 'رقم لوحة المركبة'),
                      validator: (s) => s == null || s.trim().isEmpty
                          ? 'أدخل رقم اللوحة'
                          : null),
                  TextFormField(
                      controller: _make,
                      maxLength: 80,
                      decoration: const InputDecoration(
                          labelText: 'الشركة المصنّعة (اختياري)')),
                  TextFormField(
                      controller: _model,
                      maxLength: 80,
                      decoration:
                          const InputDecoration(labelText: 'الطراز (اختياري)')),
                  TextFormField(
                      controller: _color,
                      maxLength: 80,
                      decoration:
                          const InputDecoration(labelText: 'اللون (اختياري)')),
                  const SizedBox(height: 16),
                  FileUploadWidget(
                      label: 'سنوية المركبة',
                      compact: true,
                      isRequired: true,
                      allowedExtensions: const ['jpg', 'jpeg', 'png', 'heic'],
                      maxSizeMB: 4,
                      onFileSelected: (f) => setState(() => _file = f),
                      onFileRemoved: () => setState(() => _file = null)),
                  if (_error != null)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(_error!,
                            style: const TextStyle(color: Colors.red))),
                  const SizedBox(height: 20),
                  FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: _navy,
                          foregroundColor: Colors.white),
                      onPressed: _busy ? null : _save,
                      child: Text(_busy ? 'جارٍ الرفع…' : 'إرسال للمراجعة')),
                ]))),
      ));
}

class _PersonalDocumentEditor extends StatefulWidget {
  const _PersonalDocumentEditor({required this.kind});
  final String kind;
  @override
  State<_PersonalDocumentEditor> createState() =>
      _PersonalDocumentEditorState();
}

class _PersonalDocumentEditorState extends State<_PersonalDocumentEditor> {
  Map<String, dynamic>? _file;
  bool _busy = false;
  String? _error;
  Future<void> _save() async {
    if (_busy || _file == null) return;
    setState(() => _busy = true);
    try {
      final r = await DocumentUploadService().uploadDocumentFromData(
          fileName: _file!['name'],
          contentType: _file!['type'],
          base64Content: _file!['content'],
          documentType:
              widget.kind == 'nationalId' ? 'national_id' : 'driving_license',
          phoneNumber: '');
      if (r['success'] != true) throw StateError('upload');
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر رفع الوثيقة. حاول مجددًا.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
          appBar: AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              scrolledUnderElevation: 0,
              title: const Text('تحديث الوثيقة'),
              foregroundColor: _navy),
          body: ListView(padding: const EdgeInsets.all(20), children: [
            const Text(
                'استبدال الوثيقة يتطلب مراجعتها مجددًا، وقد يتوقف استقبال الطلبات حتى اعتمادها. يمكنك إكمال الطلب الجاري.',
                style: TextStyle(height: 1.7, color: _navy)),
            const SizedBox(height: 20),
            AbsorbPointer(
                absorbing: _busy,
                child: FileUploadWidget(
                    label: widget.kind == 'nationalId'
                        ? 'البطاقة الوطنية'
                        : 'إجازة السوق / رخصة القيادة',
                    compact: true,
                    isRequired: true,
                    allowedExtensions: const ['jpg', 'jpeg', 'png', 'heic'],
                    maxSizeMB: 4,
                    onFileSelected: (f) => setState(() => _file = f),
                    onFileRemoved: () => setState(() => _file = null))),
            if (_error != null) Text(_error!),
            const SizedBox(height: 20),
            FilledButton(
                onPressed: _busy || _file == null ? null : _save,
                style: FilledButton.styleFrom(
                    backgroundColor: _navy, foregroundColor: Colors.white),
                child: Text(_busy ? 'جارٍ الرفع…' : 'إرسال للمراجعة')),
          ])));
}
