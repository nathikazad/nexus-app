import 'playback_state.dart';
import 'package:nx_auth/nx_auth.dart';
import 'package:flutter/rendering.dart';
import 'timed_story.dart';
import 'dart:async';
import 'package:nx_offline/nx_offline.dart';
import 'package:flutter/material.dart';
import 'desires.dart';
import 'forms.dart';
import 'listening.dart';
import 'remote_collection.dart';

const ink = Color(0xff262626);
const muted = Color(0xff909090);
const paper = Color(0xfff8f8f7);
const line = Color(0xffe6e6e4);

class HypnosisApp extends StatelessWidget {
  const HypnosisApp({super.key, required this.collection, this.onLogout});
  final HypnosisCollection collection;
  final VoidCallback? onLogout;
  @override
  Widget build(BuildContext context) => MaterialApp(
    builder: (context, child) => DomainSessionGate(child: child!),
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
    home: HypnosisHome(collection: collection, onLogout: onLogout),
  );
}

enum View { tapes, desires, desire, story, desireForm, storyForm }

class HypnosisHome extends StatefulWidget {
  const HypnosisHome({super.key, required this.collection, this.onLogout});
  final HypnosisCollection collection;
  final VoidCallback? onLogout;
  @override
  State<HypnosisHome> createState() => _HypnosisHomeState();
}

class _HypnosisHomeState extends State<HypnosisHome> {
  final followPlayback = ValueNotifier(true);
  late final listening = Listening(
    loadRecordingPath:
        widget.collection is RemoteCollection &&
            (widget.collection as RemoteCollection).cache != null
        ? (widget.collection as RemoteCollection).recordingPath
        : null,
    loadRecording: widget.collection is RemoteCollection
        ? (widget.collection as RemoteCollection).recording
        : null,
  );
  PlaybackState? playbackState;
  @override
  void initState() {
    super.initState();
    if (widget.collection case final RemoteCollection remote) {
      playbackState = PlaybackState.forCollection(listening, remote);
      unawaited(playbackState!.initialize());
    }
    data.addListener(_collectionChanged);
  }

  void _collectionChanged() {
    if (!mounted) return;
    playbackState?.libraryChanged();
    setState(() {
      if (selectedDesire != null) {
        selectedDesire = data.desires
            .where((d) => d.id == selectedDesire!.id)
            .firstOrNull;
        if (selectedDesire == null && view == View.desire) view = View.desires;
      }
      if (selectedTape != null) {
        selectedTape = data.tapes
            .where((t) => t.id == selectedTape!.id)
            .firstOrNull;
        if (selectedTape == null && view == View.story) view = View.tapes;
      }
      if (filter != null && !data.desires.any((d) => d.id == filter)) {
        filter = null;
      }
    });
  }

  Widget syncStatus() {
    final remote = data;
    if (remote is! RemoteCollection) return const SizedBox.shrink();
    final count = remote.tapes.where((t) => t.audioAsset != null).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SyncStatusView(
                  source: remote.synchronizer,
                  textStyle: const TextStyle(fontSize: 12, color: muted),
                ),
                if (remote.cache != null && count > 0)
                  Text(
                    '${remote.savedRecordings.length} of $count recordings saved offline${remote.downloading ? ' · Downloading' : ''}',
                    style: const TextStyle(fontSize: 12, color: muted),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Sync collection',
            icon: const Icon(Icons.sync, size: 20),
            onPressed: () =>
                unawaited(remote.refresh().catchError((Object _) {})),
          ),
        ],
      ),
    );
  }

  void openSettings() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Settings'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: ListenableBuilder(
            listenable: data,
            builder: (context, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const DomainSettingsTile(),
                if (data is RemoteCollection) ...[
                  const Divider(),
                  const SizedBox(height: 12),
                  syncStatus(),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  bool saving = false;
  Future<void> perform(Future<void> Function() action) async {
    if (saving) return;
    setState(() => saving = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not save. Please try again.")),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  View view = View.tapes;
  Desire? selectedDesire;
  Tape? selectedTape;
  String? filter;
  bool editing = false;
  HypnosisCollection get data => widget.collection;
  @override
  void dispose() {
    data.removeListener(_collectionChanged);
    playbackState?.dispose();
    listening.dispose();
    followPlayback.dispose();
    super.dispose();
  }

  void go(View next) {
    followPlayback.value = true;
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
      'A faithful servant of God': 'Faith',
      'A creator of wealth through service': 'Wealth',
      'A responsible and loving son': 'Family',
      'A loving and dependable husband': 'Partnership',
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
              IconButton.filled(
                tooltip: 'Settings',
                onPressed: openSettings,
                style: IconButton.styleFrom(
                  fixedSize: const Size(44, 44),
                  backgroundColor: ink,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.settings_outlined, size: 22),
              ),
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
                  (d) => MapEntry(d.id, labels[d.title] ?? d.title),
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
      if (widget.onLogout != null)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: widget.onLogout,
            child: const Text('Sign out'),
          ),
        ),
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
    await perform(() async {
      await data.removeDesire(
        desire,
        moveTo: result == '__delete__' ? null : result,
      );
      if (filter == desire.id) filter = null;
      if (mounted) go(View.desires);
    });
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
          t.timeline != null
              ? TimedStory(
                  key: ValueKey("${t.id}:${t.audioRevision}"),
                  tape: t,
                  listening: listening,
                  follow: followPlayback,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:
                      (t.story.isEmpty
                              ? "Your tape is saved as a draft. The narration has not been created yet."
                              : t.story)
                          .split(RegExp(r'\n\s*\n'))
                          .where((p) => p.trim().isNotEmpty)
                          .map(
                            (p) => Padding(
                              padding: const EdgeInsets.only(bottom: 22),
                              child: Text(
                                p.trim(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.85,
                                ),
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
      save: (title, belief) => perform(() async {
        selectedDesire = await data.saveDesire(
          title,
          belief,
          id: editing ? selectedDesire?.id : null,
        );
        if (mounted) go(View.desire);
      }),
    ),
    View.storyForm => StoryForm(
      desires: data.desires,
      initial: selectedDesire!.id,
      cancel: () => go(View.tapes),
      create: (desireId, title, prompt) => perform(() async {
        selectedTape = await data.createTape(desireId, title, prompt);
        if (mounted) go(View.story);
      }),
    ),
  };

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: view == View.tapes,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) back();
    },
    child: Scaffold(
      floatingActionButton: view == View.story && selectedTape?.timeline != null
          ? ValueListenableBuilder<bool>(
              valueListenable: followPlayback,
              builder: (context, follow, _) => follow
                  ? const SizedBox.shrink()
                  : FloatingActionButton.extended(
                      onPressed: () => followPlayback.value = true,
                      icon: const Icon(Icons.my_location),
                      label: const Text('Follow audio'),
                    ),
            )
          : null,
      body: NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          if (view == View.story &&
              notification.direction != ScrollDirection.idle) {
            followPlayback.value = false;
          }
          return false;
        },
        child: SafeArea(
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
                  child: AbsorbPointer(
                    absorbing: saving,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (saving) const LinearProgressIndicator(),
                        body(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: ListeningBar(listening: listening),
    ),
  );
}
