import 'package:riverpod/riverpod.dart';

class FilterKind extends Notifier<String> {
  @override
  String build() => 'all';

  void set(String v) => state = v;
}

final filterKindProvider = NotifierProvider<FilterKind, String>(FilterKind.new);

class FilterStatus extends Notifier<String> {
  @override
  String build() => 'all';

  void set(String v) => state = v;
}

final filterStatusProvider = NotifierProvider<FilterStatus, String>(FilterStatus.new);

class SearchQuery extends Notifier<String> {
  @override
  String build() => '';

  void set(String v) => state = v;
}

final searchQueryProvider = NotifierProvider<SearchQuery, String>(SearchQuery.new);
