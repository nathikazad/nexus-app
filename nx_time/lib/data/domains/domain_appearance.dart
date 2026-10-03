import 'dart:convert';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_time/data/providers.dart';
import 'package:nx_time/data/domains/domain_workspace.dart';

const domainPreferencesKey = 'domains';

class DomainAppearance {
  const DomainAppearance({
    required this.label,
    this.description = '',
    required this.accent,
    required this.secondary,
  });
  final String label, description;
  final Color accent, secondary;
  static const palette = [
    Color(0xFF5275A5),
    Color(0xFF398477),
    Color(0xFF9270A6),
    Color(0xFFB48148),
    Color(0xFFB4697C),
    Color(0xFF617C92),
  ];
  static DomainAppearance defaults(String name, int index) => DomainAppearance(
    label: name,
    accent: palette[index % palette.length],
    secondary: Color.lerp(palette[index % palette.length], Colors.white, 0.35)!,
  );
  factory DomainAppearance.read(Object? value, DomainAppearance fallback) {
    final map = value is Map ? value : const {};
    Color parse(Object? hex, Color fallback) =>
        hex is String && RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)
        ? Color(0xFF000000 | int.parse(hex.substring(1), radix: 16))
        : fallback;
    return DomainAppearance(
      label:
          map['label'] is String && (map['label'] as String).trim().isNotEmpty
          ? map['label']
          : fallback.label,
      description: map['description'] is String ? map['description'] : '',
      accent: parse(map['accent'], fallback.accent),
      secondary: parse(map['secondary_accent'], fallback.secondary),
    );
  }
  Map<String, dynamic> toJson() => {
    'label': label,
    'description': description,
    'accent': hex(accent),
    'secondary_accent': hex(secondary),
  };
  static String hex(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

Map<String, dynamic> mergeDomainAppearance(
  Map<String, dynamic> root,
  int id,
  DomainAppearance appearance,
) {
  final domains = root[domainPreferencesKey];
  final entries = domains is Map
      ? Map<String, dynamic>.from(domains)
      : <String, dynamic>{};
  final old = entries['$id'];
  entries['$id'] = {
    if (old is Map) ...Map<String, dynamic>.from(old),
    ...appearance.toJson(),
  };
  return {...root, domainPreferencesKey: entries};
}

DomainAppearance domainAppearance(WidgetRef ref, int? id) {
  final w = ref.watch(timeDomainsProvider).asData?.value;
  final ordered = w?.memberships.toList() ?? [];
  ordered.sort(
    (a, b) => a.id == w?.personalId
        ? -1
        : b.id == w?.personalId
        ? 1
        : a.id.compareTo(b.id),
  );
  final index = ordered.indexWhere((d) => d.id == id);
  return ref.watch(domainAppearancesProvider).asData?.value[id] ??
      DomainAppearance.defaults(
        index < 0 ? 'Domain' : ordered[index].name,
        index < 0 ? 0 : index,
      );
}

Future<Map<String, dynamic>> readDomainPreferenceRoot(
  GraphQLClient client,
  int userId,
) async {
  final result = await client.query(
    QueryOptions(
      document: gql(
        r'query DomainPreferences($id:Int!){allUsers(condition:{id:$id},first:1){nodes{id preferences}}}',
      ),
      variables: {'id': userId},
      fetchPolicy: FetchPolicy.networkOnly,
    ),
  );
  if (result.hasException) throw result.exception!;
  final nodes = result.data?['allUsers']?['nodes'] as List?;
  if (nodes == null || nodes.isEmpty || nodes.first is! Map)
    throw StateError('Account preferences are unavailable');
  final raw = nodes.first['preferences'];
  final value = raw is String ? jsonDecode(raw) : raw;
  return value is Map ? Map<String, dynamic>.from(value) : {};
}

Future<void> writeDomainPreferenceRoot(
  GraphQLClient client,
  int userId,
  Map<String, dynamic> root,
) async {
  final result = await client.mutate(
    MutationOptions(
      document: gql(
        r'mutation DomainPreferences($id:Int!,$preferences:JSON){updateUserById(input:{id:$id,userPatch:{preferences:$preferences}}){user{id}}}',
      ),
      variables: {'id': userId, 'preferences': root},
    ),
  );
  if (result.hasException) throw result.exception!;
  if (result.data?['updateUserById']?['user'] == null)
    throw StateError('Preferences were not saved');
}

/// Root user preferences; initialize only missing domain entries.
final domainPreferenceRootProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  final w = await ref.watch(timeDomainsProvider.future);
  final client = w.clients[w.personalId]!;
  final userId = int.parse(w.user.userId);
  var root = await readDomainPreferenceRoot(client, userId);
  final existing = root[domainPreferencesKey];
  final ordered = w.memberships.toList()
    ..sort(
      (a, b) => a.id == w.personalId
          ? -1
          : b.id == w.personalId
          ? 1
          : a.id.compareTo(b.id),
    );
  var changed = false;
  for (var i = 0; i < ordered.length; i++) {
    final id = ordered[i].id;
    if (existing is Map && existing['$id'] is Map) continue;
    root = mergeDomainAppearance(
      root,
      id,
      DomainAppearance.defaults(ordered[i].name, i),
    );
    changed = true;
  }
  if (changed) await writeDomainPreferenceRoot(client, userId, root);
  return root;
});
final domainAppearancesProvider = FutureProvider<Map<int, DomainAppearance>>((
  ref,
) async {
  final w = await ref.watch(timeDomainsProvider.future);
  final root = await ref.watch(domainPreferenceRootProvider.future);
  final domains = root[domainPreferencesKey];
  final ordered = w.memberships.toList()
    ..sort(
      (a, b) => a.id == w.personalId
          ? -1
          : b.id == w.personalId
          ? 1
          : a.id.compareTo(b.id),
    );
  return {
    for (var i = 0; i < ordered.length; i++)
      ordered[i].id: DomainAppearance.read(
        domains is Map ? domains['${ordered[i].id}'] : null,
        DomainAppearance.defaults(ordered[i].name, i),
      ),
  };
});
Future<void> saveDomainAppearances(
  WidgetRef ref,
  Map<int, DomainAppearance> appearances,
) async {
  final w = await ref.read(timeDomainsProvider.future);
  final client = w.clients[w.personalId]!;
  final userId = int.parse(w.user.userId);
  var root = await readDomainPreferenceRoot(client, userId);
  for (final entry in appearances.entries) {
    root = mergeDomainAppearance(root, entry.key, entry.value);
  }
  await writeDomainPreferenceRoot(client, userId, root);
  ref.invalidate(domainPreferenceRootProvider);
  ref.invalidate(mainPersonProvider);
}
