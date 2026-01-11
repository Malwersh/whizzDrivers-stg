// Central Platform Live Chat Configuration
// This solves the JWT User Pool mismatch issue

import 'environment.dart';

class CentralPlatformConfig {
  // Central Platform Cognito Configuration
  static const String region = String.fromEnvironment('CENTRAL_PLATFORM_REGION', defaultValue: 'us-east-1');
  static const String userPoolId =
    String.fromEnvironment('CENTRAL_PLATFORM_USER_POOL_ID', defaultValue: '');
  static const String clientId =
    String.fromEnvironment('CENTRAL_PLATFORM_CLIENT_ID', defaultValue: '');
  static const String identityPoolId =
    String.fromEnvironment('CENTRAL_PLATFORM_IDENTITY_POOL_ID', defaultValue: '');

  // WebSocket Configuration - TEMPORARY: using customer/business WebSocket for testing
  static String get webSocketUrl => Environment.liveChatWebSocketUrl;
  static String get businessId => Environment.businessId;

  // Amplify configuration for Central Platform
  static const String amplifyConfig =
      '''
{
  "UserAgent": "aws-amplify-flutter/2.0",
  "Version": "1.0",
  "auth": {
    "plugins": {
      "awsCognitoAuthPlugin": {
        "CognitoUserPool": {
          "Default": {
            "PoolId": "$userPoolId",
            "AppClientId": "$clientId",
            "Region": "$region"
          }
        },
        "Auth": {
          "Default": {
            "authenticationFlowType": "USER_SRP_AUTH",
            "socialProviders": [],
            "usernameAttributes": ["email"],
            "signupAttributes": ["email"],
            "passwordProtectionSettings": {
              "passwordPolicyMinLength": 8,
              "passwordPolicyCharacters": []
            },
            "mfaConfiguration": "OFF",
            "mfaTypes": ["SMS"],
            "verificationMechanisms": ["email"]
          }
        }
      }
    }
  }
}
''';
}
