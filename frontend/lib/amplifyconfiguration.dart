// Amplify configuration for AWS Cognito User Pool Auth
// Staging drivers pool/client (created by drivers-api-staging stack)
const amplifyconfig = '''
{
  "UserAgent": "aws-amplify-flutter/2.0",
  "Version": "1.0",
  "auth": {
    "plugins": {
      "awsCognitoAuthPlugin": {
        "CognitoUserPool": {
          "Default": {
            "PoolId": "us-east-1_RGTqUXF5C",
            "AppClientId": "2d26d3muq0vvcuf42lkpgmkgsr",
            "Region": "us-east-1"
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
