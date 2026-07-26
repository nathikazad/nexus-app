import 'package:nx_notes/application/ports/clock.dart';
import 'package:nx_notes/application/ports/id_generator.dart';
import 'package:nx_notes/application/ports/local_notes_store.dart';
import 'package:nx_notes/application/ports/remote_document_gateway.dart';
import 'package:nx_notes/application/sync/notes_sync_engine.dart';
import 'package:nx_notes/data/sync/nx_offline_notes_sync_engine.dart';
import 'package:nx_offline/nx_offline.dart' as offline;

NotesSyncEngine createOfflineTestSyncEngine({
  required LocalNotesStore localStore,
  required RemoteDocumentGateway remoteGateway,
  required Clock clock,
  required IdGenerator idGenerator,
}) {
  final separator = localStore.accountKey.indexOf(':');
  if (separator <= 0 || separator == localStore.accountKey.length - 1) {
    throw StateError('invalid Notes test account key');
  }
  return NxOfflineNotesSyncEngine(
    localStore: localStore,
    remoteGateway: remoteGateway,
    account: offline.AccountScope(
      backend: localStore.accountKey.substring(0, separator),
      userId: localStore.accountKey.substring(separator + 1),
      application: 'nx_notes',
    ),
    clock: clock,
    idGenerator: idGenerator,
  );
}
