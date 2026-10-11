import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import '../../../config/environment.dart';
import '../../../app_colors.dart';
import '../../../services/cognito_token_service.dart';
import '../../../services/document_upload_service.dart';
import '../../../widgets/file_upload_widget.dart';

class DriverProfileSetupScreen extends ConsumerStatefulWidget {
  final String phoneNumber;
  const DriverProfileSetupScreen({super.key, required this.phoneNumber});
  @override
  ConsumerState<DriverProfileSetupScreen> createState() =>
      _DriverProfileSetupScreenState();
}

class _DriverProfileSetupScreenState
    extends ConsumerState<DriverProfileSetupScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _landmark = TextEditingController();
  final _files = <String, Map<String, dynamic>>{};
  final _urls = <String, String>{};
  Map<String, dynamic>? _options;
  String? _governorate, _region, _error, _vehicleType;
  bool _loading = true, _saving = false;
  static const _documents = {
    'registration_paper': 'سنوية السيارة',
    'driving_license': 'إجازة السوق / رخصة القيادة',
    'national_id': 'البطاقة الوطنية'
  };
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _landmark.dispose();
    super.dispose();
  }

  Future<Map<String, String>> _headers() async {
    final token = await CognitoTokenService.getAccessToken();
    if (token == null) throw StateError('انتهت جلسة الدخول');
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json'
    };
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await http
          .get(
              Uri.parse(
                  '${Environment.apiBaseUrl}/driver/registration-options'),
              headers: await _headers())
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) throw StateError('فشل تحميل مناطق العمل');
      final options = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() => _options = options);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذر تحميل مناطق العمل. أعد المحاولة.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_saving || !_form.currentState!.validate()) return;
    if (_documents.keys.any((type) => !_files.containsKey(type))) {
      setState(() => _error = 'أرفق صور الوثائق الثلاث لإرسال طلبك');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      for (final type in _documents.keys) {
        if (_urls.containsKey(type)) continue;
        final file = _files[type]!;
        final result = await DocumentUploadService().uploadDocumentFromData(
            fileName: file['name'] as String,
            contentType: file['type'] as String,
            base64Content: file['content'] as String,
            documentType: type,
            phoneNumber: widget.phoneNumber);
        if (result['success'] != true || result['documentUrl'] is! String) {
          throw StateError('فشل رفع ${_documents[type]}');
        }
        _urls[type] = result['documentUrl'] as String;
      }
      final response = await http
          .put(Uri.parse('${Environment.apiBaseUrl}/driver/me'),
              headers: await _headers(),
              body: jsonEncode({
                'profileSchemaVersion': 2,
                'name': _name.text.trim(),
                'vehicleType': _vehicleType,
                'governorate_id': _governorate,
                'work_region_id': _region,
                'home_address_text': _landmark.text.trim(),
                'registrationPaperUrl': _urls['registration_paper'],
                'drivingLicenseUrl': _urls['driving_license'],
                'nationalIdUrl': _urls['national_id'],
              }))
          .timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) {
        throw StateError(
            'تعذر حفظ الملف. تأكد من أن منطقة العمل ما زالت مفتوحة.');
      }
      if (mounted) context.go('/pending-review');
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is StateError
            ? error.message.toString()
            : 'تعذر إرسال الطلب. حاول مجددًا.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final governors = (_options?['governorates'] as List?) ?? [];
    final regions = ((_options?['regions'] as List?) ?? [])
        .where((r) => r['governorateId'] == _governorate)
        .toList();
    return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.secondary,
              title: const Text('إكمال بيانات السائق')),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _options == null
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_error ?? 'تعذر تحميل المناطق'),
                      TextButton(
                          onPressed: _load, child: const Text('إعادة المحاولة'))
                    ]))
                  : AbsorbPointer(
                      absorbing: _saving,
                      child: Form(
                          key: _form,
                          child: ListView(
                              padding: const EdgeInsets.all(20),
                              children: [
                                const Text('بياناتك ومنطقة عملك',
                                    style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                const Text(
                                    'أكمل البيانات وأرفق صور الوثائق لإرسال طلبك للمراجعة.'),
                                const SizedBox(height: 20),
                                TextFormField(
                                    controller: _name,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                        labelText: 'الاسم الكامل'),
                                    validator: (v) =>
                                        v == null || v.trim().length < 2
                                            ? 'أدخل الاسم الكامل'
                                            : null),
                                const SizedBox(height: 16),
                                const ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(Icons.flag_outlined),
                                    title: Text('البلد'),
                                    subtitle: Text('العراق')),
                                DropdownButtonFormField<String>(
                                    initialValue: _governorate,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                        labelText: 'المحافظة'),
                                    items: governors
                                        .map((g) => DropdownMenuItem<String>(
                                            value: g['regionId'] as String,
                                            child: Text(g['name'] as String)))
                                        .toList(),
                                    onChanged: (value) => setState(() {
                                          _governorate = value;
                                          _region = null;
                                        }),
                                    validator: (v) =>
                                        v == null ? 'اختر المحافظة' : null),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                    key: ValueKey(_governorate),
                                    initialValue: _region,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                        labelText: 'منطقة العمل'),
                                    items: regions
                                        .map((r) => DropdownMenuItem<String>(
                                            value: r['regionId'] as String,
                                            child: Text(
                                                '${r['name']} • ${r['districtName']}',
                                                overflow:
                                                    TextOverflow.ellipsis)))
                                        .toList(),
                                    onChanged: _governorate == null
                                        ? null
                                        : (value) =>
                                            setState(() => _region = value),
                                    validator: (v) =>
                                        v == null ? 'اختر منطقة العمل' : null),
                                if (governors.isEmpty)
                                  const Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: Text(
                                          'لا توجد مناطق عمل مفتوحة حاليًا')),
                                const SizedBox(height: 16),
                                TextFormField(
                                    controller: _landmark,
                                    maxLines: 2,
                                    decoration: const InputDecoration(
                                        labelText: 'أقرب نقطة دالة',
                                        hintText: 'مثال: قرب مدرسة أو جامع'),
                                    validator: (v) =>
                                        v == null || v.trim().isEmpty
                                            ? 'أدخل أقرب نقطة دالة'
                                            : null),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                    initialValue: _vehicleType,
                                    decoration: const InputDecoration(
                                        labelText: 'نوع المركبة'),
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'motorcycle',
                                          child: Text('دراجة نارية')),
                                      DropdownMenuItem(
                                          value: 'car', child: Text('سيارة')),
                                    ],
                                    onChanged: (value) =>
                                        setState(() => _vehicleType = value),
                                    validator: (value) => value == null
                                        ? 'اختر نوع المركبة'
                                        : null),
                                const SizedBox(height: 24),
                                const Text('صور الوثائق',
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold)),
                                ..._documents.entries.map((entry) => Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: FileUploadWidget(
                                        label: entry.value,
                                        compact: true,
                                        isRequired: true,
                                        allowedExtensions: const [
                                          'jpg',
                                          'jpeg',
                                          'png',
                                          'heic'
                                        ],
                                        maxSizeMB: 4,
                                        onFileSelected: (file) => setState(() {
                                              _files[entry.key] = file;
                                              _urls.remove(entry.key);
                                            }),
                                        onFileRemoved: () => setState(() {
                                              _files.remove(entry.key);
                                              _urls.remove(entry.key);
                                            })))),
                                if (_error != null)
                                  Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      child: Text(_error!,
                                          style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .error))),
                                const SizedBox(height: 20),
                                FilledButton(
                                    style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: AppColors.secondary),
                                    onPressed:
                                        governors.isEmpty ? null : _submit,
                                    child: _saving
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2))
                                        : const Text('إرسال الطلب للمراجعة')),
                                const SizedBox(height: 12),
                                const Text(
                                    'ستراجع الإدارة بياناتك ووثائقك قبل السماح لك باستقبال الطلبات.',
                                    textAlign: TextAlign.center),
                              ]))),
        ));
  }
}
