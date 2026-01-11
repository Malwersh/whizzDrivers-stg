import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/cognito_auth_service_enhanced.dart';

// Simple provider for CognitoAuthServiceEnhanced without riverpod_annotation dependency
final cognitoAuthServiceSimpleProvider = Provider<CognitoAuthServiceEnhanced>((ref) {
  return CognitoAuthServiceEnhanced();
});
