import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import '../../../app_colors.dart';
import '../../../config/environment.dart';
import '../../../legal/application_legal_bundle.dart';
import '../../../legal/application_legal_consent.dart';
import '../../../services/cognito_token_service.dart';
import '../../../services/document_upload_service.dart';
import '../../../widgets/file_upload_widget.dart';

class DriverProfileSetupScreen extends ConsumerStatefulWidget {
  final String phoneNumber;
  final Future<String?> Function()? profileToken;
  const DriverProfileSetupScreen({
    super.key,
    required this.phoneNumber,
    this.profileToken,
  });
  @override
  ConsumerState<DriverProfileSetupScreen> createState() =>
      _DriverProfileSetupScreenState();
}

class _DriverProfileSetupScreenState
    extends ConsumerState<DriverProfileSetupScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _landmark = TextEditingController();
  final _plate = TextEditingController();
  final _files = <String, Map<String, dynamic>>{};
  final _urls = <String, String>{};
  Map<String, dynamic>? _options;
  String? _governorate, _region, _error, _vehicleType;
  bool _loading = true, _saving = false;
  ApplicationLegalBundle? _legalConsent;
  int _legalEpoch = 0;
  static const _documents = {
    'registration_paper': 'سنوية المركبة',
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
    _plate.dispose();
    super.dispose();
  }

  Future<Map<String, String>> _headers() async {
    final token =
        await (widget.profileToken ?? CognitoTokenService.getProfileToken)();
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
    if (_saving) return;
    FocusScope.of(context).unfocus();
    final invalid = _form.currentState!.validateGranularly();
    if (invalid.isNotEmpty) {
      final field = invalid.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !field.mounted) return;
        Scrollable.ensureVisible(
          field.context,
          duration: const Duration(milliseconds: 260),
          alignment: 0.16,
        );
      });
      return;
    }
    if (_documents.keys.any((type) => !_files.containsKey(type))) {
      setState(() => _error = 'أرفق صور الوثائق الثلاث لإرسال طلبك.');
      return;
    }
    if (_legalConsent == null) {
      setState(() =>
          _error = 'راجع السياسات المنشورة ووافق عليها قبل إرسال بياناتك.');
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
                'legalAccepted': true,
                'legalAcceptance': _legalConsent!.pin,
                'name': _name.text.trim(),
                'vehicleType': _vehicleType,
                'vehiclePlate': _plate.text.trim(),
                'governorate_id': _governorate,
                'work_region_id': _region,
                'home_address_text': _landmark.text.trim(),
                'registrationPaperUrl': _urls['registration_paper'],
                'drivingLicenseUrl': _urls['driving_license'],
                'nationalIdUrl': _urls['national_id'],
              }))
          .timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        if (['LEGAL_VERSION_CHANGED', 'LEGAL_ACCEPTANCE_REQUIRED']
            .contains(error['code'] ?? error['error'])) {
          if (!mounted) return;
          setState(() {
            _legalConsent = null;
            _legalEpoch++;
          });
          throw StateError('تحدثت السياسات؛ راجع النص الجديد ووافق عليه.');
        }
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

  static const _background = Color(0xFFF5F7FB);
  static const _border = Color(0xFFD9E2EE);
  static const _muted = Color(0xFF52647B);
  static const _fieldGap = SizedBox(height: 14);

  InputDecoration _field(String label, IconData icon, {String? hint}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        counterText: '',
      );

  Widget _section(IconData icon, String title, List<Widget> children) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5D5),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 21, color: AppColors.secondary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.secondaryDark,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      );

  Widget _header() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: const Text(
                    'إكمال ملف السائق',
                    style: TextStyle(
                      color: AppColors.secondaryDark,
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Image.asset(
                'assets/images/wizz-wordmark-blue.png',
                width: 54,
                height: 23,
                fit: BoxFit.contain,
                semanticLabel: 'Wizz',
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'أدخل بياناتك وأرفق وثائقك لإرسال طلبك للمراجعة.',
            style: TextStyle(color: _muted, fontSize: 14, height: 1.55),
          ),
        ],
      );

  Widget _notice(String text, {bool error = false}) {
    final ink = error ? const Color(0xFF932628) : AppColors.secondary;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: error ? const Color(0xFFFCEEEF) : const Color(0xFFEEF3FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(error ? Icons.error_outline : Icons.info_outline,
                size: 18, color: ink),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text, style: TextStyle(color: ink, height: 1.55)),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _formSections() {
    final governors = (_options?['governorates'] as List?) ?? [];
    final regions = ((_options?['regions'] as List?) ?? [])
        .where((r) => r['governorateId'] == _governorate)
        .toList();
    final labels = MaterialLocalizations.of(context);
    return [
      _section(Icons.badge_outlined, 'البيانات ومنطقة العمل', [
        TextFormField(
          controller: _name,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          decoration: _field('الاسم الكامل', Icons.person_outline),
          validator: (value) => value == null || value.trim().length < 2
              ? 'أدخل الاسم الكامل'
              : null,
        ),
        _fieldGap,
        const ListTile(
          dense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 8),
          leading: Icon(Icons.flag_outlined, color: AppColors.secondary),
          title: Text('البلد', style: TextStyle(color: _muted)),
          subtitle: Text(
            'العراق',
            style: TextStyle(
              color: AppColors.secondaryDark,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        _fieldGap,
        DropdownButtonFormField<String>(
          initialValue: _governorate,
          isExpanded: true,
          decoration: _field('المحافظة', Icons.map_outlined),
          items: [
            for (final g in governors)
              DropdownMenuItem<String>(
                value: g['regionId'] as String,
                child:
                    Text(g['name'] as String, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: governors.isEmpty
              ? null
              : (value) => setState(() {
                    _governorate = value;
                    _region = null;
                  }),
          validator: (value) => value == null ? 'اختر المحافظة' : null,
        ),
        _fieldGap,
        DropdownButtonFormField<String>(
          key: ValueKey(_governorate),
          initialValue: _region,
          isExpanded: true,
          decoration: _field('منطقة العمل', Icons.location_on_outlined),
          items: [
            for (final r in regions)
              DropdownMenuItem<String>(
                value: r['regionId'] as String,
                child: Text(
                  '${r['name']} • ${r['districtName']}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: regions.isEmpty
              ? null
              : (value) => setState(() => _region = value),
          validator: (value) => value == null ? 'اختر منطقة العمل' : null,
        ),
        if (governors.isEmpty || (_governorate != null && regions.isEmpty)) ...[
          _fieldGap,
          _notice(governors.isEmpty
              ? 'لا توجد مناطق عمل مفتوحة حاليًا.'
              : 'لا توجد مناطق عمل مفتوحة في هذه المحافظة.'),
        ],
        _fieldGap,
        TextFormField(
          controller: _landmark,
          minLines: 1,
          maxLines: 2,
          decoration: _field(
            'أقرب نقطة دالة',
            Icons.place_outlined,
            hint: 'مثال: قرب مدرسة أو جامع',
          ),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'أدخل أقرب نقطة دالة'
              : null,
        ),
      ]),
      const SizedBox(height: 16),
      _section(Icons.directions_car_outlined, 'المركبة', [
        DropdownButtonFormField<String>(
          initialValue: _vehicleType,
          isExpanded: true,
          decoration: _field('نوع المركبة', Icons.two_wheeler_outlined),
          items: const [
            DropdownMenuItem(value: 'motorcycle', child: Text('دراجة نارية')),
            DropdownMenuItem(value: 'car', child: Text('سيارة')),
          ],
          onChanged: (value) => setState(() => _vehicleType = value),
          validator: (value) => value == null ? 'اختر نوع المركبة' : null,
        ),
        _fieldGap,
        TextFormField(
          controller: _plate,
          maxLength: 40,
          decoration: _field('رقم لوحة المركبة', Icons.pin_outlined),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'أدخل رقم لوحة المركبة كما في السنوية'
              : null,
        ),
      ]),
      const SizedBox(height: 16),
      _section(Icons.description_outlined, 'الوثائق المطلوبة', [
        Text(
          'أرفق صورة واضحة لكل وثيقة. الحد الأقصى للصورة الواحدة ${labels.formatDecimal(4)} ميغابايت.',
          style: const TextStyle(color: _muted, height: 1.55),
        ),
        for (final entry in _documents.entries) ...[
          _fieldGap,
          FileUploadWidget(
            key: ValueKey(entry.key),
            label: entry.value,
            compact: true,
            isRequired: true,
            allowedExtensions: const ['jpg', 'jpeg', 'png', 'heic'],
            maxSizeMB: 4,
            onFileSelected: (file) => setState(() {
              _files[entry.key] = file;
              _urls.remove(entry.key);
            }),
            onFileRemoved: () => setState(() {
              _files.remove(entry.key);
              _urls.remove(entry.key);
            }),
          ),
        ],
      ]),
      const SizedBox(height: 16),
      _section(Icons.fact_check_outlined, 'السياسات والمراجعة', [
        ApplicationLegalConsent(
          key: ValueKey('driver-legal-$_legalEpoch'),
          enabled: !_saving,
          onChanged: (bundle) => setState(() => _legalConsent = bundle),
        ),
        const SizedBox(height: 6),
        const Text(
          'بعد إرسال طلبك، تراجع الإدارة البيانات والوثائق قبل تفعيل استقبال الطلبات.',
          style: TextStyle(color: _muted, height: 1.55),
        ),
      ]),
      const SizedBox(height: 16),
      if (_error case final error?) ...[
        _notice(error, error: true),
        const SizedBox(height: 12),
      ],
      FilledButton(
        onPressed: _saving || governors.isEmpty ? null : _submit,
        child: _saving
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Flexible(child: Text('جارٍ إرسال الطلب…')),
                ],
              )
            : const Text('إرسال الطلب للمراجعة'),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: _border),
    );
    final errorBorder = border.copyWith(
      borderSide: BorderSide(color: theme.colorScheme.error),
    );
    final canGoBack = Navigator.canPop(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Theme(
        data: theme.copyWith(
          textTheme: theme.textTheme.apply(
            fontFamily: 'NotoSansArabic',
            bodyColor: AppColors.secondaryDark,
          ),
          inputDecorationTheme: theme.inputDecorationTheme.copyWith(
            filled: true,
            fillColor: _background,
            border: border,
            enabledBorder: border,
            disabledBorder: border,
            focusedBorder: border.copyWith(
              borderSide:
                  const BorderSide(color: AppColors.secondary, width: 2),
            ),
            errorBorder: errorBorder,
            focusedErrorBorder: errorBorder,
            errorMaxLines: 2,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
            labelStyle: const TextStyle(color: _muted),
            hintStyle: const TextStyle(color: _muted),
            prefixIconColor: AppColors.secondary,
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.secondaryDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontFamily: 'NotoSansArabic',
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        child: Scaffold(
          backgroundColor: _background,
          appBar: canGoBack
              ? AppBar(
                  backgroundColor: _background,
                  foregroundColor: AppColors.secondary)
              : null,
          body: SafeArea(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Form(
                    key: _form,
                    child: AbsorbPointer(
                      absorbing: _saving,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _header(),
                          const SizedBox(height: 16),
                          if (_loading)
                            Semantics(
                              label: 'جارٍ تحميل خيارات التسجيل',
                              child: const LinearProgressIndicator(
                                color: AppColors.secondary,
                              ),
                            )
                          else if (_options == null) ...[
                            _notice(_error ?? 'تعذر تحميل المناطق.',
                                error: true),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _load,
                              child: const Text('إعادة المحاولة'),
                            ),
                          ] else
                            ..._formSections(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
