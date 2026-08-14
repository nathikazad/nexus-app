import 'package:flutter_test/flutter_test.dart';
import 'package:nx_docs/sync/fake/fake_document_remote_api.dart';
import 'package:nx_docs/documents/document_models.dart';

import '../../support/contracts/document_remote_api_contract.dart';
import '../../support/offline_fixtures.dart';

void main() {
  group('FakeDocumentRemoteApi contract', () {
    runDocumentRemoteApiContract(
      createApi: () async =>
          FakeDocumentRemoteApi(documents: <NxDocument>[offlineTestDocument()]),
    );
  });
}
