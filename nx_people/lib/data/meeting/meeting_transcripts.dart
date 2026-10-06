import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_people/data/sync/people_sync_providers.dart';

class MeetingTranscriptState {
  const MeetingTranscriptState(this.rows, {this.connected = false});
  final List<Map<String, dynamic>> rows;
  final bool connected;
}

/// The transport uses the same authenticated, domain-bound client as app sync.
/// Cached snapshots live in the existing server/user/domain storage partition.
class MeetingTranscripts {
  MeetingTranscripts({
    required this.fetch,
    required this.subscribe,
    required this.readCache,
    required this.writeCache,
    this.retryDelay = const Duration(seconds: 5),
    this.refreshInterval = const Duration(seconds: 20),
  });
  final Future<List<Map<String, dynamic>>> Function(int) fetch;
  final Stream<List<Map<String, dynamic>>> Function(int) subscribe;
  final Future<List<Map<String, dynamic>>?> Function(int) readCache;
  final Future<void> Function(int, List<Map<String, dynamic>>) writeCache;
  final Duration retryDelay, refreshInterval;

  Stream<MeetingTranscriptState> watch(int id) {
    late StreamController<MeetingTranscriptState> output;
    StreamSubscription<List<Map<String, dynamic>>>? subscription;
    Timer? retry, refresh;
    var stopped = false;
    var fetching = false;
    var version = 0;
    var rows = <Map<String, dynamic>>[];
    Future<void> writes = Future.value();
    void emit(bool connected) {
      if (!stopped) {
        output.add(MeetingTranscriptState(rows, connected: connected));
      }
    }

    void accept(List<Map<String, dynamic>> value) {
      if (stopped) return;
      version++;
      rows = value;
      emit(true);
      // Serialize writes so an earlier snapshot cannot overwrite a later one.
      writes = writes
          .then((_) => stopped ? null : writeCache(id, value))
          .catchError((Object _) {});
    }

    Future<void> load() async {
      if (stopped || fetching) return;
      fetching = true;
      final before = version;
      try {
        final value = await fetch(id);
        if (!stopped && version == before) accept(value);
      } catch (_) {
        if (version == before) emit(false);
      } finally {
        fetching = false;
      }
    }

    void connect() {
      if (stopped) return;
      void disconnected() {
        if (stopped) return;
        emit(false);
        if (retry?.isActive ?? false) return;
        retry = Timer(retryDelay, () async {
          await subscription?.cancel();
          connect();
          unawaited(load());
        });
      }

      try {
        subscription = subscribe(id).listen(
          accept,
          onError: (Object _) => disconnected(),
          onDone: disconnected,
        );
      } catch (_) {
        disconnected();
      }
    }

    output = StreamController<MeetingTranscriptState>(
      onListen: () async {
        try {
          rows = await readCache(id) ?? rows;
        } catch (_) {}
        if (stopped) return;
        emit(false);
        connect();
        unawaited(load());
        refresh = Timer.periodic(refreshInterval, (_) => unawaited(load()));
      },
      onCancel: () async {
        stopped = true;
        retry?.cancel();
        refresh?.cancel();
        await subscription?.cancel();
        await writes;
      },
    );
    return output.stream;
  }
}

List<Map<String, dynamic>> transcriptRows(dynamic value) => (value as List)
    .map((row) => Map<String, dynamic>.from(row as Map))
    .toList();

final meetingTranscriptsRepositoryProvider = Provider<MeetingTranscripts>((
  ref,
) {
  final client = ref.watch(graphqlClientProvider);
  final store = ref.watch(peopleOfflineStoreProvider);
  return MeetingTranscripts(
    fetch: (id) async {
      final result = await client
          .query(
            QueryOptions(
              document: gql(r'''
        query($id:Int!){meetingTranscripts(meetingId:$id)}
      '''),
              variables: {'id': id},
              fetchPolicy: FetchPolicy.noCache,
            ),
          )
          .timeout(const Duration(seconds: 15));
      if (result.hasException) throw result.exception!;
      return transcriptRows(result.data!['meetingTranscripts']);
    },
    subscribe: (id) => client
        .subscribe(
          SubscriptionOptions(
            document: gql(r'''
      subscription($id:Int!){meetingTranscriptsChanged(meetingId:$id)}
    '''),
            variables: {'id': id},
            fetchPolicy: FetchPolicy.noCache,
          ),
        )
        .map((result) {
          if (result.hasException) throw result.exception!;
          final snapshot = result.data?['meetingTranscriptsChanged'];
          if (snapshot is! Map || snapshot['status'] != 'ready') {
            throw StateError('Transcript connection interrupted');
          }
          return transcriptRows(snapshot['transcripts']);
        }),
    readCache: (id) async {
      if (store == null) return null;
      final raw = await store.library.read('meeting_transcripts', '$id');
      return raw == null ? null : transcriptRows(jsonDecode(raw));
    },
    writeCache: (id, rows) async {
      if (store != null) {
        await store.library.saveRemote(
          'meeting_transcripts',
          '$id',
          jsonEncode(rows),
        );
      }
    },
  );
});

final meetingTranscriptsProvider = StreamProvider.autoDispose
    .family<MeetingTranscriptState, int>(
      (ref, id) => ref.watch(meetingTranscriptsRepositoryProvider).watch(id),
    );
