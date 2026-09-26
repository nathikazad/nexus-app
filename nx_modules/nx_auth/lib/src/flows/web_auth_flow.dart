import 'package:oidc/oidc.dart';

/// Preserve the web plugin defaults and existing auth.html callback handshake.
class WebAuthFlow {
  const WebAuthFlow();

  static const options = OidcPlatformSpecificOptions_Web();

  Future<OidcUser?> authorize(OidcUserManager manager, String? loginHint) =>
      manager.loginAuthorizationCodeFlow(loginHint: loginHint);
}
