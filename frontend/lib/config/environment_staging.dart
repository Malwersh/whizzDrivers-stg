// AWS Cognito environment configuration - STAGING
class Environment {
  // Environment flags
  static const bool isProduction = false;
  static String get environment => 'staging';

  // AWS Cognito Configuration - STAGING (will be created)
  static const String awsRegion = 'us-east-1';
  // TODO: Create WhizzDrivers-stg Cognito User Pool
  static const String cognitoUserPoolId = 'STAGING_POOL_TO_BE_CREATED';
  static const String cognitoUserPoolName = 'WhizzDrivers-stg';
  static const String cognitoAppClientId = 'STAGING_CLIENT_TO_BE_CREATED';

  // API endpoints - STAGING (will be created)
  static const String apiBaseUrl =
      'https://STAGING_API_GATEWAY.execute-api.us-east-1.amazonaws.com/stg';
  
  static const String ordersApiBaseUrl =
      'https://STAGING_ORDERS_API.execute-api.us-east-1.amazonaws.com/stg';

  // WebSocket URL - STAGING
  static String get webSocketUrl {
    return 'wss://STAGING_WS.execute-api.us-east-1.amazonaws.com/stg';
  }
  
  // Business ID (same as dev for now)
  static const String businessId = '7ccf646c-9594-48d4-8f63-c366d89257e5';

  // Live Chat Support WebSocket URL - STAGING
  static String get liveChatWebSocketUrl {
    return 'wss://STAGING_CHAT_WS.execute-api.us-east-1.amazonaws.com/stg';
  }

  // Chat Bridge API - STAGING
  static const String chatBridgeApiUrl =
      'https://STAGING_CHAT_API.execute-api.us-east-1.amazonaws.com/stg';
}
