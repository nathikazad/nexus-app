class FileEntry {
  final String name;
  final int size;
  final bool isDirectory;
  
  FileEntry({
    required this.name,
    required this.size,
    required this.isDirectory,
  });
  
  @override
  String toString() {
    return '${isDirectory ? "[DIR]" : "[FILE]"} $name ($size bytes)';
  }
}

