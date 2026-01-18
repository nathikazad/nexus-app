import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/log_entry.dart';

class LoggingService {
  static final LoggingService _instance = LoggingService._internal();
  factory LoggingService() => _instance;
  LoggingService._internal();

  static LoggingService get instance => _instance;

  static const int _maxInMemoryLogs = 100;
  static const String _logFileName = 'logs.json';

  final List<LogEntry> _logs = [];
  final StreamController<LogEntry> _logStreamController = StreamController<LogEntry>.broadcast();
  File? _logFile;
  bool _isInitialized = false;
  final Queue<LogEntry> _writeQueue = Queue<LogEntry>();
  bool _isWriting = false;

  Stream<LogEntry> get logStream => _logStreamController.stream;
  List<LogEntry> get recentLogs => List.unmodifiable(_logs);

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      _logFile = File('${directory.path}/$_logFileName');

      // Load existing logs from file
      if (await _logFile!.exists()) {
        await _loadLogsFromFile();
      }

      _isInitialized = true;
      log('LoggingService initialized');
    } catch (e) {
      debugPrint('Error initializing LoggingService: $e');
    }
  }

  Future<void> _loadLogsFromFile() async {
    try {
      final content = await _logFile!.readAsString();
      if (content.isEmpty) return;

      final List<dynamic> jsonList = jsonDecode(content);
      final loadedLogs = jsonList.map((json) => LogEntry.fromJson(json)).toList();

      // Keep only the last _maxInMemoryLogs in memory
      _logs.clear();
      final startIndex = loadedLogs.length > _maxInMemoryLogs
          ? loadedLogs.length - _maxInMemoryLogs
          : 0;
      _logs.addAll(loadedLogs.sublist(startIndex));
    } catch (e) {
      debugPrint('Error loading logs from file: $e');
    }
  }

  void log(String message) {
    if (!_isInitialized) {
      debugPrint('LoggingService not initialized, falling back to debugPrint: $message');
      return;
    }

    final entry = LogEntry(
      timestamp: DateTime.now(),
      message: message,
    );

    debugPrint('LoggingService: $message');

    // Add to in-memory buffer (keep last 100)
    _logs.add(entry);
    if (_logs.length > _maxInMemoryLogs) {
      _logs.removeAt(0);
    }

    // Emit to stream for real-time updates
    _logStreamController.add(entry);

    // Queue for file write
    _writeQueue.add(entry);
    _flushWriteQueue();
  }

  Future<void> _flushWriteQueue() async {
    if (_isWriting || _writeQueue.isEmpty || _logFile == null) return;

    _isWriting = true;

    try {
      // Read existing logs
      List<LogEntry> existingLogs = [];
      if (await _logFile!.exists()) {
        try {
          final content = await _logFile!.readAsString();
          if (content.isNotEmpty) {
            final List<dynamic> jsonList = jsonDecode(content);
            existingLogs = jsonList.map((json) => LogEntry.fromJson(json)).toList();
          }
        } catch (e) {
          debugPrint('Error reading existing logs: $e');
        }
      }

      // Add queued logs
      while (_writeQueue.isNotEmpty) {
        existingLogs.add(_writeQueue.removeFirst());
      }

      // Write back to file
      final jsonList = existingLogs.map((entry) => entry.toJson()).toList();
      await _logFile!.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error writing logs to file: $e');
    } finally {
      _isWriting = false;

      // If more logs were added while writing, flush again
      if (_writeQueue.isNotEmpty) {
        _flushWriteQueue();
      }
    }
  }

  Future<void> clearLogs() async {
    _logs.clear();
    _writeQueue.clear();

    if (_logFile != null && await _logFile!.exists()) {
      await _logFile!.writeAsString('[]');
    }

    log('Logs cleared');
  }

  Future<void> dispose() async {
    await _flushWriteQueue();
    await _logStreamController.close();
  }
}

