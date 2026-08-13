import 'package:flutter_test/flutter_test.dart';
import 'package:nx_docs/data/remote/fake/fake_notes_remote_api.dart';
import 'package:nx_docs/domain/document/document.dart';

import '../../../support/contracts/notes_remote_api_contract.dart';
import '../../../support/offline_fixtures.dart';

void main() {
  group('FakeNotesRemoteApi contract', () {
    runNotesRemoteApiContract(
      createApi: () async =>
          FakeNotesRemoteApi(documents: <NxDocument>[offlineTestDocument()]),
    );
  });
}
