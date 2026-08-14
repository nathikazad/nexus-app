import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:nx_db/auth.dart';
import 'package:nx_docs/publishing/data/kgql_mirror_publish_trigger.dart';
import 'package:nx_docs/publishing/document_publish_service.dart';
import 'package:nx_docs/sync/sync_providers.dart';
import 'package:nx_docs/workspace/workspace_providers.dart';

final mirrorPublishTriggerProvider = Provider<MirrorPublishTrigger?>((ref) {
  final user = ref.watch(authProvider).value;
  if (user == null) {
    return null;
  }
  final client = http.Client();
  ref.onDispose(client.close);
  return MirrorPublishTriggerService(
    baseUrl: resolve(user.preset).imageHttp,
    userId: user.userId,
    client: client,
  );
});

final documentPublishServiceProvider = Provider<DocumentPublishService?>((ref) {
  final workspace = ref.watch(documentWorkspaceProvider);
  if (workspace == null) return null;
  return DocumentPublishService(
    workspace: workspace,
    clock: ref.watch(offlineClockProvider),
    trigger: ref.watch(mirrorPublishTriggerProvider),
  );
});
