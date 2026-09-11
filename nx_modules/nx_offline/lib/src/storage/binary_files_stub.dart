import 'binary_files.dart';

class ApplicationBinaryContentFiles implements BinaryContentFiles {
  ApplicationBinaryContentFiles(String account);

  Never _unsupported() =>
      throw UnsupportedError('Binary offline files require a native platform');

  @override
  Future<String> localPath(BinaryContentReference reference) async =>
      _unsupported();
  @override
  Future<bool> verify(BinaryContentReference reference) async => _unsupported();
  @override
  Future<BinaryContentReference> write(
    String collection,
    String item,
    String extension,
    Stream<List<int>> bytes,
  ) async => _unsupported();
}

class DirectoryBinaryContentFilesImpl implements DirectoryBinaryContentFiles {
  DirectoryBinaryContentFilesImpl(String rootPath);

  Never _unsupported() =>
      throw UnsupportedError('Binary offline files require a native platform');
  @override
  Future<String> localPath(BinaryContentReference reference) async =>
      _unsupported();
  @override
  Future<bool> verify(BinaryContentReference reference) async => _unsupported();
  @override
  Future<BinaryContentReference> write(
    String collection,
    String item,
    String extension,
    Stream<List<int>> bytes,
  ) async => _unsupported();
}
