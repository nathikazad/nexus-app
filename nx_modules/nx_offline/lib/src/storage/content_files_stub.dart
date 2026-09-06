import 'content_files.dart';

class ApplicationContentFiles implements ContentFiles {
  ApplicationContentFiles(String account);
  @override
  Future<bool> exists(String reference) => Future.value(false);
  @override
  Future<String> write(String collection, String item, String content) =>
      Future.error(UnsupportedError('Native content storage is unavailable'));
  @override
  Future<String> read(String reference) =>
      Future.error(UnsupportedError('Native content storage is unavailable'));
}
