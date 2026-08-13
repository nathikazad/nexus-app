import 'dart:io';

Future<List<int>> readNxDocumentImageFileBytes(String path) {
  return File(path).readAsBytes();
}
