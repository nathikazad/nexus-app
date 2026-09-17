import 'package:image_picker/image_picker.dart' show XFile;
import 'package:crypto/crypto.dart';
import 'package:nx_offline/nx_offline.dart';
import 'package:nx_offline/nx_offline_storage.dart';
import 'expense_store.dart';
import 'expense_transport.dart';
import 'expense_data_repository.dart';

class ExpenseReceipts {
  ExpenseReceipts(
    this.remote,
    this.domainId, {
    this.store,
    this.files,
    this.onPending,
  });
  final ExpenseTransport remote;
  final int domainId;
  final ExpenseStore? store;
  final BinaryContentFiles? files;
  final void Function()? onPending;
  final Map<String, Map<String, String>> _webPending = {};

  Future<Map<String, dynamic>> add({
    required List<int> bytes,
    required String filename,
    required String contentType,
    required DateTime capturedAt,
    required String timezone,
  }) async {
    if (bytes.isEmpty || bytes.length > 20 * 1024 * 1024) {
      throw ArgumentError('Receipt must be smaller than 20 MB');
    }
    final operation = expenseOperationId();
    // Timeline timestamps are local wall-clock, not UTC instants.
    final local = DateTime(
      capturedAt.year,
      capturedAt.month,
      capturedAt.day,
      capturedAt.hour,
      capturedAt.minute,
      capturedAt.second,
      capturedAt.millisecond,
      capturedAt.microsecond,
    ).toIso8601String();
    if (store == null) {
      final key = '${sha256.convert(bytes)}:$filename:$contentType';
      final pending = _webPending.putIfAbsent(
        key,
        () => {
          'operation': operation,
          'captured_at': local,
          'timezone': timezone,
        },
      );
      final result = await remote.uploadReceipt(
        operationId: pending['operation']!,
        domainId: domainId,
        capturedAt: pending['captured_at']!,
        timezone: pending['timezone']!,
        filename: filename,
        contentType: contentType,
        bytes: bytes,
      );
      _webPending.remove(key);
      return result;
    }
    final reference = await files!.write(
      'receipts',
      operation,
      '.bin',
      Stream.value(bytes),
    );
    final entity = <String, dynamic>{
      'id': 'receipt:$operation',
      'kind': 'event',
      'event_id': 'pending:$operation',
      'event_time': local,
      'event_type': 'image',
      'source': 'expense_app',
      'links': <dynamic>[],
      'payload': {
        'local_reference': reference.encode(),
        'filename': filename,
        'timezone': timezone,
      },
      'pending': true,
    };
    await store!.enqueue(
      operationId: operation,
      localId: 'receipt:$operation',
      command: {
        '_receipt': true,
        'reference': reference.encode(),
        'captured_at': local,
        'timezone': timezone,
        'filename': filename,
        'content_type': contentType,
      },
      optimistic: entity,
      now: DateTime.now().toUtc(),
    );
    onPending?.call();
    return {'status': 'queued', 'entity': entity};
  }
}

class ExpenseReceiptHandler implements MutationHandler {
  ExpenseReceiptHandler(this.store, this.remote, this.files);
  final ExpenseStore store;
  final ExpenseTransport remote;
  final BinaryContentFiles files;
  @override
  String get collection => 'expense_receipt';
  @override
  Future<MutationReceipt> execute(PendingMutation mutation) async {
    final command = mutation.payload['command'] as Map;
    final reference = BinaryContentReference.decode(
      command['reference'] as String,
    );
    if (!await files.verify(reference)) {
      throw const SyncTransportException(
        SyncFailure(
          kind: SyncFailureKind.validation,
          message: 'Receipt file is missing or damaged. Reattach it.',
        ),
      );
    }
    final bytes = await XFile(await files.localPath(reference)).readAsBytes();
    final result = await remote.uploadReceipt(
      operationId: mutation.operationId,
      domainId: store.account.domainId,
      capturedAt: command['captured_at'] as String,
      timezone: command['timezone'] as String,
      filename: command['filename'] as String,
      contentType: command['content_type'] as String,
      bytes: bytes,
    );
    return MutationReceipt(
      operationId: mutation.operationId,
      entityKey: EntityKey(localId: mutation.payload['local_id']! as String),
      revision: const Revision('uploaded'),
      metadata: {'result': result},
    );
  }
}
