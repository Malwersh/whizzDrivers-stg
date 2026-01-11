/// Environment setup shim for offline mode. AWS/Firebase removed.
class EnvironmentSetup {
  /// No-op legacy method kept for compatibility.
  static Future<void> enableAWSCognito() async {
    // Deprecated: AWS Cognito disabled. No action required.
  }

  /// No-op legacy method kept for compatibility.
  static Future<void> enableMockMode() async {
    // Mock mode is the default globally; nothing to do here.
  }

  static Future<void> printStatus() async {}
  static Future<void> quickSetup() async {}
}
