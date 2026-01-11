import 'package:flutter/material.dart';

/// Smart input detection utility for email and phone numbers
class SmartInputDetector {
  /// Determines if input is an email or phone number
  /// Returns 'email', 'phone', or 'unknown'
  static String detectInputType(String input) {
    if (input.trim().isEmpty) return 'unknown';

    final trimmedInput = input.trim();

    // Check if it's an email
    if (isEmail(trimmedInput)) {
      return 'email';
    }

    // Check if it's an Iraqi phone number
    if (isIraqiPhone(trimmedInput)) {
      return 'phone';
    }

    return 'unknown';
  }

  /// Check if input is a valid email address
  static bool isEmail(String input) {
    return RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(input);
  }

  /// Check if input is a valid Iraqi phone number
  static bool isIraqiPhone(String input) {
    // Clean input - remove spaces and special characters except +
    String cleanPhone = input.replaceAll(RegExp(r'[^\d+]'), '');

    // Check various Iraqi phone formats:
    // 07XXXXXXXXX (11 digits starting with 07)
    // +9647XXXXXXXXX (starts with +964 followed by 7 and 9 digits)
    // 9647XXXXXXXXX (starts with 964 followed by 7 and 9 digits)

    if (RegExp(r'^07[0-9]{9}$').hasMatch(cleanPhone)) {
      return true;
    }

    if (RegExp(r'^\+9647[0-9]{9}$').hasMatch(cleanPhone)) {
      return true;
    }

    if (RegExp(r'^9647[0-9]{9}$').hasMatch(cleanPhone)) {
      return true;
    }

    return false;
  }

  /// Get appropriate keyboard type based on detected input
  static TextInputType getKeyboardType(String inputType) {
    switch (inputType) {
      case 'email':
        return TextInputType.emailAddress;
      case 'phone':
        return TextInputType.phone;
      default:
        return TextInputType.text;
    }
  }

  /// Get appropriate icon based on detected input
  static IconData getIcon(String inputType) {
    switch (inputType) {
      case 'email':
        return Icons.email;
      case 'phone':
        return Icons.phone;
      default:
        return Icons.person;
    }
  }

  /// Get appropriate hint text based on detected input
  static String getHintText(String inputType) {
    switch (inputType) {
      case 'email':
        return 'example@domain.com';
      case 'phone':
        return '07XX XXX XXXX';
      default:
        return 'البريد الإلكتروني أو رقم الهاتف';
    }
  }

  /// Get appropriate label text based on detected input
  static String getLabelText(String inputType) {
    switch (inputType) {
      case 'email':
        return 'البريد الإلكتروني';
      case 'phone':
        return 'رقم الهاتف';
      default:
        return 'البريد الإلكتروني أو رقم الهاتف';
    }
  }

  /// Validate input based on detected type
  static String? validateInput(String input, String inputType) {
    if (input.trim().isEmpty) {
      return 'يرجى إدخال البريد الإلكتروني أو رقم الهاتف';
    }

    switch (inputType) {
      case 'email':
        if (!isEmail(input)) {
          return 'البريد الإلكتروني غير صحيح';
        }
        break;
      case 'phone':
        if (!isIraqiPhone(input)) {
          return 'رقم الهاتف غير صحيح (مثال: 07XXXXXXXXX)';
        }
        break;
      case 'unknown':
        return 'يرجى إدخال بريد إلكتروني صحيح أو رقم هاتف عراقي';
    }

    return null;
  }

  /// Normalize phone number for processing
  static String normalizePhone(String phone) {
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');

    // Convert to +964 format
    if (cleanPhone.startsWith('07')) {
      return '+964${cleanPhone.substring(1)}';
    } else if (cleanPhone.startsWith('7') && cleanPhone.length == 10) {
      return '+964$cleanPhone';
    } else if (cleanPhone.startsWith('9647')) {
      return '+$cleanPhone';
    }

    return cleanPhone;
  }
}
