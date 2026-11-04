import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../wallet/providers/wallet_provider.dart';
import '../../providers/riverpod/tab_provider.dart';

const _ink = Color(0xFF00296B);

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(walletNotificationsProvider);
    Future<void> refresh() async {
      ref.invalidate(walletNotificationsProvider);
      await ref.read(walletNotificationsProvider.future);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          title: const Text('الإشعارات',
              style: TextStyle(
                  color: _ink, fontSize: 20, fontWeight: FontWeight.w600)),
          actions: [
            IconButton(
                tooltip: 'تحديث الإشعارات',
                onPressed: refresh,
                icon: const Icon(Icons.refresh_rounded, color: _ink))
          ]),
      body: notifications.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _ink)),
        error: (_, __) => Center(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.cloud_off_outlined, color: _ink, size: 38),
                  const SizedBox(height: 12),
                  const Text('تعذر تحميل الإشعارات',
                      style: TextStyle(color: _ink)),
                  TextButton(
                      onPressed: refresh,
                      child: const Text('إعادة المحاولة',
                          style: TextStyle(color: _ink)))
                ]))),
        data: (items) {
          final sorted = [...items]..sort(
              (a, b) => _notificationDate(b).compareTo(_notificationDate(a)));
          String? previous;
          return RefreshIndicator(
              onRefresh: refresh,
              color: _ink,
              child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(children: [
                          const Expanded(
                              child: Text('آخر التحديثات',
                                  style: TextStyle(
                                      color: _ink,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600))),
                          if (items.isNotEmpty)
                            Text('${items.length} إشعار',
                                style: const TextStyle(
                                    color: Color(0xFF66758D), fontSize: 12))
                        ])),
                    if (items.isEmpty)
                      const Padding(
                          padding: EdgeInsets.symmetric(vertical: 70),
                          child: Column(children: [
                            Icon(Icons.notifications_none_rounded,
                                size: 52, color: Color(0xFF8B99AD)),
                            SizedBox(height: 16),
                            Text('لا توجد إشعارات بعد',
                                style: TextStyle(
                                    color: _ink,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600)),
                            SizedBox(height: 8),
                            Text('ستظهر تحديثات المحفظة والحساب هنا.',
                                style: TextStyle(color: Color(0xFF66758D)),
                                textAlign: TextAlign.center)
                          ])),
                    for (final item in sorted) ...[
                      if (previous != notificationDayLabel(item))
                        Padding(
                            padding: const EdgeInsets.only(top: 14, bottom: 10),
                            child: Text(previous = notificationDayLabel(item),
                                style: const TextStyle(
                                    color: Color(0xFF66758D),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600))),
                      WalletNotificationCard(
                          item: item,
                          onTap: () {
                            ref.read(walletRefreshProvider.notifier).state++;
                            ref.read(selectedTabProvider.notifier).state =
                                DriverTabs.wallet;
                          }),
                    ]
                  ]));
        },
      ),
    );
  }
}

DateTime _notificationDate(Map item) =>
    DateTime.tryParse('${item['createdAt'] ?? ''}')?.toUtc() ??
    DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
String notificationDayLabel(Map item, {DateTime? now}) {
  if (DateTime.tryParse('${item['createdAt'] ?? ''}') == null)
    return 'إشعارات سابقة';
  final d = _notificationDate(item).add(const Duration(hours: 3));
  final n = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 3));
  final days = DateTime.utc(n.year, n.month, n.day)
      .difference(DateTime.utc(d.year, d.month, d.day))
      .inDays;
  if (days == 0) return 'اليوم';
  if (days == 1) return 'أمس';
  return '${d.day}/${d.month}/${d.year}';
}

class WalletNotificationCard extends StatelessWidget {
  const WalletNotificationCard(
      {super.key, required this.item, required this.onTap});
  final Map item;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final type = '${item['type'] ?? ''}',
        title = '${item['title'] ?? ''}'.trim(),
        body = '${item['body'] ?? ''}'.trim();
    final payout = type == 'wallet_cash_payout',
        rejected = type.contains('rejected'),
        approved = type.contains('approved');
    final color = rejected
        ? const Color(0xFFB76627)
        : approved
            ? const Color(0xFF20856D)
            : _ink;
    final icon = payout
        ? Icons.payments_outlined
        : type.contains('topup')
            ? Icons.account_balance_wallet_outlined
            : type.contains('transfer')
                ? Icons.swap_horiz_rounded
                : Icons.notifications_outlined;
    final date = DateTime.tryParse('${item['createdAt'] ?? ''}')
        ?.toUtc()
        .add(const Duration(hours: 3));
    final time = date == null
        ? null
        : '${date.hour % 12 == 0 ? 12 : date.hour % 12}:${date.minute.toString().padLeft(2, '0')} ${date.hour < 12 ? 'ص' : 'م'}';
    return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: Color(0xFFE7EBF2))),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
                onTap: onTap,
                child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                  color: color.withValues(alpha: .08),
                                  borderRadius: BorderRadius.circular(13)),
                              child: Icon(icon, color: color, size: 23)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(title.isEmpty ? 'تحديث المحفظة' : title,
                                    style: const TextStyle(
                                        color: _ink,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        height: 1.5)),
                                if (body.isNotEmpty)
                                  Padding(
                                      padding: const EdgeInsets.only(top: 5),
                                      child: Text(body,
                                          style: const TextStyle(
                                              color: Color(0xFF53627B),
                                              fontSize: 13,
                                              height: 1.7))),
                                const SizedBox(height: 10),
                                Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 12,
                                    runSpacing: 8,
                                    children: [
                                      if (time != null)
                                        Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                  Icons.access_time_rounded,
                                                  size: 13,
                                                  color: Color(0xFF8592A8)),
                                              const SizedBox(width: 4),
                                              Text(time,
                                                  style: const TextStyle(
                                                      color: Color(0xFF8592A8),
                                                      fontSize: 11))
                                            ]),
                                      const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Flexible(
                                                child: Text('عرض المحفظة',
                                                    style: TextStyle(
                                                        color: _ink,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w500))),
                                            SizedBox(width: 3),
                                            Icon(Icons.chevron_left,
                                                size: 16, color: _ink)
                                          ])
                                    ])
                              ]))
                        ])))));
  }
}
