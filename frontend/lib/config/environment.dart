// AWS Cognito environment configuration
class Environment {
  // Environment flags
  static const _productionFlag = bool.fromEnvironment('IS_PRODUCTION');
  static const _environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'staging',
  );
  static const bool isProduction =
      _productionFlag || _environment == 'production' || _environment == 'prod';
  static const String environment = isProduction ? 'production' : _environment;

  // GPS is the default. A fixed position requires explicit staging opt-in
  // plus TEST_LOCATION_DRIVER_ID matching the signed-in test driver.
  static const bool useTestLocation =
      bool.fromEnvironment('USE_TEST_LOCATION', defaultValue: false);
  static const String testLocationDriverId =
      String.fromEnvironment('TEST_LOCATION_DRIVER_ID', defaultValue: '');
  static final double testLatitude = double.tryParse(
          const String.fromEnvironment('TEST_LATITUDE',
              defaultValue: '31.913292')) ??
      31.913292;
  static final double testLongitude = double.tryParse(
          const String.fromEnvironment('TEST_LONGITUDE',
              defaultValue: '44.476014')) ??
      44.476014;

  static const productionPoolId = 'us-east-1_5sUT54eCB';
  static const productionClientId = '59to4hbat3lv2fvosa49afu0gi';

  // AWS Cognito Configuration - Updated for dedicated drivers pool
  static const String awsRegion =
      String.fromEnvironment('AWS_REGION', defaultValue: 'us-east-1');
  static const String cognitoUserPoolId = String.fromEnvironment(
      'COGNITO_USER_POOL_ID',
      defaultValue: isProduction ? productionPoolId : 'us-east-1_RGTqUXF5C');
  static const String cognitoUserPoolName = String.fromEnvironment(
      'COGNITO_USER_POOL_NAME',
      defaultValue: isProduction
          ? 'wizz-production-driver'
          : 'WhizzDrivers-users-staging');
  static const String cognitoUserPoolArn =
      String.fromEnvironment('COGNITO_USER_POOL_ARN', defaultValue: '');

  // App Client ID from Cognito User Pool: WhizzDrivers-Client-dev
  static const String cognitoAppClientId = String.fromEnvironment(
      'COGNITO_APP_CLIENT_ID',
      defaultValue:
          isProduction ? productionClientId : '2d26d3muq0vvcuf42lkpgmkgsr');

  // AWS Access Keys for services like SNS
  static const String awsAccessKeyId = String.fromEnvironment(
      'AWS_ACCESS_KEY_ID',
      defaultValue: 'YOUR_AWS_ACCESS_KEY_ID');
  static const String awsSecretAccessKey = String.fromEnvironment(
      'AWS_SECRET_ACCESS_KEY',
      defaultValue: 'YOUR_AWS_SECRET_ACCESS_KEY');

  static const productionProfileUrl =
      'https://kq49g7b6wa.execute-api.us-east-1.amazonaws.com/production';
  static const productionSearchUrl =
      'https://ojicbq2eff.execute-api.us-east-1.amazonaws.com/production';
  static const productionOffersUrl =
      'https://5o8l5l0p54.execute-api.us-east-1.amazonaws.com/production';
  static const productionWalletUrl =
      'https://44rmfvjxp8.execute-api.us-east-1.amazonaws.com/production';
  static const productionOrderSocket =
      'wss://9plheg8f1h.execute-api.us-east-1.amazonaws.com/production';
  static const productionSupportSocket =
      'wss://x7o502lmzk.execute-api.us-east-1.amazonaws.com/production';
  static const productionSupportAttachments =
      'https://rdrpzzb1kc.execute-api.us-east-1.amazonaws.com/production/support/attachments';
  static const productionPushUrl =
      'https://zfpd4wpdrf.execute-api.us-east-1.amazonaws.com/production';

  static const _stagingDriverApi =
      'https://6ogrj6so22.execute-api.us-east-1.amazonaws.com/staging';
  static const _stagingOrderSocket =
      'wss://igcrhwc84c.execute-api.us-east-1.amazonaws.com/staging';
  static const bool usesProductionEndpoints = isProduction;

  static const String apiBaseUrl = String.fromEnvironment('DRIVER_API_BASE_URL',
      defaultValue: isProduction ? productionProfileUrl : _stagingDriverApi);
  static const String driverSearchApiBaseUrl =
      isProduction ? productionSearchUrl : apiBaseUrl;
  static const String driverOffersApiBaseUrl =
      isProduction ? productionOffersUrl : apiBaseUrl;
  static const String ordersApiBaseUrl = String.fromEnvironment(
    'ORDERS_API_BASE_URL',
    defaultValue: isProduction ? productionOffersUrl : _stagingDriverApi,
  );
  static const String walletApiBaseUrl = String.fromEnvironment(
    'WALLET_API_BASE_URL',
    defaultValue: isProduction
        ? productionWalletUrl
        : 'https://z14s5f8oxh.execute-api.us-east-1.amazonaws.com/staging',
  );
  static const String documentUploadApiBaseUrl = String.fromEnvironment(
    'DOCUMENT_UPLOAD_API_BASE_URL',
    defaultValue: isProduction ? productionProfileUrl : _stagingDriverApi,
  );
  static const String tripsApiBaseUrl = String.fromEnvironment(
    'TRIPS_API_BASE_URL',
    defaultValue: isProduction ? productionSearchUrl : _stagingDriverApi,
  );
  static const String webSocketUrl = String.fromEnvironment(
    'DRIVER_WS_URL',
    defaultValue: isProduction ? productionOrderSocket : _stagingOrderSocket,
  );
  static const String businessId = String.fromEnvironment(
    'BUSINESS_ID',
    defaultValue: isProduction ? '' : '7ccf646c-9594-48d4-8f63-c366d89257e5',
  );
  static const String liveChatWebSocketUrl = String.fromEnvironment(
    'LIVE_CHAT_WS_URL',
    defaultValue: isProduction ? productionSupportSocket : _stagingOrderSocket,
  );
  static const String chatBridgeApiUrl = String.fromEnvironment(
    'CHAT_BRIDGE_API_URL',
    defaultValue: isProduction ? '' : '$_stagingDriverApi/api',
  );
  static const String supportChatWebSocketUrl = String.fromEnvironment(
    'SUPPORT_CHAT_WS_URL',
    defaultValue: isProduction
        ? productionSupportSocket
        : environment == 'staging'
            ? 'wss://vzvnqu5jhl.execute-api.us-east-1.amazonaws.com/staging'
            : '',
  );
  static const String supportAttachmentsUrl = String.fromEnvironment(
    'SUPPORT_ATTACHMENTS_API_URL',
    defaultValue: isProduction
        ? productionSupportAttachments
        : environment == 'staging'
            ? 'https://5ytyphpnkc.execute-api.us-east-1.amazonaws.com/staging/support/attachments'
            : '',
  );
  static const String centralPushApiBaseUrl = String.fromEnvironment(
    'CENTRAL_PUSH_API_BASE_URL',
    defaultValue: isProduction
        ? productionPushUrl
        : 'https://x066k4dftk.execute-api.us-east-1.amazonaws.com/staging',
  );
  static const String pushDeviceRegistryBaseUrl =
      isProduction ? productionPushUrl : centralPushApiBaseUrl;

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
    if (isProduction) {
      if (cognitoUserPoolId != productionPoolId ||
          cognitoAppClientId != productionClientId ||
          awsRegion != 'us-east-1' ||
          useTestLocation) {
        throw StateError(
            'Invalid production driver identity or location configuration');
      }
      const productionBindings = {
        'DRIVER_API_BASE_URL': (apiBaseUrl, productionProfileUrl),
        'ORDERS_API_BASE_URL': (ordersApiBaseUrl, productionOffersUrl),
        'DOCUMENT_UPLOAD_API_BASE_URL': (
          documentUploadApiBaseUrl,
          productionProfileUrl
        ),
        'TRIPS_API_BASE_URL': (tripsApiBaseUrl, productionSearchUrl),
        'WALLET_API_BASE_URL': (walletApiBaseUrl, productionWalletUrl),
        'DRIVER_WS_URL': (webSocketUrl, productionOrderSocket),
        'LIVE_CHAT_WS_URL': (liveChatWebSocketUrl, productionSupportSocket),
        'SUPPORT_CHAT_WS_URL': (
          supportChatWebSocketUrl,
          productionSupportSocket
        ),
        'SUPPORT_ATTACHMENTS_API_URL': (
          supportAttachmentsUrl,
          productionSupportAttachments
        ),
        'CENTRAL_PUSH_API_BASE_URL': (centralPushApiBaseUrl, productionPushUrl),
      };
      final invalid = productionBindings.entries
          .where((entry) => entry.value.$1 != entry.value.$2)
          .map((entry) => entry.key)
          .toList();
      if (chatBridgeApiUrl.isNotEmpty) invalid.add('CHAT_BRIDGE_API_URL');
      if (invalid.isNotEmpty) {
        throw StateError(
            'Invalid production driver bindings: ${invalid.join(', ')}');
      }
      return;
    }

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
