import 'package:flutter/foundation.dart';
import 'package:oidc/oidc.dart';

import 'android_auth_flow.dart';
import 'ios_auth_flow.dart';
import 'web_auth_flow.dart';

enum AuthFlowPlatform { ios, android, web, desktop }

AuthFlowPlatform authFlowPlatform({
  required bool isWeb,
  required TargetPlatform target,
}) {
  if (isWeb) return AuthFlowPlatform.web;
  return switch (target) {
    TargetPlatform.iOS => AuthFlowPlatform.ios,
    TargetPlatform.android => AuthFlowPlatform.android,
    _ => AuthFlowPlatform.desktop,
  };
}

AuthFlowPlatform get currentAuthFlowPlatform =>
    authFlowPlatform(isWeb: kIsWeb, target: defaultTargetPlatform);

const nexusAuthFlowOptions = OidcPlatformSpecificOptions(
  ios: IosAuthFlow.options,
  android: AndroidAuthFlow.options,
  web: WebAuthFlow.options,
);

Future<OidcUser?> authorizeForPlatform(
  AuthFlowPlatform platform,
  OidcUserManager manager,
  String? loginHint,
) => switch (platform) {
  AuthFlowPlatform.ios => const IosAuthFlow().authorize(manager, loginHint),
  AuthFlowPlatform.android => const AndroidAuthFlow().authorize(
    manager,
    loginHint,
  ),
  AuthFlowPlatform.web => const WebAuthFlow().authorize(manager, loginHint),
  AuthFlowPlatform.desktop => manager.loginAuthorizationCodeFlow(
    loginHint: loginHint,
  ),
};
