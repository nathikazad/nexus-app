import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/nx_db.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReviewProgressionSettings {
  const ReviewProgressionSettings({
    this.historyWindow = 10,
    // Legacy constructor arguments retained for archived session compatibility.
    this.automaticProgressionEnabled = true,
    this.moveToPastPercentage = 80,
    this.moveToCurrentPercentage = 80,
    this.autoReplacePromotedCards = false,
  });
  final int historyWindow;
  final bool automaticProgressionEnabled;
  final int moveToPastPercentage;
  final int moveToCurrentPercentage;
  final bool autoReplacePromotedCards;
  bool get isValid => historyWindow >= 1 && historyWindow <= 10;
  Map<String, Object> toJson() => {'history_window': historyWindow};
  factory ReviewProgressionSettings.fromJson(Map<String, Object?> json) {
    final n = (json['history_window'] as num?)?.toInt() ?? 10;
    return ReviewProgressionSettings(historyWindow: n >= 1 && n <= 10 ? n : 10);
  }
}

class ReviewProgressionSettingsStore {
  ReviewProgressionSettingsStore({
    this.client,
    this.userId,
    this.accountKey = 'signed-out',
  });
  final GraphQLClient? client;
  final int? userId;
  final String accountKey;
  String get _key => 'nx_cards.account_preferences.v2.$accountKey';

  Future<ReviewProgressionSettings> load() async {
    final local = await SharedPreferences.getInstance();
    final cached = local.getString(_key);
    Map<String, Object?> data = cached == null
        ? {}
        : Map<String, Object?>.from(jsonDecode(cached) as Map);
    if (client != null && userId != null) {
      try {
        final result = await client!.query(
          QueryOptions(
            document: gql(r'''query CardsPreferences($id: Int!) {
            allUsers(condition: {id: $id}, first: 1) { nodes { preferences } }
          }'''),
            variables: {'id': userId},
            fetchPolicy: FetchPolicy.networkOnly,
          ),
        );
        if (result.hasException) throw result.exception!;
        var preferences =
            result.data?['allUsers']?['nodes']?[0]?['preferences'];
        if (preferences is String) preferences = jsonDecode(preferences);
        data = Map<String, Object?>.from(
          (preferences is Map ? preferences['nx_cards'] : null) as Map? ?? {},
        );
        await local.setString(_key, jsonEncode(data));
      } catch (_) {
        // Offline reads use only this account's last synchronized preference.
      }
    }
    return ReviewProgressionSettings.fromJson(data);
  }

  Future<void> save(ReviewProgressionSettings settings) async {
    if (!settings.isValid) {
      throw ArgumentError('Choose between 1 and 10 answers.');
    }
    if (client == null || userId == null) {
      throw StateError('Sign in to save account preferences.');
    }
    final result = await client!.mutate(
      MutationOptions(
        document: gql(r'''mutation CardsPreferences($window: Int!) {
        setCardsRecallWindow(historyWindow: $window)
      }'''),
        variables: {'window': settings.historyWindow},
      ),
    );
    if (result.hasException) throw result.exception!;
    final local = await SharedPreferences.getInstance();
    await local.setString(_key, jsonEncode(settings.toJson()));
  }
}

final reviewProgressionSettingsStoreProvider =
    Provider<ReviewProgressionSettingsStore>((ref) {
      final user = ref.exists(authProvider)
          ? ref.watch(authProvider).value
          : null;
      return ReviewProgressionSettingsStore(
        client: user == null ? null : ref.watch(graphqlClientProvider),
        userId: user == null ? null : int.tryParse(user.userId),
        accountKey: user == null
            ? 'signed-out'
            : '${user.preset.serverId}:${user.userId}',
      );
    });
final reviewProgressionSettingsProvider =
    FutureProvider<ReviewProgressionSettings>(
      (ref) => ref.watch(reviewProgressionSettingsStoreProvider).load(),
    );
