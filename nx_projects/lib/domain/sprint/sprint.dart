import 'package:nx_projects/domain/sprint/sprint_state.dart';

class Sprint {
  const Sprint({
    required this.id,
    required this.name,
    required this.dates,
    required this.badge,
    required this.start,
    required this.length,
    required this.capH,
    this.state = SprintState.planned,
    this.goal = '',
    this.retro = '',
    this.dayNotes = const {},
  });

  final int id;
  final String name;
  final String dates;

  /// display label: active, planned, done
  final String badge;
  final SprintState state;
  final String start;

  /// YYYY-MM-DD
  final int length;
  final double capH;
  final String goal;
  final String retro;
  final Map<String, String> dayNotes;

  Sprint copyWith({
    int? id,
    String? name,
    String? dates,
    String? badge,
    SprintState? state,
    String? start,
    int? length,
    double? capH,
    String? goal,
    String? retro,
    Map<String, String>? dayNotes,
  }) {
    return Sprint(
      id: id ?? this.id,
      name: name ?? this.name,
      dates: dates ?? this.dates,
      badge: badge ?? this.badge,
      state: state ?? this.state,
      start: start ?? this.start,
      length: length ?? this.length,
      capH: capH ?? this.capH,
      goal: goal ?? this.goal,
      retro: retro ?? this.retro,
      dayNotes: dayNotes ?? this.dayNotes,
    );
  }
}
