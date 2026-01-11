// AWS Cognito environment configuration
class Environment {
  // Environment flags
  static const bool isProduction =
      bool.fromEnvironment('IS_PRODUCTION', defaultValue: false);
  static const String environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'staging',
  );

  // Temporary testing: fixed coordinates (match dev testing behavior)
  // Disable for real launch by setting: --dart-define=USE_TEST_LOCATION=false
  static const bool useTestLocation =
      bool.fromEnvironment('USE_TEST_LOCATION', defaultValue: true);
  static final double testLatitude =
      double.tryParse(const String.fromEnvironment('TEST_LATITUDE', defaultValue: '31.913292')) ??
      31.913292;
  static final double testLongitude =
      double.tryParse(const String.fromEnvironment('TEST_LONGITUDE', defaultValue: '44.476014')) ??
      44.476014;

  // AWS Cognito Configuration - Updated for dedicated drivers pool
  static const String awsRegion =
      String.fromEnvironment('AWS_REGION', defaultValue: 'us-east-1');
  static const String cognitoUserPoolId = String.fromEnvironment(
      'COGNITO_USER_POOL_ID',
      defaultValue: 'us-east-1_RGTqUXF5C');
  static const String cognitoUserPoolName = String.fromEnvironment(
      'COGNITO_USER_POOL_NAME',
      defaultValue: 'WhizzDrivers-users-staging');
  static const String cognitoUserPoolArn =
      String.fromEnvironment('COGNITO_USER_POOL_ARN', defaultValue: '');

  // App Client ID from Cognito User Pool: WhizzDrivers-Client-dev
  static const String cognitoAppClientId = String.fromEnvironment(
      'COGNITO_APP_CLIENT_ID',
      defaultValue: '2d26d3muq0vvcuf42lkpgmkgsr');

  // AWS Access Keys for services like SNS
  static const String awsAccessKeyId = String.fromEnvironment(
      'AWS_ACCESS_KEY_ID',
      defaultValue: 'YOUR_AWS_ACCESS_KEY_ID');
  static const String awsSecretAccessKey = String.fromEnvironment(
      'AWS_SECRET_ACCESS_KEY',
      defaultValue: 'YOUR_AWS_SECRET_ACCESS_KEY');

  // API endpoints (update these with your actual backend URLs when available)
  static const String apiBaseUrl = String.fromEnvironment('DRIVER_API_BASE_URL',
      defaultValue:
          'https://6ogrj6so22.execute-api.us-east-1.amazonaws.com/staging');

  // Orders API (separate for orders functionality)
  static const String ordersApiBaseUrl = String.fromEnvironment(
      'ORDERS_API_BASE_URL',
      defaultValue:
          'https://6ogrj6so22.execute-api.us-east-1.amazonaws.com/staging');

  // Wallet service API
  static const String walletApiBaseUrl = String.fromEnvironment(
      'WALLET_API_BASE_URL',
      defaultValue:
          'https://z14s5f8oxh.execute-api.us-east-1.amazonaws.com/staging');

  // Document upload API
  static const String documentUploadApiBaseUrl = String.fromEnvironment(
      'DOCUMENT_UPLOAD_API_BASE_URL',
      defaultValue:
          'https://6ogrj6so22.execute-api.us-east-1.amazonaws.com/staging');

  // Trips API
  static const String tripsApiBaseUrl = String.fromEnvironment(
      'TRIPS_API_BASE_URL',
      defaultValue:
          'https://6ogrj6so22.execute-api.us-east-1.amazonaws.com/staging');

  // 🔧 FIXED: Use the SAME WebSocket endpoint as working WizzUser app
  static const String webSocketUrl = String.fromEnvironment('DRIVER_WS_URL',
      defaultValue:
          'wss://igcrhwc84c.execute-api.us-east-1.amazonaws.com/staging');

  // Business ID for WebSocket connection
  static const String businessId = String.fromEnvironment('BUSINESS_ID',
      defaultValue: '7ccf646c-9594-48d4-8f63-c366d89257e5');

  // Live Chat Support WebSocket URL (no authentication parameters - uses JWT in headers)
  static const String liveChatWebSocketUrl = String.fromEnvironment(
      'LIVE_CHAT_WS_URL',
      defaultValue:
          'wss://igcrhwc84c.execute-api.us-east-1.amazonaws.com/staging');

  // Chat Bridge API for support agent communication (PRODUCTION READY - API KEY ENDPOINT)
  static const String chatBridgeApiUrl = String.fromEnvironment(
      'CHAT_BRIDGE_API_URL',
      defaultValue:
          'https://6ogrj6so22.execute-api.us-east-1.amazonaws.com/staging/api');

    // CentralPlatform Push Notifications API
    static const String centralPushApiBaseUrl = String.fromEnvironment(
        'CENTRAL_PUSH_API_BASE_URL',
        defaultValue:
                'https://x066k4dftk.execute-api.us-east-1.amazonaws.com/staging',
    );

  // Regional defaults
  static const String defaultCountryCode = '+964';
  static const String defaultLanguage = 'ar';
  static const String defaultTimezone = 'Asia/Baghdad';

  // API endpoints
  static String get authEndpoint => '$apiBaseUrl/auth';
  static String get ordersEndpoint => '$apiBaseUrl/orders';
  static String get driversEndpoint => '$apiBaseUrl/drivers';
  static String get notificationsEndpoint => '$apiBaseUrl/notifications';

  static void validateOrThrow() {
    final missing = <String>[];

    void requireNonEmpty(String key, String value) {
      if (value.trim().isEmpty) missing.add(key);
    }

    requireNonEmpty('COGNITO_USER_POOL_ID', cognitoUserPoolId);
    requireNonEmpty('COGNITO_APP_CLIENT_ID', cognitoAppClientId);
    requireNonEmpty('DRIVER_API_BASE_URL', apiBaseUrl);
    requireNonEmpty('ORDERS_API_BASE_URL', ordersApiBaseUrl);
    requireNonEmpty('WALLET_API_BASE_URL', walletApiBaseUrl);
    requireNonEmpty('DOCUMENT_UPLOAD_API_BASE_URL', documentUploadApiBaseUrl);
    requireNonEmpty('TRIPS_API_BASE_URL', tripsApiBaseUrl);
    requireNonEmpty('DRIVER_WS_URL', webSocketUrl);
    requireNonEmpty('LIVE_CHAT_WS_URL', liveChatWebSocketUrl);
    requireNonEmpty('CHAT_BRIDGE_API_URL', chatBridgeApiUrl);
    requireNonEmpty('BUSINESS_ID', businessId);

    if (missing.isNotEmpty) {
      throw StateError(
        'Missing required dart-define(s): ${missing.join(', ')}\n'
        'Provide them via: flutter run --dart-define=KEY=value ...',
      );
    }

    const forbidden = '/dev';
    final bad = <String, String>{
      'DRIVER_API_BASE_URL': apiBaseUrl,
      'ORDERS_API_BASE_URL': ordersApiBaseUrl,
      'WALLET_API_BASE_URL': walletApiBaseUrl,
      'DOCUMENT_UPLOAD_API_BASE_URL': documentUploadApiBaseUrl,
      'TRIPS_API_BASE_URL': tripsApiBaseUrl,
      'DRIVER_WS_URL': webSocketUrl,
      'LIVE_CHAT_WS_URL': liveChatWebSocketUrl,
      'CHAT_BRIDGE_API_URL': chatBridgeApiUrl,
    };

    final offenders = bad.entries
        .where((e) => e.value.contains(forbidden))
        .map((e) => e.key)
        .toList();
    if (offenders.isNotEmpty) {
      throw StateError(
        'Staging config contains forbidden "/dev" in: ${offenders.join(', ')}',
      );
    }
  }
}
