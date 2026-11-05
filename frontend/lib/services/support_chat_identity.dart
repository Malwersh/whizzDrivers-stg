import 'dart:async';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class SupportDriverIdentity {
  const SupportDriverIdentity(this.subject, {this.name = 'سائق'});
  final String subject;
  final String name;
}

abstract class SupportChatIdentitySource {
  Future<SupportDriverIdentity?> read();
  Future<String?> tokenFor(String subject);
  Stream<void> get invalidations;
}

/// Cached profile IDs and stored bearer strings never establish chat identity.
class AmplifySupportChatIdentitySource implements SupportChatIdentitySource {
  @override
  Future<SupportDriverIdentity?> read() async {
    final session = await Amplify.Auth.fetchAuthSession();
    if (session is! CognitoAuthSession || !session.isSignedIn) return null;
    final subject = session.userSubResult.value;
    var name = 'سائق';
    final attributes = await Amplify.Auth.fetchUserAttributes();
    for (final attribute in attributes) {
      if (attribute.userAttributeKey == AuthUserAttributeKey.name &&
          attribute.value.trim().isNotEmpty) {
        final value = attribute.value.trim();
        name = value.length > 100 ? value.substring(0, 100) : value;
      }
    }
    final user = await Amplify.Auth.getCurrentUser();
    if (subject.isEmpty || user.userId != subject) return null;
    return SupportDriverIdentity(subject, name: name);
  }

  @override
  Future<String?> tokenFor(String subject) async {
    try {
      var session = await Amplify.Auth.fetchAuthSession();
      if (session is! CognitoAuthSession ||
          !session.isSignedIn ||
          session.userSubResult.value != subject) {
        return null;
      }
      var token = session.userPoolTokensResult.value.accessToken.raw;
      if (!JwtDecoder.getExpirationDate(token)
          .isAfter(DateTime.now().add(const Duration(seconds: 60)))) {
        session = await Amplify.Auth.fetchAuthSession(
            options: const FetchAuthSessionOptions(forceRefresh: true));
        if (session is! CognitoAuthSession ||
            !session.isSignedIn ||
            session.userSubResult.value != subject) {
          return null;
        }
        token = session.userPoolTokensResult.value.accessToken.raw;
      }
      if (!JwtDecoder.getExpirationDate(token).isAfter(DateTime.now())) {
        return null;
      }
      return token;
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<void> get invalidations {
    late StreamController<void> events;
    StreamSubscription<dynamic>? hub;
    events = StreamController<void>(onListen: () {
      hub = Amplify.Hub.listen(HubChannel.Auth, (event) {
        if (['SIGNED_OUT', 'SIGNED_IN', 'SESSION_EXPIRED', 'USER_DELETED']
            .contains(event.eventName)) {
          events.add(null);
        }
      });
    }, onCancel: () async {
      await hub?.cancel();
    });
    return events.stream;
  }
}
