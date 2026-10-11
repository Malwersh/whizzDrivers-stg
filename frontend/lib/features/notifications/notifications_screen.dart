import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../wallet/providers/wallet_provider.dart';
import '../../providers/riverpod/tab_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(walletNotificationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('الإشعارات')),
      body: notifications.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
            child: TextButton(
                onPressed: () => ref.invalidate(walletNotificationsProvider),
                child: const Text('تعذر تحميل الإشعارات — إعادة المحاولة'))),
        data: (items) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(walletNotificationsProvider);
            await ref.read(walletNotificationsProvider.future);
          },
          child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (items.isEmpty)
                  const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('لا توجد إشعارات للمحفظة'))),
                ...items.map((item) => ListTile(
                      leading: Icon(item['type'] == 'wallet_topup_approved'
                          ? Icons.account_balance_wallet
                          : Icons.info_outline),
                      title: Text(item['title'] ?? ''),
                      subtitle: Text(
                          '${item['body'] ?? ''}\n${item['createdAt'] ?? ''}'),
                      onTap: () {
                        ref.read(walletRefreshProvider.notifier).state++;
                        ref.read(selectedTabProvider.notifier).state = 2;
                      },
                    )),
              ]),
        ),
      ),
    );
  }
}
