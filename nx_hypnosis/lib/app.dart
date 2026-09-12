import 'package:flutter/material.dart';
import 'desires.dart';
import 'forms.dart';
import 'listening.dart';

const ink = Color(0xff262626);
const muted = Color(0xff909090);
const paper = Color(0xfff8f8f7);
const line = Color(0xffe6e6e4);

class HypnosisApp extends StatelessWidget {
  const HypnosisApp({super.key, required this.collection});
  final HypnosisCollection collection;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'NX Hypnosis',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: paper,
      colorScheme: const ColorScheme.light(
        primary: ink,
        onPrimary: Colors.white,
        surface: paper,
        onSurface: ink,
        outline: line,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(fontSize: 16, height: 1.55, color: ink),
      ),
      dividerColor: line,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 44),
          backgroundColor: ink,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          foregroundColor: ink,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 44),
          side: const BorderSide(color: line),
        ),
      ),
    ),
    home: HypnosisHome(collection: collection),
  );
}

enum View { tapes, desires, desire, story, desireForm, storyForm }

class HypnosisHome extends StatefulWidget {
  const HypnosisHome({super.key, required this.collection});
  final HypnosisCollection collection;
  @override
  State<HypnosisHome> createState() => _HypnosisHomeState();
}

class _HypnosisHomeState extends State<HypnosisHome> {
  final listening = Listening();
  View view = View.tapes;
  Desire? selectedDesire;
  Tape? selectedTape;
  String? filter;
  bool editing = false;
  HypnosisCollection get data => widget.collection;
  @override
  void dispose() {
    listening.dispose();
    super.dispose();
  }

  void go(View next) {
    setState(() => view = next);
  }

  void back() {
    switch (view) {
      case View.desire:
      case View.desireForm:
        go(View.desires);
      case View.storyForm:
        go(View.tapes);
      default:
        go(View.tapes);
    }
  }

