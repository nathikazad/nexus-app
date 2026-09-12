import 'dart:convert';
import 'dart:typed_data';
import 'package:nx_auth/nx_auth.dart';
import 'desires.dart';

class RemoteCollection extends HypnosisCollection {
  RemoteCollection(this.user, {NexusAuthenticatedClient? transport})
    : client =
          transport ??
          NexusAuthenticatedClient(preset: user.preset, userId: user.userId),
      super([], [], '');
  final User user;
  final NexusAuthenticatedClient client;
  Uri endpoint(String path) =>
      Uri.parse('${resolve(user.preset).imageHttp}$path');

  Future<void> refresh() async {
    final response = await client
        .get(endpoint('/hypnosis/collection'))
        .timeout(const Duration(seconds: 30));
    _accept(response.statusCode, response.body);
  }

  void _accept(int status, String body) {
    if (status != 200) {
      throw Exception(
        status == 401
            ? 'Please sign in again.'
            : 'Could not save or load your collection. Please try again.',
      );
    }
    final json = jsonDecode(body) as Map<String, dynamic>;
    final nextDesires = (json['desires'] as List)
        .map(
          (d) =>
              Desire(id: d['id'], title: d['title'], belief: d['belief'] ?? ''),
        )
        .toList();
    final nextTapes = (json['tapes'] as List)
        .map(
          (t) => Tape(
            id: t['id'],
            desireId: t['desire_id'],
            title: t['title'],
            story: t['story'] ?? '',
            prompt: t['prompt'] ?? '',
            audioAsset: (t['audio'] as Map?)?['link'] as String?,
          ),
        )
        .toList();
    desires
      ..clear()
      ..addAll(nextDesires);
    tapes
      ..clear()
      ..addAll(nextTapes);
  }

  Future<void> write(String kind, Map<String, dynamic> body) async {
    final response = await client
        .post(
          endpoint('/hypnosis/$kind'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));
    _accept(response.statusCode, response.body);
  }

  @override
  Future<Desire> saveDesire(String title, String belief, {String? id}) async {
    final previous = desires.map((d) => d.id).toSet();
    await write('desires', {'title': title, 'belief': belief, 'id': ?id});
    return id == null
        ? desires.firstWhere((d) => !previous.contains(d.id))
        : desire(id);
  }

  @override
  Future<Tape> createTape(String desireId, String title, String prompt) async {
    final previous = tapes.map((t) => t.id).toSet();
    await write('tapes', {
      'title': title,
      'desire_id': desireId,
      'prompt': prompt,
      'story': '',
    });
    return tapes.firstWhere((t) => !previous.contains(t.id));
  }

  @override
  Future<void> removeDesire(Desire item, {String? moveTo}) async {
    final response = await client
        .delete(
          endpoint('/hypnosis/desires'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({'id': item.id, 'move_to': ?moveTo}),
        )
        .timeout(const Duration(seconds: 30));
    _accept(response.statusCode, response.body);
  }

  Future<Uint8List> recording(Tape tape) async {
    final response = await client
        .get(endpoint(tape.audioAsset!))
        .timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) throw Exception('Could not load recording');
    return response.bodyBytes;
  }

  void dispose() => client.close();
}
