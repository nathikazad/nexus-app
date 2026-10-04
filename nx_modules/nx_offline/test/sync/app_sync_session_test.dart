import 'package:flutter_test/flutter_test.dart';
import 'package:nx_offline/nx_offline.dart';

void main() {
  test('offline exposes the shared hierarchy protocol', () async {
    final session = AppSyncSession(
      request: (_, _) async => {'status': 'unsupported'},
    );
    await expectLater(session.manifest(), throwsStateError);
  });
}
