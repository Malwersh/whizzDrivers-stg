import '../../../services/wallet_transfer_service.dart';
import '../../../widgets/wallet_transfer_gate.dart';
import 'dart:async';
import '../../../services/push_notifications_service.dart';
import 'wallet_transfer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../design_system/app_colors.dart';
import '../../../models/wallet_balance.dart';
import '../../../models/transaction_history.dart';
import '../../../models/wallet_transaction.dart';
import '../providers/wallet_provider.dart';
import '../widgets/balance_card.dart';
import '../widgets/minimum_balance_indicator.dart';
import '../widgets/transaction_tile.dart';
import 'transactions_screen.dart';

/// Wallet Home Screen
///
/// Main wallet screen displaying:
/// - Balance card (available, locked, total)
/// - Minimum balance indicator (progress toward 25,000 IQD)
/// - Quick actions (topup, monthly statement)
/// - A compact preview of the most recent transactions with a link to the
///   full, paginated transaction history screen.
class WalletHomeScreen extends ConsumerStatefulWidget {
  const WalletHomeScreen({super.key});

  @override
  ConsumerState<WalletHomeScreen> createState() => _WalletHomeScreenState();
}

class _WalletHomeScreenState extends ConsumerState<WalletHomeScreen>
    with WidgetsBindingObserver {
  StreamSubscription<dynamic>? _fundingEvents;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fundingEvents = PushNotificationsService.walletEvents.listen((_) {
      if (mounted) _refresh();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) _refresh();
  }

  @override
  void dispose() {
    _fundingEvents?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.read(walletRefreshProvider.notifier).state++;
    try {
      await Future.wait([
        ref.read(walletBalanceProvider.future),
        ref.read(transactionHistoryProvider(null).future),
      ]);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تعذر تحديث المحفظة. حاول مرة أخرى'),
        ));
      }
    }
  }

  /// Number of recent transactions shown as a preview on the home screen.
  static const int _previewCount = 5;

  @override
  Widget build(BuildContext context) {
    final walletBalanceAsync = ref.watch(walletBalanceProvider);
    // Only ever request the first page here; the full history lives in its
    // own dedicated, paginated screen.
    final transactionHistoryAsync = ref.watch(transactionHistoryProvider(null));

    return Scaffold(
      backgroundColor: AppColors.grey50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.borderLight),
        ),
        title: const Text(
          'المحفظة',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: AppColors.secondary,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.secondary),
            onPressed: walletBalanceAsync.isLoading ? null : _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.secondary,
        onRefresh: _refresh,
        child: walletBalanceAsync.when(
          skipLoadingOnReload: true,
          skipError: walletBalanceAsync.hasValue,
          data: (balance) =>
              _buildWalletContent(balance, transactionHistoryAsync),
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.secondary),
          ),
          error: (error, stack) => _buildErrorState(error),
        ),
      ),
    );
  }

  Widget _buildWalletContent(
    WalletBalance balance,
    AsyncValue<TransactionHistory> transactionHistoryAsync,
  ) {
    return ListView(
      children: [
        WalletTransferGate(
            check: () async =>
                (await WalletTransferService()
                    .call('context'))['canTransfer'] ==
                true,
            builder: (enabled) => BalanceCard(
                onFundingReturn: _refresh,
                balance: balance,
                onTransfer: enabled
                    ? () async {
                        await Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const WalletTransferScreen()));
                        if (mounted) await _refresh();
                      }
                    : null)),
        const SizedBox(height: 16),
        MinimumBalanceIndicator(balance: balance),

        // Transaction History Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  size: 20,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'سجل المعاملات',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              transactionHistoryAsync.maybeWhen(
                data: (history) =>
                    (WalletTransaction.driverVisible(history.transactions)
                                    .length >
                                _previewCount ||
                            history.hasMore)
                        ? _buildViewAllButton()
                        : const SizedBox.shrink(),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
        ),

        // Recent transactions preview
        transactionHistoryAsync.when(
          skipLoadingOnReload: true,
          skipError: transactionHistoryAsync.hasValue,
          data: (history) {
            final visible =
                WalletTransaction.driverVisible(history.transactions);
            if (visible.isEmpty) {
              return _buildEmptyState();
            }
            final preview = visible.take(_previewCount).toList();
            return Column(
              children: [
                ...preview.map((txn) => TransactionTile(transaction: txn)),
                if (visible.length > _previewCount || history.hasMore) ...[
                  const SizedBox(height: 4),
                  _buildViewAllBanner(),
                ],
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.secondary),
            ),
          ),
          error: (error, stack) => _buildTransactionsError(error),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  void _openAllTransactions() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TransactionsScreen()),
    );
  }

  Widget _buildViewAllButton() {
    return TextButton(
      onPressed: _openAllTransactions,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.secondary,
        backgroundColor: AppColors.secondary.withValues(alpha: 0.08),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: const Size(0, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: const Text(
        'عرض الكل',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildViewAllBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: OutlinedButton.icon(
        onPressed: _openAllTransactions,
        icon: const Icon(Icons.chevron_left_rounded,
            size: 20, color: AppColors.secondary),
        label: const Text(
          'عرض كل المعاملات',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.secondary,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 13),
          minimumSize: const Size.fromHeight(0),
          side: BorderSide(
            color: AppColors.secondary.withValues(alpha: 0.25),
            width: 1.25,
          ),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 64, color: AppColors.grey400),
            SizedBox(height: 16),
            Text(
              'لا توجد معاملات بعد',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsError(Object error) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            const Text(
              'خطأ في تحميل المعاملات',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                ref.read(walletRefreshProvider.notifier).state++;
              },
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 24),
            const Text(
              'خطأ في تحميل المحفظة',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              error.toString(),
              style:
                  const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(walletRefreshProvider.notifier).state++;
              },
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
