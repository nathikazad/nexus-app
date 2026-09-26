# Platform authentication flows

The shared service selects a platform entry point in `lib/src/flows/`.
Web detection takes precedence over the browser's operating system.

- **iOS:** `ios_auth_flow.dart` owns ASWebAuthenticationSession settings,
  explicitly captures the app's custom callback scheme, and bounds the native
  wait to five minutes. Browser SSO remains enabled.
- **Android:** `android_auth_flow.dart` preserves the existing Chrome selection,
  five-minute timeout, and OIDC plugin receiver. Native Android code is unchanged.
- **Web:** `web_auth_flow.dart` preserves default browser navigation and the
  existing `auth.html` handshake. Callback HTML is unchanged.
- **Desktop:** continues using the previous OIDC manager defaults.

All entry points still delegate state, nonce, PKCE, token validation and token
exchange to the OIDC manager. Identity checks, storage namespaces, provider
configuration and server endpoints remain shared and unchanged. Do not parse
an arbitrary deep link into a signed-in session.

NX Main's iOS navigation keeps one router alive across authentication updates.
Its login route hosts `DomainSessionGate`, so an authenticated identity without
a selected domain gets the picker rather than another login form. The iOS
Info.plist disables Flutter's competing deep-link handler; the native OIDC
session owns authentication callbacks. Android and web routing is unchanged.
This follows Flutter's [plugin-owned deep-link guidance](https://docs.flutter.dev/ui/navigation/deep-linking).

Regression coverage: `nx_auth/test/auth_flow_test.dart` checks platform
selection, unchanged non-iOS options and error/cancellation propagation.
`nx_main/test/features/auth/ios_auth_navigation_test.dart` checks router
lifetime, navigation gating and the domain picker. These are automated checks,
not proof of a live provider callback on every device.

On 2026-09-26, the 28 NX Auth tests and three NX Main iOS navigation tests
passed, along with targeted static analysis. Shorebird release
`1.0.21+20260927` was built and installed on Nathik's iPhone. After launch the
physical phone displayed “Choose a domain” with Home and Nathik memberships,
confirming a restored authenticated identity and successful membership loading.
The old app had routed that state back to Login. Fresh provider authentication
and entry into the workspace after domain selection have not yet been observed.
