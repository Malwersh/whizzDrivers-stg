import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/riverpod/services_provider.dart';
import 'auth/login_screen.dart';
import '../features/authentication/screens/pending_review_screen.dart';

/// Authentication Wrapper that checks authentication state and routes users accordingly
class AuthWrapper extends ConsumerStatefulWidget {
  final Widget authenticatedHome;
  
  const AuthWrapper({
    super.key,
    required this.authenticatedHome,
  });

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> {
  bool _isLoading = true;
  bool _isAuthenticated = false;
  String? _profileStatus;

  @override
  void initState() {
    super.initState();
    _checkAuthenticationState();
  }

  Future<void> _checkAuthenticationState() async {
    try {
      debugPrint('🔐 AuthWrapper: Checking authentication state...');
      
      // Get auth service from provider
      final authService = ref.read(authServiceProvider);
      
      // Check if user is authenticated
      final isAuthenticated = authService.isAuthenticated;
      
      debugPrint('🔐 AuthWrapper: User authenticated: $isAuthenticated');
      
      // User must be authenticated to proceed
      if (isAuthenticated) {
        // User is authenticated, check profile status
        try {
          final profileService = ref.read(profileCompletionServiceProvider);
          final profileStatus = await profileService.checkProfileCompleteness();
          
          debugPrint('🔐 AuthWrapper: Profile status: ${profileStatus.status}');
          
          setState(() {
            _isAuthenticated = true;
            _profileStatus = profileStatus.status.name.toUpperCase();
            _isLoading = false;
          });
        } catch (e) {
          debugPrint('❌ AuthWrapper: Error checking profile status: $e');
          // If profile check fails, treat as needs profile completion
          setState(() {
            _isAuthenticated = true;
            _profileStatus = 'PENDING_PROFILE';
            _isLoading = false;
          });
        }
      } else {
        // User is not authenticated
        debugPrint('🔐 AuthWrapper: User not authenticated');
        
        setState(() {
          _isAuthenticated = false;
          _profileStatus = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ AuthWrapper: Error checking authentication: $e');
      setState(() {
        _isAuthenticated = false;
        _profileStatus = null;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Not authenticated - show login screen directly
    if (!_isAuthenticated) {
      debugPrint('🔐 AuthWrapper: Showing login screen');
      return const LoginScreen();
    }

    // Authenticated - check profile status
    switch (_profileStatus) {
      case 'PENDINGPROFILE':
      case 'PENDING_PROFILE':
        debugPrint('🔐 AuthWrapper: Showing pending review screen (profile incomplete)');
        return const PendingReviewScreen();
      
      case 'PENDINGREVIEW':
      case 'PENDING_REVIEW':
        debugPrint('🔐 AuthWrapper: Showing pending review screen');
        return const PendingReviewScreen();
      
      case 'APPROVED':
      case 'ACTIVE':
        debugPrint('🔐 AuthWrapper: Showing home screen');
        return widget.authenticatedHome;
      
      default:
        // Unknown status - show pending review screen as default
        debugPrint('🔐 AuthWrapper: Unknown profile status: $_profileStatus, showing pending review screen');
        return const PendingReviewScreen();
    }
  }
}
