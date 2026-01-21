import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:nexus_voice_assistant/services/logging_service.dart';
import 'package:nexus_voice_assistant/models/log_entry.dart';

class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({super.key});

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<LogEntry>? _logSubscription;
  List<LogEntry> _logs = [];
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    _loadInitialLogs();
    _subscribeToLogStream();
  }

  void _loadInitialLogs() {
    setState(() {
      _logs = List.from(LoggingService.instance.recentLogs);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _subscribeToLogStream() {
    _logSubscription = LoggingService.instance.logStream.listen((entry) {
      if (mounted) {
        setState(() {
          _logs.add(entry);
          // Keep only last 100 logs in the viewer
          if (_logs.length > 100) {
            _logs.removeAt(0);
          }
        });
        if (_autoScroll) {
          _scrollToBottom();
        }
      }
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final second = timestamp.second.toString().padLeft(2, '0');
    final millisecond = timestamp.millisecond.toString().padLeft(3, '0');
    return '$hour:$minute:$second.$millisecond';
  }

  Future<void> _clearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Logs'),
        content: const Text('Are you sure you want to clear all logs?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await LoggingService.instance.clearLogs();
      setState(() {
        _logs.clear();
      });
    }
  }

  Future<void> _shareLogs() async {
    try {
      final logFilePath = await LoggingService.instance.getLogFilePath();
      if (logFilePath == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Log file not available')),
          );
        }
        return;
      }

      final logFile = File(logFilePath);
      if (!await logFile.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Log file does not exist')),
          );
        }
        return;
      }

      // Share the file via AirDrop (or other sharing options)
      await Share.shareXFiles(
        [XFile(logFilePath)],
        subject: 'Nexus App Logs',
        text: 'Logs exported from Nexus Voice Assistant',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing logs: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _logSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Viewer'),
        actions: [
          IconButton(
            icon: Icon(_autoScroll ? Icons.vertical_align_bottom : Icons.vertical_align_center),
            tooltip: _autoScroll ? 'Auto-scroll enabled' : 'Auto-scroll disabled',
            onPressed: () {
              setState(() {
                _autoScroll = !_autoScroll;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              _loadInitialLogs();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear logs',
            onPressed: _clearLogs,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share logs (AirDrop)',
            onPressed: _shareLogs,
          ),
        ],
      ),
      body: _logs.isEmpty
          ? const Center(
              child: Text(
                'No logs available',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final entry = _logs[index];
                return _LogEntryWidget(
                  entry: entry,
                  formatTimestamp: _formatTimestamp,
                );
              },
            ),
    );
  }
}

class _LogEntryWidget extends StatelessWidget {
  final LogEntry entry;
  final String Function(DateTime) formatTimestamp;

  const _LogEntryWidget({
    required this.entry,
    required this.formatTimestamp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              formatTimestamp(entry.timestamp),
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: Colors.blue[900],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.message,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

