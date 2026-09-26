import 'package:nx_db/auth.dart';

/// iOS returns from the system authentication sheet to the existing login
/// screen. Keep it mounted while the callback/token exchange is pending, and
/// present domain selection before entering any application data route.
String? iosAuthRedirect({
  required String location,
  required bool bootstrapping,
  required AppStatus status,
}) {
  if (bootstrapping || status == AppStatus.initializing) {
    if (location == '/login' || location == '/splash') return null;
    return '/splash';
  }
  if (status == AppStatus.authenticated) {
    return location == '/login' || location == '/splash' ? '/' : null;
  }
  // /login hosts DomainSessionGate on iOS, so selectingDomain displays the
  // membership picker instead of starting another authentication request.
  return location == '/login' ? null : '/login';
}
