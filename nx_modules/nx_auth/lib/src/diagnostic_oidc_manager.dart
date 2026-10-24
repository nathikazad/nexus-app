import 'package:oidc/oidc.dart';

import 'session_availability.dart';

/// Retains safe reasons when the OIDC library returns null for invalid claims.
/// Validation and persistence remain entirely with the library.
class DiagnosticOidcUserManager extends OidcUserManager {
  DiagnosticOidcUserManager.lazy({
    required super.discoveryDocumentUri,
    required super.clientCredentials,
    required super.store,
    required super.settings,
    super.id,
  }) : super.lazy();

  final validationReasons = <String>{};

  @override
  List<Exception> validateUser({
    required OidcUser user,
    required OidcProviderMetadata metadata,
    String? authorizationCode,
    Duration? maxAge,
  }) {
    final errors = super.validateUser(
      user: user,
      metadata: metadata,
      authorizationCode: authorizationCode,
      maxAge: maxAge,
    );
    validationReasons.addAll(
      errors.map((e) => authValidationReason(e.toString())),
    );
    return errors;
  }
}
