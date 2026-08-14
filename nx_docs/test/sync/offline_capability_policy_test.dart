import 'package:flutter_test/flutter_test.dart';
import 'package:nx_docs/sync/offline_capability_policy.dart';
import 'package:nx_docs/documents/document_models.dart';

void main() {
  const policy = OfflineCapabilityPolicy();

  test('link waits until both local documents have remote identities', () {
    expect(
      policy.linkDocuments(
        const DocumentKey(localId: 'source'),
        const DocumentKey(localId: 'target', remoteId: 2),
      ),
      OfflineCapabilityDecision.waitingForIdentity,
    );
    expect(
      policy.linkDocuments(
        const DocumentKey(localId: 'source', remoteId: 1),
        const DocumentKey(localId: 'target', remoteId: 2),
      ),
      OfflineCapabilityDecision.allowed,
    );
  });

  test('publishing remains explicitly online-only', () {
    expect(
      policy.publish(online: false),
      OfflineCapabilityDecision.requiresNetwork,
    );
    expect(policy.publish(online: true), OfflineCapabilityDecision.allowed);
  });
}
