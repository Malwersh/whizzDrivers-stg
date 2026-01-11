// Amplify configuration for AWS Cognito User Pool Auth
// Updated to match hadhir-phone-only-pool with hadhir-phone-app-client
import 'environment.dart';

const amplifyconfig = '''
{
  "UserAgent": "aws-amplify-flutter/2.0",
  "Version": "1.0",
  "auth": {
    "plugins": {
      "awsCognitoAuthPlugin": {
        "CognitoUserPool": {
          "Default": {
            "PoolId": "${Environment.cognitoUserPoolId}",
            "AppClientId": "${Environment.cognitoAppClientId}",
            "Region": "${Environment.awsRegion}"
          }
        },
        "Auth": {
          "Default": {
            "authenticationFlowType": "USER_SRP_AUTH",
            "socialProviders": [],
            "usernameAttributes": ["email", "phone_number"],
            "signupAttributes": ["email", "phone_number"],
            "passwordProtectionSettings": {
              "passwordPolicyMinLength": 8,
              "passwordPolicyCharacters": []
            },
            "mfaConfiguration": "OFF",
            "mfaTypes": ["SMS"],
            "verificationMechanisms": ["email", "phone_number"]
          }
        }
      }
    }
  }
}
''';
