import 'package:flutter_test/flutter_test.dart';
import 'package:nx_docs/documents/data/fake/fake_document_repository.dart';
import 'package:nx_docs/sync/fake/fake_document_remote_api.dart';
import 'package:nx_docs/sync/remote/repository_document_remote_api.dart';

import '../../support/contracts/document_remote_api_contract.dart';

void main() {
  group('RepositoryDocumentRemoteApi contract', () {
    runDocumentRemoteApiContract(
      createApi: () async => RepositoryDocumentRemoteApi(
        repository: FakeDocumentRepository(),
        syncTransport: FakeDocumentRemoteApi(),
      ),
    );
  });
}
