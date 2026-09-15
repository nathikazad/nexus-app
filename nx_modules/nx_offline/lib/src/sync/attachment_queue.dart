import 'dart:async';

/// Bounded file work, isolated from catalog requests. One slot remains available
/// for user-requested files while background hydration is running.
final class AttachmentQueue {
  AttachmentQueue({this.concurrency = 3}) : assert(concurrency >= 2);
  final int concurrency;
  final Map<String, _AttachmentJob> _jobs = {};
  int _running = 0;
  int _background = 0;
  bool _closed = false;

  Future<T> run<T>(
    String key,
    Future<T> Function() work, {
    bool foreground = false,
  }) {
    if (_closed) return Future.error(StateError('File queue closed'));
    final existing = _jobs[key];
    if (existing != null) {
      if (foreground && !existing.started) existing.foreground = true;
      _pump();
      return existing.result.future.then((value) => value as T);
    }
    final job = _AttachmentJob(() async => await work(), foreground);
    _jobs[key] = job;
    _pump();
    return job.result.future.then((value) => value as T);
  }

  void _pump() {
    while (!_closed && _running < concurrency) {
      final waiting =
          _jobs.entries.where((entry) => !entry.value.started).toList()..sort(
            (a, b) => (b.value.foreground ? 1 : 0).compareTo(
              a.value.foreground ? 1 : 0,
            ),
          );
      if (waiting.isEmpty) return;
      final entry = waiting.first;
      final job = entry.value;
      if (!job.foreground && _background >= concurrency - 1) return;
      job.started = true;
      _running++;
      if (!job.foreground) _background++;
      unawaited(_execute(entry.key, job));
    }
  }

  Future<void> _execute(String key, _AttachmentJob job) async {
    try {
      job.result.complete(await job.work());
    } catch (error, stack) {
      job.result.completeError(error, stack);
    } finally {
      _jobs.remove(key);
      _running--;
      if (!job.foreground) _background--;
      _pump();
    }
  }

  Future<void> close() async {
    _closed = true;
    final active = <Future<void>>[];
    for (final job in _jobs.values.toList()) {
      if (!job.started)
        job.result.completeError(StateError('File queue closed'));
      active.add(job.result.future.then<void>((_) {}, onError: (Object _) {}));
    }
    await Future.wait(active);
  }
}

final class _AttachmentJob {
  _AttachmentJob(this.work, this.foreground);
  final Future<Object?> Function() work;
  bool foreground;
  bool started = false;
  final result = Completer<Object?>();
}
