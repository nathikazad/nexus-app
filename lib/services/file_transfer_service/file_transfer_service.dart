import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:nexus_voice_assistant/services/file_transfer_service/file_transfer.dart';
import '../hardware_service/hardware_service.dart';
import '../logging_service.dart';

/// High-level file transfer service
/// Provides async API for file operations, converting callbacks to Futures
class FileTransferService {
  static final FileTransferService _instance = FileTransferService._internal();
  
  /// Singleton instance getter
  static FileTransferService get instance => _instance;
  
  factory FileTransferService() => _instance;
  
  FileTransferService._internal();
  
  Completer<List<FileEntry>>? _listFilesCompleter;
  Completer<FileEntry>? _fileReceivedCompleter;
  
  /// List files on device
  /// Returns a Future that completes when the file list is received
  Future<List<FileEntry>> listFiles({String? path}) async {
    if (_listFilesCompleter != null && !_listFilesCompleter!.isCompleted) {
      throw Exception('List files request already in progress');
    }
    
    _listFilesCompleter = Completer<List<FileEntry>>();
    
    // Send request through HardwareService
    if (path != null) {
      // For now, HardwareService only has sendListFilesRequest() without path
      // We'll need to add path support or handle it differently
      HardwareService.instance.sendListFilesRequest();
    } else {
      HardwareService.instance.sendListFilesRequest();
    }
    
    return _listFilesCompleter!.future;
  }
  
  /// Handle file list response (called by HardwareService)
  void onListFilesReceived(List<FileEntry> fileList) {
    if (_listFilesCompleter != null && !_listFilesCompleter!.isCompleted) {
      _listFilesCompleter!.complete(fileList);
      _listFilesCompleter = null;
    } else {
      LoggingService.instance.log('FileTransferService: Received file list but no completer waiting');
    }
  }
  
  /// Handle file received (called by HardwareService)
  void onFileReceived(FileEntry fileEntry) {
    if (_fileReceivedCompleter != null && !_fileReceivedCompleter!.isCompleted) {
      _fileReceivedCompleter!.complete(fileEntry);
      _fileReceivedCompleter = null;
    } else {
      LoggingService.instance.log('FileTransferService: Received file but no completer waiting');
    }
  }
  
  /// Request a specific file (for future use)
  Future<FileEntry> requestFile(String path) async {
    if (_fileReceivedCompleter != null && !_fileReceivedCompleter!.isCompleted) {
      throw Exception('File request already in progress');
    }
    
    _fileReceivedCompleter = Completer<FileEntry>();
    HardwareService.instance.sendFileRequest(path);
    
    return _fileReceivedCompleter!.future;
  }
}

