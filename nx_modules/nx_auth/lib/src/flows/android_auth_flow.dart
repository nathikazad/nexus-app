import 'package:oidc/oidc.dart';

/// Prefer Chrome when available; native code falls back to other browsers.
class AndroidAuthFlow {
  const AndroidAuthFlow();

  static const options = OidcNativeOptionsAndroid(
    preferredBrowserPackages: ['com.android.chrome'],
    flowTimeoutSeconds: 300,
  );

  Future<OidcUser?> authorize(OidcUserManager manager, String? loginHint) =>
      manager.loginAuthorizationCodeFlow(loginHint: loginHint);
}
