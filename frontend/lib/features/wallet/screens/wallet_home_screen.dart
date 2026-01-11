import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../design_system/app_colors.dart';
import '../../../models/wallet_balance.dart';
import '../../../models/transaction_history.dart';
import '../providers/wallet_provider.dart';
import '../widgets/balance_card.dart';
import '../widgets/minimum_balance_indicator.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/quick_actions_row.dart';

/// Wallet Home Screen
/// 
/// Main wallet screen displaying:
/// - Balance card (available, locked, total)
/// - Minimum balance indicator (progress toward 25,000 IQD)
/// - Quick actions (topup, monthly statement)
/// - Transaction history list
class WalletHomeScreen extends ConsumerStatefulWidget {
  const WalletHomeScreen({super.key});

  @override
  ConsumerState<WalletHomeScreen> createState() => _WalletHomeScreenState();
}

class _WalletHomeScreenState extends ConsumerState<WalletHomeScreen> {
  String? _nextToken; // For pagination
  List<dynamic> _allTransactions = []; // Accumulate all loaded transactions

  @override
  Widget build(BuildContext context) {
    final walletBalanceAsync = ref.watch(walletBalanceProvider);
    final transactionHistoryAsync = ref.watch(
      transactionHistoryProvider(_nextToken),
    );

    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text(
          '💰 المحفظة',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF00296B), // Dark blue
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF00296B)),
            onPressed: () {
              // Trigger refresh
              ref.read(walletRefreshProvider.notifier).state++;
              // Reset pagination
              setState(() {
                _nextToken = null;
                _allTransactions = [];
              });
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Refresh wallet data
          ref.read(walletRefreshProvider.notifier).state++;
          // Reset pagination
          setState(() {
            _nextToken = null;
            _allTransactions = [];
          });
        },
        child: walletBalanceAsync.when(
          data: (balance) => _buildWalletContent(
            balance,
            transactionHistoryAsync,
          ),
          loading: () => const Center(
            child: CircularProgressIndicator(),
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
    return CustomScrollView(
      slivers: [
        // Balance Card
        SliverToBoxAdapter(
          child: BalanceCard(balance: balance),
        ),

        // Minimum Balance Indicator
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: MinimumBalanceIndicator(balance: balance),
          ),
        ),

        // Quick Actions
        const SliverToBoxAdapter(
          child: QuickActionsRow(),
        ),

        // Transaction History Header
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: Row(
              children: [
                Icon(
                  Icons.history,
                  size: 22,
                  color: Color(0xFF00296B),
                ),
                SizedBox(width: 8),
                Text(
                  '📋 سجل المعاملات',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Transaction List
        transactionHistoryAsync.when(
          data: (history) {
            // Accumulate transactions on first load or when _nextToken is null
            if (_nextToken == null && history.transactions.isNotEmpty) {
              _allTransactions = history.transactions;
            } else if (_nextToken != null && history.transactions.isNotEmpty) {
              // Append new transactions when loading more
              _allTransactions.addAll(history.transactions);
            }

            if (_allTransactions.isEmpty) {
              return SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'لا توجد معاملات بعد',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index < _allTransactions.length) {
                    return TransactionTile(
                      transaction: _allTransactions[index],
                    );
                  } else if (history.hasMore) {
                    // Load more button
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _nextToken = history.nextToken;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'تحميل المزيد',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
                childCount: _allTransactions.length + (history.hasMore ? 1 : 0),
              ),
            );
          },
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
          error: (error, stack) => SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'خطأ في تحميل المعاملات',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Bottom padding
        const SliverToBoxAdapter(
          child: SizedBox(height: 24),
        ),
      ],
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error,
            ),
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
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
