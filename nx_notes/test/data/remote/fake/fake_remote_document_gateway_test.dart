import 'package:flutter_test/flutter_test.dart';
import 'package:nx_notes/data/remote/fake/fake_remote_document_gateway.dart';

import '../../../support/contracts/remote_document_gateway_contract.dart';

void main() {
  group('FakeRemoteDocumentGateway contract', () {
    runRemoteDocumentGatewayContract(
      createGateway: () async => FakeRemoteDocumentGateway(),
    );
  });
}
