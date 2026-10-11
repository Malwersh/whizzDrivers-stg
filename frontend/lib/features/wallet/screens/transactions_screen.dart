import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../design_system/app_colors.dart';
import '../../../models/transaction_history.dart';
import '../../../models/wallet_transaction.dart';
import '../providers/wallet_provider.dart';
import '../widgets/transaction_tile.dart';

/// Transactions Screen
///
/// Full, paginated transaction history with a "load more" button.
/// Pages are fetched via [transactionHistoryProvider] using the continuation
/// token returned by the backend, and merged with de-duplication by the unique
/// ledger entry id.
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  String? _nextToken; // Current page token being requested
  String? _pendingNextToken; // Next token to request on "load more"
  String? _lastProcessedPageToken;
  bool _isLoadingMore = false;
  List<WalletTransaction> _allTransactions = [];
  final Set<String> _transactionIds = <String>{};

  void _resetPagination() {
    _nextToken = null;
    _pendingNextToken = null;
    _lastProcessedPageToken = null;
    _isLoadingMore = false;
    _allTransactions = <WalletTransaction>[];
    _transactionIds.clear();
  }

  void _appendUniqueTransactions(List<WalletTransaction> transactions) {
    for (final transaction in transactions) {
      if (_transactionIds.add(transaction.entryId)) {
        _allTransactions.add(transaction);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactionHistoryAsync =
        ref.watch(transactionHistoryProvider(_nextToken));

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
        iconTheme: const IconThemeData(color: AppColors.secondary),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'سجل المعاملات',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.secondary,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.secondary,
        onRefresh: () async {
          ref.read(walletRefreshProvider.notifier).state++;
          setState(_resetPagination);
        },
        child: transactionHistoryAsync.when(
          data: (history) => _buildList(history),
          loading: () => _allTransactions.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.secondary),
                )
              : _buildList(null),
          error: (error, stack) => _buildError(error),
        ),
      ),
    );
  }

  Widget _buildList(TransactionHistory? history) {
    if (history != null) {
      final pageToken = _nextToken ?? '__FIRST_PAGE__';
      if (_lastProcessedPageToken != pageToken) {
        if (_nextToken == null) {
          _allTransactions = <WalletTransaction>[];
          _transactionIds.clear();
        }
        _appendUniqueTransactions(
            WalletTransaction.driverVisible(history.transactions));
        _pendingNextToken = history.nextToken;
        _lastProcessedPageToken = pageToken;
        _isLoadingMore = false;
      }
    }

    if (_allTransactions.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Icon(Icons.receipt_long_outlined,
              size: 64, color: AppColors.grey400),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'لا توجد معاملات بعد',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
          ),
        ],
      );
    }

    final hasMore = (history?.hasMore ?? (_pendingNextToken != null)) ||
        _isLoadingMore;

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: _allTransactions.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < _allTransactions.length) {
          return TransactionTile(transaction: _allTransactions[index]);
        }
        return Padding(
          padding: const EdgeInsets.all(16),
          child: _isLoadingMore
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.secondary),
                )
              : ElevatedButton(
                  onPressed: _pendingNextToken == null
                      ? null
                      : () {
                          setState(() {
                            _isLoadingMore = true;
                            _nextToken = _pendingNextToken;
                          });
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'تحميل المزيد',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildError(Object error) {
    // Load-more error: keep already loaded items and offer retry.
    if (_allTransactions.isNotEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        itemCount: _allTransactions.length + 1,
        itemBuilder: (context, index) {
          if (index < _allTransactions.length) {
            return TransactionTile(transaction: _allTransactions[index]);
          }
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تعذر تحميل المزيد من المعاملات',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton.icon(
                      onPressed: _pendingNextToken == null
                          ? null
                          : () {
                              setState(() {
                                _isLoadingMore = true;
                                _nextToken = _pendingNextToken;
                              });
                            },
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
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
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () {
              ref.read(walletRefreshProvider.notifier).state++;
              setState(_resetPagination);
            },
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}
