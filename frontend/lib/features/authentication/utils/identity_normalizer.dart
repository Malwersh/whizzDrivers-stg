// filepath: lib/features/authentication/utils/identity_normalizer.dart
// Utility helpers for normalizing phone numbers & emails + hashing (non-PII logging)

import 'dart:convert';
import 'package:crypto/crypto.dart';

class IdentityNormalizer {
  /// Normalize email: trim, lowercase.
  static String normalizeEmail(String email) {
    return email.trim().toLowerCase();
  }

  /// Normalize Iraqi phone numbers into E.164 (+9647XXXXXXXXX)
  /// Accepts inputs like: 07XX XXX XXXX, +964 7XX..., 7XXXXXXXXX
  static String normalizeIraqiPhone(String input) {
    var digits = input.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.startsWith('+964')) {
      digits = digits.replaceAll(' ', '');
      return digits; // assume already correct length (13 chars) validation external
    }
    // remove leading zeros / plus
    digits = digits.replaceFirst(RegExp(r'^0+'), '');
    if (!digits.startsWith('7')) {
      // If user omitted leading 7, leave as is (will fail validation upstream)
      return '+964$digits';
    }
    return '+964$digits';
  }

  /// Basic validation helpers
  static bool isValidEmail(String email) {
    final e = normalizeEmail(email);
    return RegExp(r'^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$').hasMatch(e);
  }

  static bool isValidIraqiPhone(String phone) {
    final p = normalizeIraqiPhone(phone);
    // Accept both 07XXXXXXXXX and +9647XXXXXXXXX formats
    return RegExp(r'^(07[0-9]{9}|\+9647[0-9]{9})$').hasMatch(p);
  }

  /// Produce a stable SHA256 hash for non-PII logging correlation
  static String hashIdentity(String identity) {
    final normalized = identity.trim().toLowerCase();
    final bytes = utf8.encode(normalized);
    return sha256.convert(bytes).toString().substring(0, 16); // short hash
  }

  /// General normalize function that auto-detects email vs phone
  static String normalize(String identity) {
    if (identity.contains('@')) {
      return hashIdentity(normalizeEmail(identity));
    } else {
      return hashIdentity(normalizeIraqiPhone(identity));
    }
  }
}
