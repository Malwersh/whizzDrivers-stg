import 'package:flutter_test/flutter_test.dart';

import '../lib/config/environment.dart';

void main() {
  test('driver build uses services from its configured environment', () {
    Environment.validateOrThrow();
    if (Environment.isProduction) {
      expect(Environment.environment, 'production');
      expect(Environment.cognitoUserPoolId, Environment.productionPoolId);
      expect(Environment.cognitoAppClientId, Environment.productionClientId);
      expect(Environment.apiBaseUrl, Environment.productionProfileUrl);
      expect(Environment.documentUploadApiBaseUrl,
          Environment.productionProfileUrl);
      expect(
          Environment.driverSearchApiBaseUrl, Environment.productionSearchUrl);
      expect(
          Environment.driverOffersApiBaseUrl, Environment.productionOffersUrl);
      expect(Environment.supportChatWebSocketUrl,
          Environment.productionSupportSocket);
      expect(Environment.walletApiBaseUrl, Environment.productionWalletUrl);
      expect(Environment.tripsApiBaseUrl, Environment.productionSearchUrl);
    } else {
      expect(Environment.environment, 'staging');
      expect(Uri.parse(Environment.apiBaseUrl).path, '/staging');
      expect(Uri.parse(Environment.tripsApiBaseUrl).path, '/staging');
      expect(Uri.parse(Environment.supportChatWebSocketUrl).path, '/staging');
    }
  });
}