  Widget backButton(String text, VoidCallback action) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        foregroundColor: const Color(0xff777777),
      ),
      onPressed: action,
      icon: const Icon(Icons.arrow_back, size: 14),
      label: Text(text, style: const TextStyle(fontSize: 13)),
    ),
  );
  Widget heading(String text, {Widget? trailing, bool small = false}) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            fontSize: small ? 28 : 34,
            height: 1.2,
            fontWeight: FontWeight.w600,
            letterSpacing: -1.2,
          ),
        ),
      ),
      if (trailing != null) ...[const SizedBox(width: 18), trailing],
    ],
  );
  Widget plus(String label, VoidCallback action, {bool dark = true}) =>
      IconButton.filled(
        tooltip: label,
        onPressed: action,
        style: IconButton.styleFrom(
          fixedSize: const Size(44, 44),
          backgroundColor: dark ? ink : const Color(0xffececeb),
          foregroundColor: dark ? Colors.white : ink,
        ),
        icon: const Icon(Icons.add, size: 22),
      );
  Widget play(Tape tape, {bool dark = false}) => IconButton.filled(
    tooltip: tape.audioAsset == null
        ? 'No recording yet'
        : 'Play ${tape.title}',
    onPressed: tape.audioAsset == null ? null : () => listening.open(tape),
    style: IconButton.styleFrom(
      fixedSize: Size(dark ? 52 : 44, dark ? 52 : 44),
      backgroundColor: dark ? ink : const Color(0xffececeb),
      foregroundColor: dark ? Colors.white : ink,
    ),
    icon: const Icon(Icons.play_arrow_rounded, size: 25),
  );
  Widget surface(
    Widget child, {
    VoidCallback? tap,
    double padding = 18,
    double radius = 12,
  }) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: const BorderSide(color: line),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: tap,
      child: Padding(padding: EdgeInsets.all(padding), child: child),
    ),
  );
  Widget subtitle(String text) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 28),
    child: Text(text, style: const TextStyle(color: muted, fontSize: 15)),
  );

  Widget tapesList(List<Tape> tapes) {
    if (tapes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.waves, color: muted),
              SizedBox(height: 12),
              Text(
                'Your first story starts here.',
                style: TextStyle(color: muted),
              ),
              Text(
                'Create something you can return to.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: tapes
          .map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: surface(
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          selectedTape = t;
                          go(View.story);
                        },
                        child: Row(
                          children: [
                            const Icon(Icons.waves, color: muted, size: 18),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.title,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      height: 1.45,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${data.desire(t.desireId).title} · ${t.audioAsset != null ? 'Ready to listen' : 'Draft'}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (t.audioAsset != null) play(t),
                  ],
                ),
                padding: 16,
                radius: 14,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget tapesScreen() {
    const labels = {
      'god': 'Faith',
      'wealth': 'Wealth',
      'son': 'Family',
      'husband': 'Partnership',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading(
          'Tapes',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton.outlined(
                tooltip: 'Desires',
                onPressed: () => go(View.desires),
                style: IconButton.styleFrom(
                  fixedSize: const Size(44, 44),
                  side: const BorderSide(color: line),
                  foregroundColor: ink,
                ),
                icon: const Icon(Icons.favorite_border_rounded, size: 21),
              ),
              const SizedBox(width: 12),
              if (data.desires.isNotEmpty)
                plus('Create a story', () {
                  selectedDesire = data.desires.first;
                  go(View.storyForm);
                }),
            ],
          ),
        ),
        subtitle('Words to return to.'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final entry in [
                const MapEntry<String?, String>(null, 'All tapes'),
                ...data.desires.map(
                  (d) => MapEntry(d.id, labels[d.id] ?? d.title),
                ),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(entry.value),
                    selected: filter == entry.key,
                    showCheckmark: false,
                    selectedColor: ink,
                    backgroundColor: paper,
                    labelStyle: TextStyle(
                      fontSize: 13,
                      color: filter == entry.key
                          ? Colors.white
                          : const Color(0xff777777),
                    ),
                    shape: const StadiumBorder(side: BorderSide(color: line)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    onSelected: (_) => setState(() => filter = entry.key),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        tapesList(
          data.tapes
              .where((t) => filter == null || t.desireId == filter)
              .toList(),
        ),
      ],
    );
  }

  Widget desiresScreen() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      backButton('Tapes', () => go(View.tapes)),
      const SizedBox(height: 16),
      heading(
        'Desires',
        trailing: plus('Add desire', () {
          selectedDesire = null;
          editing = false;
          go(View.desireForm);
        }),
      ),
      subtitle('Who you choose to become.'),
      LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 552;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: data.desires.map((d) {
              final count = data.forDesire(d.id).length;
              return SizedBox(
                width: wide
                    ? (constraints.maxWidth - 8) / 2
                    : constraints.maxWidth,
                child: surface(
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          d.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                        if (count > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            '$count ${count == 1 ? 'tape' : 'tapes'}',
                            style: const TextStyle(fontSize: 12, color: muted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  padding: 14,
                  tap: () {
                    selectedDesire = d;
                    go(View.desire);
                  },
                ),
              );
            }).toList(),
          );
        },
      ),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(
          child: Text(
            'A belief to practice. A story to live into.',
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ),
      ),
    ],
  );

  Future<void> deleteDesire(Desire desire) async {
    final others = data.desires.where((d) => d.id != desire.id).toList();
    final count = data.forDesire(desire.id).length;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${desire.title}?'),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$count linked tapes.'),
                if (count > 0 && others.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Move tapes to another desire:'),
                  for (final d in others)
                    ListTile(
                      title: Text(d.title),
                      onTap: () => Navigator.pop(context, d.id),
                    ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, '__delete__'),
            child: Text(
              count > 0 ? 'Delete desire and tapes' : 'Delete desire',
            ),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    if (result == '__delete__' && listening.tape?.desireId == desire.id) {
      await listening.close();
    }
    data.removeDesire(desire, moveTo: result == '__delete__' ? null : result);
    if (filter == desire.id) filter = null;
    if (mounted) go(View.desires);
  }

  Widget desireScreen() {
    final d = selectedDesire!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: backButton('Desires', () => go(View.desires))),
            PopupMenuButton<String>(
              tooltip: 'Desire options',
              icon: const Icon(Icons.more_horiz),
              onSelected: (v) {
                if (v == 'edit') {
                  editing = true;
                  go(View.desireForm);
                } else {
                  deleteDesire(d);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit desire')),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete desire'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        heading(d.title, small: true),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            d.belief,
            style: const TextStyle(
              fontSize: 18,
              height: 1.8,
              color: Color(0xff666666),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Your stories',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            plus('Create a story', () => go(View.storyForm), dark: false),
          ],
        ),
        const SizedBox(height: 16),
        tapesList(data.forDesire(d.id)),
      ],
    );
  }

  Widget storyScreen() {
    final t = selectedTape!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        backButton('Tapes', () => go(View.tapes)),
        const SizedBox(height: 20),
        heading(t.title, trailing: play(t, dark: true), small: true),
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 24),
          child: Text(
            '${data.desire(t.desireId).title} · ${t.audioAsset != null ? 'Hypnotizer' : 'Draft · No recording yet'}',
            style: const TextStyle(color: muted, fontSize: 12),
          ),
        ),
        surface(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: t.story
                .split(RegExp(r'\n\s*\n'))
                .where((p) => p.trim().isNotEmpty)
                .map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 22),
                    child: Text(
                      p.trim(),
                      style: const TextStyle(fontSize: 16, height: 1.85),
                    ),
                  ),
                )
                .toList(),
          ),
          padding: 26,
        ),
      ],
    );
  }

  Widget body() => switch (view) {
    View.tapes => tapesScreen(),
    View.desires => desiresScreen(),
    View.desire => desireScreen(),
    View.story => storyScreen(),
    View.desireForm => DesireForm(
      key: ValueKey('desire-${editing ? selectedDesire?.id : 'new'}'),
      desire: editing ? selectedDesire : null,
      cancel: () => go(View.desires),
      save: (title, belief) {
        if (editing) {
          selectedDesire!
            ..title = title
            ..belief = belief;
        } else {
          selectedDesire = Desire(
            id: data.newId(),
            title: title,
            belief: belief,
          );
          data.desires.add(selectedDesire!);
        }
        go(View.desire);
      },
    ),
    View.storyForm => StoryForm(
      desires: data.desires,
      initial: selectedDesire!.id,
      cancel: () => go(View.tapes),
      create: (desireId, title, prompt) {
        final d = data.desire(desireId);
        selectedTape = Tape(
          id: data.newId(),
          desireId: desireId,
          title: title,
          prompt: prompt,
          story: desireId == 'wealth'
              ? data.sampleStory
              : 'Let your hands rest. Let your shoulders settle.\n\n${d.belief}\n\nTake a moment to notice how these words feel.',
        );
        data.tapes.add(selectedTape!);
        go(View.story);
      },
    ),
  };

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: view == View.tapes,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) back();
    },
    child: Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            key: ValueKey(view),
            padding: EdgeInsets.fromLTRB(
              box.maxWidth < 600 ? 24 : 32,
              box.maxWidth < 600 ? 24 : 36,
              box.maxWidth < 600 ? 24 : 32,
              36,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 816),
                child: body(),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: ListeningBar(listening: listening),
    ),
  );
}
