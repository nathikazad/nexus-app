import 'package:nx_docs/domain/document/document_identity.dart';

enum OfflineCapabilityDecision { allowed, requiresNetwork, waitingForIdentity }

class OfflineCapabilityPolicy {
  const OfflineCapabilityPolicy();

  OfflineCapabilityDecision linkDocuments(
    DocumentKey source,
    DocumentKey target,
  ) {
    if (source.remoteId == null || target.remoteId == null) {
      return OfflineCapabilityDecision.waitingForIdentity;
    }
    return OfflineCapabilityDecision.allowed;
  }

  OfflineCapabilityDecision publish({required bool online}) => online
      ? OfflineCapabilityDecision.allowed
      : OfflineCapabilityDecision.requiresNetwork;
}
