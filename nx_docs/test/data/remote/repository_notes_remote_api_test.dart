import 'package:flutter_test/flutter_test.dart';
import 'package:nx_docs/data/document/fake_document_repository.dart';
import 'package:nx_docs/data/remote/fake/fake_notes_remote_api.dart';
import 'package:nx_docs/data/remote/repository_notes_remote_api.dart';

import '../../support/contracts/notes_remote_api_contract.dart';

void main() {
  group('RepositoryNotesRemoteApi contract', () {
    runNotesRemoteApiContract(
      createApi: () async => RepositoryNotesRemoteApi(
        repository: FakeDocumentRepository(),
        syncTransport: FakeNotesRemoteApi(),
      ),
    );
  });
}
