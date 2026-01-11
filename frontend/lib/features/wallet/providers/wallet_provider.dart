import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/wallet_balance.dart';
import '../../../models/transaction_history.dart';
import '../../../services/wallet_api_service.dart';

/// Wallet Balance Provider
/// 
/// FutureProvider that fetches driver's wallet balance from backend
/// Automatically refetches when dependencies change
final walletBalanceProvider = FutureProvider.autoDispose<WalletBalance>((ref) async {
  // Watch refresh trigger to refetch when needed
  ref.watch(walletRefreshProvider);
  
  final apiService = WalletApiService();
  return await apiService.getWalletBalance();
});

/// Transaction History Provider
/// 
/// FutureProvider that fetches driver's transaction history
/// Supports pagination via nextToken
final transactionHistoryProvider = FutureProvider.autoDispose
    .family<TransactionHistory, String?>((ref, nextToken) async {
  final apiService = WalletApiService();
  return await apiService.getTransactionHistory(
    limit: 20,
    nextToken: nextToken,
  );
});

/// Wallet Refresh Provider
/// 
/// StateProvider that triggers refetch of wallet data when incremented
/// Usage: ref.read(walletRefreshProvider.notifier).state++
final walletRefreshProvider = StateProvider<int>((ref) => 0);
