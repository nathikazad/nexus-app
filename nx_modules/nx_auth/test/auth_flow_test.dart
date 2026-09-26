import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:oidc/oidc.dart';
import 'package:nx_auth/src/flows/auth_flow.dart';

class MockManager extends Mock implements OidcUserManager {}

void main() {
  test('web wins over the browser operating system', () {
    for (final target in TargetPlatform.values) {
      expect(
        authFlowPlatform(isWeb: true, target: target),
        AuthFlowPlatform.web,
      );
    }
    expect(
      authFlowPlatform(isWeb: false, target: TargetPlatform.iOS),
      AuthFlowPlatform.ios,
    );
    expect(
      authFlowPlatform(isWeb: false, target: TargetPlatform.android),
      AuthFlowPlatform.android,
    );
    expect(
      authFlowPlatform(isWeb: false, target: TargetPlatform.macOS),
      AuthFlowPlatform.desktop,
    );
  });

  test(
    'Android, web and desktop options exactly match the previous configuration',
    () {
      const previous = OidcPlatformSpecificOptions(
        android: OidcNativeOptionsAndroid(
          preferredBrowserPackages: ['com.android.chrome'],
          flowTimeoutSeconds: 300,
        ),
      );
      final before = previous.toJson()..remove('ios');
      final after = nexusAuthFlowOptions.toJson()..remove('ios');
      expect(after, before);
      expect(
        nexusAuthFlowOptions.ios.callbackMode,
        OidcAppleCallbackMode.customScheme,
      );
      expect(nexusAuthFlowOptions.ios.flowTimeoutSeconds, 300);
      expect(
        nexusAuthFlowOptions.ios.prefersEphemeralWebBrowserSession,
        isFalse,
      );
    },
  );

  for (final platform in AuthFlowPlatform.values) {
    test(
      '$platform retains OIDC validation and cancellation semantics',
      () async {
        final manager = MockManager();
        when(
          () => manager.loginAuthorizationCodeFlow(loginHint: 'person'),
        ).thenAnswer((_) async => null);
        expect(await authorizeForPlatform(platform, manager, 'person'), isNull);
        verify(
          () => manager.loginAuthorizationCodeFlow(loginHint: 'person'),
        ).called(1);
        when(
          () => manager.loginAuthorizationCodeFlow(loginHint: 'person'),
        ).thenThrow(StateError('invalid state'));
        await expectLater(
          () => authorizeForPlatform(platform, manager, 'person'),
          throwsStateError,
        );
      },
    );
  }
}
