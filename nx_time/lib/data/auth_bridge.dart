/// Re-exports auth and client symbols from `nx_db` so `features/` can avoid
/// importing `package:nx_db/nx_db.dart` directly (layering rule).
library;

export 'package:nx_db/nx_db.dart' show
    AuthController,
    BackendPreset,
    GraphQLConfig,
    User,
    authProvider,
    endpointProvider,
    graphqlClientProvider,
    imageBaseUrlProvider,
    sockWsUrlProvider;
