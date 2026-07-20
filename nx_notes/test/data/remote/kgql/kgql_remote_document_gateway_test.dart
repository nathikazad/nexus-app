import 'package:flutter_test/flutter_test.dart';
import 'package:nx_notes/data/document/fake_document_repository.dart';
import 'package:nx_notes/data/remote/kgql/kgql_remote_document_gateway.dart';

import '../../../support/contracts/remote_document_gateway_contract.dart';

void main() {
  group('KgqlRemoteDocumentGateway contract', () {
    runRemoteDocumentGatewayContract(
      createGateway: () async =>
          KgqlRemoteDocumentGateway(repository: FakeDocumentRepository()),
    );
  });
}
