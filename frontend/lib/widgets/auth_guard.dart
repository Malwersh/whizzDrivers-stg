import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../design_system/app_colors.dart';
import '../providers/riverpod/services_provider.dart';

/// Riverpod-based auth guard replacing legacy ChangeNotifier implementation.
class AuthGuard extends ConsumerWidget {
  final Widget child;

  const AuthGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(cognitoAuthServiceProvider);

    // For simplicity, assume no loading state for now
    // TODO: Add loading state if needed
    if (!authService.isAuthenticated) {
      // Schedule navigation to avoid setState during build / multiple pushes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/login');
      });
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return child;
  }
}

/// Wrapper that chooses between authenticated / unauthenticated child widgets.
class AuthWrapper extends ConsumerWidget {
  final Widget authenticatedChild;
  final Widget unauthenticatedChild;

  const AuthWrapper({
    super.key,
    required this.authenticatedChild,
    required this.unauthenticatedChild,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(cognitoAuthServiceProvider);

    return authService.isAuthenticated
        ? authenticatedChild
        : unauthenticatedChild;
  }
}
