abstract interface class LastOpenedDocumentStore {
  Future<int?> load(String accountKey);

  Future<void> save(String accountKey, int documentId);

  Future<void> clear(String accountKey);
}
