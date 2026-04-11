import 'dart:io';

import 'package:nx_db/nx_db.dart';

/// Live GraphQL at [resolve](BackendPreset.laptop) — `http://127.0.0.1:5001/graphql`.
class TestAuthController extends AuthController {
  @override
  Future<User?> build() async {
    return User(userId: '1', preset: BackendPreset.laptop);
  }
}

bool get runExpenseIntegration =>
    Platform.environment['RUN_EXPENSE_INTEGRATION'] == 'true';

const kExpenseIntegrationSkipReason =
    'Set RUN_EXPENSE_INTEGRATION=true and run PGDB on localhost (see test/README.md)';
