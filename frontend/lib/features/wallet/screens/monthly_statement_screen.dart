import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../design_system/app_colors.dart';
import '../../../models/monthly_wallet_statement.dart';
import '../../../services/monthly_wallet_service.dart';
import '../../../services/monthly_wallet_pdf.dart';
import '../widgets/transaction_tile.dart';

class MonthlyStatementScreen extends StatefulWidget {
  const MonthlyStatementScreen({super.key, this.service});
  final MonthlyWalletService? service;
  @override
  State<MonthlyStatementScreen> createState() => _MonthlyStatementScreenState();
}

class _MonthlyStatementScreenState extends State<MonthlyStatementScreen> {
  late final MonthlyWalletService _service =
      widget.service ?? MonthlyWalletService();
  String _month = MonthlyWalletStatement.monthOf(DateTime.now());
  MonthlyWalletStatement? _statement;
  bool _loading = true, _saving = false;
  String? _error;
  int _generation = 0, _loaded = 0;
  static const _months = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر'
  ];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _statement = null;
      _loaded = 0;
    });
    try {
      final result = await _service.load(_month, onProgress: (n) {
        if (mounted && generation == _generation) setState(() => _loaded = n);
      });
      if (mounted && generation == _generation)
        setState(() {
          _statement = result;
          _loading = false;
        });
    } catch (_) {
      if (mounted && generation == _generation)
        setState(() {
          _error = 'تعذر تحميل الكشف كاملًا. تحقق من الاتصال ثم أعد المحاولة.';
          _loading = false;
        });
    }
  }

  String _money(int n) =>
      '${n.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} د.ع';
  Future<void> _chooseMonth() async {
    final now = MonthlyWalletStatement.baghdad(DateTime.now());
    var year = int.parse(_month.substring(0, 4)),
        month = int.parse(_month.substring(5));
    final choice = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (context) => SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: StatefulBuilder(
                    builder: (context, update) => Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text('اختر شهر الكشف',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary)),
                              const SizedBox(height: 20),
                              DropdownButtonFormField<int>(
                                  dropdownColor: Colors.white,
                                  style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 16),
                                  iconEnabledColor: AppColors.secondary,
                                  initialValue: year,
                                  decoration: const InputDecoration(
                                      filled: true,
                                      fillColor: Colors.white,
                                      labelStyle: TextStyle(
                                          color: AppColors.textSecondary),
                                      labelText: 'السنة',
                                      border: OutlineInputBorder()),
                                  items: [
                                    for (var y = now.year; y >= 2000; y--)
                                      DropdownMenuItem(
                                          value: y, child: Text('$y'))
                                  ],
                                  onChanged: (v) => update(() {
                                        year = v!;
                                        if (year == now.year &&
                                            month > now.month)
                                          month = now.month;
                                      })),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<int>(
                                  dropdownColor: Colors.white,
                                  style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 16),
                                  iconEnabledColor: AppColors.secondary,
                                  key: ValueKey(year),
                                  initialValue: month,
                                  decoration: const InputDecoration(
                                      filled: true,
                                      fillColor: Colors.white,
                                      labelStyle: TextStyle(
                                          color: AppColors.textSecondary),
                                      labelText: 'الشهر',
                                      border: OutlineInputBorder()),
                                  items: [
                                    for (var m = 1;
                                        m <=
                                            (year == now.year ? now.month : 12);
                                        m++)
                                      DropdownMenuItem(
                                          value: m, child: Text(_months[m - 1]))
                                  ],
                                  onChanged: (v) => update(() => month = v!)),
                              const SizedBox(height: 24),
                              FilledButton(
                                  onPressed: () => Navigator.pop(context,
                                      '$year-${month.toString().padLeft(2, '0')}'),
                                  style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.secondary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.all(14)),
                                  child: const Text('عرض الكشف',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700))),
                            ])))));
    if (choice != null && mounted && choice != _month) {
      setState(() => _month = choice);
      await _load();
    }
  }

  Future<void> _save() async {
    final statement = _statement;
    if (statement == null) return;
    setState(() => _saving = true);
    try {
      final path = await FilePicker.platform.saveFile(
          dialogTitle: 'حفظ الكشف الشهري',
          fileName: 'wallet-${statement.month}.pdf',
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          bytes: await MonthlyWalletPdf.generate(statement));
      if (mounted && path != null)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تم حفظ الكشف')));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر حفظ الملف. حاول مجددًا.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showActions() async {
    final download = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (context) => SafeArea(
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: ListTile(
                    leading: const Icon(Icons.download_rounded,
                        color: AppColors.secondary),
                    title: const Text('تحميل الكشف',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700)),
                    subtitle: const Text('ملف PDF',
                        style: TextStyle(color: AppColors.textSecondary)),
                    onTap: () => Navigator.pop(context, true)))));
    if (download == true && mounted) await _save();
  }

  Widget _summary(String title, int amount) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        Expanded(child: Text(title)),
        Text(_money(amount),
            style: const TextStyle(
                fontWeight: FontWeight.w700, color: AppColors.secondary))
      ]));
  @override
  Widget build(BuildContext context) {
    final s = _statement;
    final visible = s?.visible ?? [];
    return Scaffold(
        backgroundColor: AppColors.grey50,
        appBar: AppBar(
            title: const Text('الكشف الشهري'),
            actions: [
              IconButton(
                  tooltip: 'خيارات الكشف',
                  onPressed: s == null || _saving ? null : _showActions,
                  icon: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.more_vert))
            ],
            foregroundColor: AppColors.secondary,
            backgroundColor: Colors.white),
        body: RefreshIndicator(
            onRefresh: _load,
            child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                      child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                OutlinedButton.icon(
                                    onPressed: _chooseMonth,
                                    icon: const Icon(Icons.calendar_month),
                                    label: Text(
                                        '${_months[int.parse(_month.substring(5)) - 1]} ${_month.substring(0, 4)}'),
                                    style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.secondary,
                                        padding: const EdgeInsets.all(14))),
                                const SizedBox(height: 12),
                                const Text(
                                    'الفترة حسب توقيت بغداد. يعرض الكشف الحركات المسجلة في المحفظة؛ أجور التوصيل التي تحتفظ بها نقدًا تظهر في صفحة أرباحك.',
                                    style: TextStyle(
                                        height: 1.7,
                                        color: AppColors.textPrimary)),
                                if (_loading) ...[
                                  const SizedBox(height: 28),
                                  const Center(
                                      child: CircularProgressIndicator()),
                                  const SizedBox(height: 16),
                                  Text('جارٍ تحميل الكشف كاملًا… $_loaded حركة',
                                      textAlign: TextAlign.center)
                                ],
                                if (_error != null) ...[
                                  const SizedBox(height: 24),
                                  Text(_error!,
                                      style: const TextStyle(
                                          color: AppColors.error)),
                                  TextButton.icon(
                                      onPressed: _load,
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('إعادة المحاولة'))
                                ],
                                if (s != null) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                      padding: const EdgeInsets.all(18),
                                      decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(16)),
                                      child: Column(children: [
                                        _summary('الإضافات الفعلية', s.credits),
                                        _summary('الخصومات الفعلية', s.debits),
                                        const Divider(),
                                        _summary('صافي تغيّر المحفظة', s.net),
                                        const Divider(),
                                        _summary(
                                            'حُجز مؤقتًا خلال الشهر', s.holds),
                                        _summary(
                                            'فُك حجزه خلال الشهر', s.releases),
                                        const Text(
                                            'الحجز وفكّه ينقلان الرصيد بين المتاح والمحجوز، ولا يُحتسبان كإيراد أو مصروف.',
                                            style: TextStyle(
                                                height: 1.6,
                                                color:
                                                    AppColors.textSecondary)),
                                      ])),
                                  const SizedBox(height: 12),
                                  Text(
                                      'حتى ${MonthlyWalletStatement.baghdad(s.asOf).toString().substring(0, 16)} بتوقيت بغداد',
                                      style: const TextStyle(
                                          color: AppColors.textSecondary)),
                                  const SizedBox(height: 8),
                                  const SizedBox(height: 18),
                                  Text('الحركات (${visible.length})',
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700)),
                                  if (visible.isEmpty)
                                    const Padding(
                                        padding: EdgeInsets.all(28),
                                        child: Text(
                                            'لا توجد حركات في هذا الشهر',
                                            textAlign: TextAlign.center)),
                                ],
                              ]))),
                  if (s != null)
                    SliverList(
                        delegate: SliverChildBuilderDelegate(
                            (context, index) => TransactionTile(
                                transaction: visible[index],
                                useBaghdadTime: true),
                            childCount: visible.length)),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ])));
  }
}
