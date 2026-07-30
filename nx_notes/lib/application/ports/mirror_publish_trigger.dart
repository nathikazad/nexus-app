abstract interface class MirrorPublishTrigger {
  Future<void> trigger({
    required String reason,
    required int documentId,
    required bool immediate,
    bool waitForCompletion = false,
  });
}
