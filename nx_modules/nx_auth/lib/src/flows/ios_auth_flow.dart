import 'package:oidc/oidc.dart';

/// iOS owns its ASWebAuthenticationSession callback. Token exchange and
/// state/nonce/PKCE validation remain inside the OIDC manager.
class IosAuthFlow {
  const IosAuthFlow();

  static const options = OidcNativeOptionsApple(
    callbackMode: OidcAppleCallbackMode.customScheme,
    flowTimeoutSeconds: 300,
  );

  Future<OidcUser?> authorize(OidcUserManager manager, String? loginHint) =>
      manager.loginAuthorizationCodeFlow(loginHint: loginHint);
}
