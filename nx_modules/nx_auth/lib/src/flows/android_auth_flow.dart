import 'package:oidc/oidc.dart';

/// Preserve the verified Chrome Auth Tab / native receiver behavior.
class AndroidAuthFlow {
  const AndroidAuthFlow();

  static const options = OidcNativeOptionsAndroid(
    preferredBrowserPackages: ['com.android.chrome'],
    flowTimeoutSeconds: 300,
  );

  Future<OidcUser?> authorize(OidcUserManager manager, String? loginHint) =>
      manager.loginAuthorizationCodeFlow(loginHint: loginHint);
}
