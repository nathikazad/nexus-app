import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart' as image_picker;
import 'package:intl/intl.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_db/riverpod.dart';

const mirrorPublicUrl = String.fromEnvironment(
  'MIRROR_PUBLIC_URL',
  defaultValue: 'http://188.245.46.13:8787',
);
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      overrides: [dbAuditSourceKindProvider.overrideWithValue('nx_post')],
      child: const NexusPostApp(),
    ),
  );
}

class NexusPostApp extends StatelessWidget {
  const NexusPostApp({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.interTextTheme();
    return MaterialApp(
      title: 'Nexus Post',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff18181b),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xfffafafa),
        textTheme: textTheme,
        useMaterial3: true,
      ),
      home: const PostAppShell(),
    );
  }
}

class PostAppShell extends ConsumerWidget {
  const PostAppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    if (auth.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final user = auth.value;
    if (user == null) {
      return const PostLoginScreen();
    }
    final session = PostSession.fromUser(user);
    return FeedPage(
      session: session,
      repository: MirrorFeedRepository(session.mirrorUrl),
      postRepository: MicroblogPostRepository(
        session.mcpUrl,
        graphqlUrl: session.graphqlUrl,
        userId: session.userId,
      ),
    );
  }
}

class PostSession {
  const PostSession({
    required this.userId,
    required this.mcpUrl,
    required this.graphqlUrl,
    required this.mirrorUrl,
  });

  final String userId;
  final String mcpUrl;
  final String graphqlUrl;
  final String mirrorUrl;

  factory PostSession.fromUser(User user) {
    final urls = resolve(user.preset);
    return PostSession(
      userId: user.userId,
      mcpUrl: normalizeEndpoint(urls.imageHttp),
      graphqlUrl: urls.graphqlHttp,
      mirrorUrl: mirrorPublicUrl,
    );
  }
}

class PostLoginScreen extends ConsumerStatefulWidget {
  const PostLoginScreen({super.key});

  @override
  ConsumerState<PostLoginScreen> createState() => _PostLoginScreenState();
}

class _PostLoginScreenState extends ConsumerState<PostLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  AuthLoginProfile _selectedProfile = authLoginProfiles.first;
  BackendPreset _selectedPreset = BackendPreset.defaultPreset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfffafafa),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      child: Container(
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xff18181b),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'N',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'nx_post',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xff18181b),
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sign in to post microblogs from your personal domain.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xff71717a),
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 36),
                    const LoginLabel('PERSON'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<AuthLoginProfile>(
                      isExpanded: true,
                      initialValue: _selectedProfile,
                      decoration: loginDecoration(icon: Icons.person_outline),
                      items: [
                        for (final profile in authLoginProfiles)
                          DropdownMenuItem<AuthLoginProfile>(
                            value: profile,
                            child: Text(profile.label),
                          ),
                      ],
                      onChanged: (profile) {
                        if (profile != null) {
                          setState(() => _selectedProfile = profile);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const LoginLabel('BACKEND'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<BackendPreset>(
                      isExpanded: true,
                      initialValue: _selectedPreset,
                      decoration: loginDecoration(icon: Icons.dns_outlined),
                      items: [
                        for (final preset in BackendPreset.values)
                          DropdownMenuItem<BackendPreset>(
                            value: preset,
                            child: Text(preset.label),
                          ),
                      ],
                      onChanged: (preset) {
                        if (preset != null) {
                          setState(() => _selectedPreset = preset);
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xff18181b),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      onPressed: _login,
                      child: const Text(
                        'Log In',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Public mirror: http://188.245.46.13:8787',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xffa1a1aa), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final error = await ref
        .read(authProvider.notifier)
        .login(_selectedProfile.userId, _selectedPreset);
    if (error == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error), backgroundColor: const Color(0xffef4444)),
    );
  }
}

class LoginLabel extends StatelessWidget {
  const LoginLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xff71717a),
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

InputDecoration loginDecoration({required IconData icon}) {
  return InputDecoration(
    prefixIcon: Icon(icon, color: const Color(0xff71717a), size: 20),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xffe4e4e7)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xff18181b)),
    ),
  );
}

String normalizeEndpoint(String value) {
  return value.trim().replaceFirst(RegExp(r'/+$'), '');
}

void logNxPost(String message) {
  final line = '[nx_post] $message';
  debugPrint(line);
  // ignore: avoid_print
  print(line);
}

class FeedPage extends StatefulWidget {
  const FeedPage({
    required this.session,
    required this.repository,
    required this.postRepository,
    super.key,
  });

  final PostSession session;
  final MirrorFeedRepository repository;
  final MicroblogPostRepository postRepository;

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  late Future<List<FeedItem>> _feedFuture;
  final Set<String> _selectedTags = {};
  final Set<FeedItemKind> _selectedKinds = {
    FeedItemKind.document,
    FeedItemKind.microblog,
  };
  final Set<String> _deletedItemIds = {};
  bool _hasCustomTagSelection = false;
  bool _syncing = false;
  String _syncLabel = '';

  @override
  void initState() {
    super.initState();
    _feedFuture = widget.repository.fetchFeed();
  }

  void _reload() {
    setState(() {
      _feedFuture = widget.repository.fetchFeed();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xff18181b),
          onRefresh: () async => _reload(),
          child: FutureBuilder<List<FeedItem>>(
            future: _feedFuture,
            builder: (context, snapshot) {
              final items = snapshot.data ?? const <FeedItem>[];
              final topics = _topicsFor(items);
              final visibleItems = items
                  .where(_matchesFilters)
                  .where((item) => !_deletedItemIds.contains(item.id))
                  .toList(growable: false);

              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 48, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 672),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              FeedHeader(
                                topics: topics,
                                selectedTags: _selectedTags,
                                selectedKinds: _selectedKinds,
                                hasCustomTagSelection: _hasCustomTagSelection,
                                onFiltersChanged: _setFilters,
                              ),
                              SyncStatusBanner(
                                visible: _syncing,
                                label: _syncLabel,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      items.isEmpty)
                    const SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (snapshot.hasError && items.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: FeedMessage(
                        title: 'Could not load feed',
                        body: snapshot.error.toString(),
                        action: TextButton(
                          onPressed: _reload,
                          child: const Text('Try again'),
                        ),
                      ),
                    )
                  else if (visibleItems.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: FeedMessage(
                        title: 'No posts here yet',
                        body: 'Try another topic or pull to refresh.',
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 40, 20, 96),
                      sliver: SliverList.separated(
                        itemCount: visibleItems.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 56),
                        itemBuilder: (context, index) {
                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 672),
                              child: FeedItemView(
                                item: visibleItems[index],
                                onEditMicroblog: _editMicroblog,
                                onDeleteMicroblog: _deleteMicroblog,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final posted = await showComposeSheet(
            context,
            repository: widget.postRepository,
          );
          if (posted == true && mounted) {
            _reload();
          }
        },
        backgroundColor: const Color(0xff18181b),
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        tooltip: 'New microblog',
        child: const Icon(Icons.add_rounded, size: 30),
      ),
    );
  }

  List<String> _topicsFor(List<FeedItem> items) {
    final topics = <String>{};
    for (final item in items) {
      if (item.kind != FeedItemKind.document) continue;
      topics.addAll(item.topics);
    }
    return [...topics.toList()..sort()];
  }

  bool _matchesFilters(FeedItem item) {
    if (!_selectedKinds.contains(item.kind)) return false;
    if (item.kind == FeedItemKind.microblog) return true;
    final selectedTags = _hasCustomTagSelection ? _selectedTags : null;
    if (selectedTags == null) return true;
    if (selectedTags.isEmpty) return false;
    return item.topics.any(selectedTags.contains);
  }

  void _setFilters({
    required Set<String> selectedTags,
    required Set<FeedItemKind> selectedKinds,
    required bool hasCustomTagSelection,
  }) {
    setState(() {
      _selectedTags
        ..clear()
        ..addAll(selectedTags);
      _selectedKinds
        ..clear()
        ..addAll(selectedKinds);
      _hasCustomTagSelection = hasCustomTagSelection;
    });
  }

  Future<void> _editMicroblog(FeedItem item) async {
    final edited = await showComposeSheet(
      context,
      repository: widget.postRepository,
      item: item,
    );
    if (edited == true && mounted) {
      _reload();
    }
  }

  Future<void> _deleteMicroblog(FeedItem item) async {
    final modelId = item.modelId;
    if (modelId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This removes the microblog and syncs the mirror.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xff18181b),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      setState(() {
        _syncing = true;
        _syncLabel = 'Deleting and syncing mirror...';
      });
      await widget.postRepository.deleteMicroblog(modelId);
      if (!mounted) return;
      setState(() {
        _deletedItemIds.add(item.id);
        _syncing = false;
        _syncLabel = '';
      });
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microblog deleted and synced.')),
      );
    } catch (error) {
      if (!mounted) return;
      logNxPost('delete microblog failed id=$modelId error=$error');
      setState(() {
        _syncing = false;
        _syncLabel = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete microblog: $error')),
      );
    }
  }
}

class SyncStatusBanner extends StatefulWidget {
  const SyncStatusBanner({
    required this.visible,
    required this.label,
    super.key,
  });

  final bool visible;
  final String label;

  @override
  State<SyncStatusBanner> createState() => _SyncStatusBannerState();
}

class _SyncStatusBannerState extends State<SyncStatusBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (widget.visible) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant SyncStatusBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.visible && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: widget.visible
          ? Padding(
              key: const ValueKey('syncing'),
              padding: const EdgeInsets.only(top: 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xfff4f4f5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xffe4e4e7)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: const Color(0xff18181b),
                          value: null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.label,
                          style: const TextStyle(
                            color: Color(0xff3f3f46),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) {
                          final step = (_controller.value * 4).floor();
                          return Text(
                            '.'.padRight(step.clamp(1, 3), '.'),
                            style: const TextStyle(
                              color: Color(0xff71717a),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(key: ValueKey('not-syncing')),
    );
  }
}

class FeedHeader extends StatelessWidget {
  const FeedHeader({
    required this.topics,
    required this.selectedTags,
    required this.selectedKinds,
    required this.hasCustomTagSelection,
    required this.onFiltersChanged,
    super.key,
  });

  final List<String> topics;
  final Set<String> selectedTags;
  final Set<FeedItemKind> selectedKinds;
  final bool hasCustomTagSelection;
  final void Function({
    required Set<String> selectedTags,
    required Set<FeedItemKind> selectedKinds,
    required bool hasCustomTagSelection,
  })
  onFiltersChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xffe4e4e7))),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Feed',
                style: TextStyle(
                  color: Color(0xffa1a1aa),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.6,
                ),
              ),
            ),
            TopicFilterMenu(
              topics: topics,
              selectedTags: selectedTags,
              selectedKinds: selectedKinds,
              hasCustomTagSelection: hasCustomTagSelection,
              onFiltersChanged: onFiltersChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class TopicFilterMenu extends StatelessWidget {
  const TopicFilterMenu({
    required this.topics,
    required this.selectedTags,
    required this.selectedKinds,
    required this.hasCustomTagSelection,
    required this.onFiltersChanged,
    super.key,
  });

  final List<String> topics;
  final Set<String> selectedTags;
  final Set<FeedItemKind> selectedKinds;
  final bool hasCustomTagSelection;
  final void Function({
    required Set<String> selectedTags,
    required Set<FeedItemKind> selectedKinds,
    required bool hasCustomTagSelection,
  })
  onFiltersChanged;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    return PopupMenuButton<void>(
      tooltip: 'Filter by topic',
      position: PopupMenuPosition.under,
      color: Colors.white,
      elevation: 12,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xffe4e4e7)),
        borderRadius: BorderRadius.circular(8),
      ),
      constraints: const BoxConstraints(minWidth: 192),
      itemBuilder: (context) => [
        PopupMenuItem<void>(
          enabled: false,
          padding: const EdgeInsets.all(6),
          child: FilterMenuPanel(
            topics: topics,
            selectedTags: selectedTags,
            selectedKinds: selectedKinds,
            hasCustomTagSelection: hasCustomTagSelection,
            onFiltersChanged: onFiltersChanged,
          ),
        ),
      ],
      child: Container(
        constraints: BoxConstraints(
          minWidth: compact ? 36 : 140,
          minHeight: 36,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xfff4f4f5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_list_rounded,
              size: compact ? 18 : 16,
              color: const Color(0xff71717a),
            ),
            if (!compact) ...[
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  'Filters',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xff3f3f46),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: Color(0xff71717a),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class FilterMenuPanel extends StatefulWidget {
  const FilterMenuPanel({
    required this.topics,
    required this.selectedTags,
    required this.selectedKinds,
    required this.hasCustomTagSelection,
    required this.onFiltersChanged,
    super.key,
  });

  final List<String> topics;
  final Set<String> selectedTags;
  final Set<FeedItemKind> selectedKinds;
  final bool hasCustomTagSelection;
  final void Function({
    required Set<String> selectedTags,
    required Set<FeedItemKind> selectedKinds,
    required bool hasCustomTagSelection,
  })
  onFiltersChanged;

  @override
  State<FilterMenuPanel> createState() => _FilterMenuPanelState();
}

class _FilterMenuPanelState extends State<FilterMenuPanel> {
  late Set<String> _selectedTags;
  late Set<FeedItemKind> _selectedKinds;
  late bool _hasCustomTagSelection;

  @override
  void initState() {
    super.initState();
    _selectedTags = widget.hasCustomTagSelection
        ? {...widget.selectedTags}
        : {...widget.topics};
    _selectedKinds = {...widget.selectedKinds};
    _hasCustomTagSelection = widget.hasCustomTagSelection;
  }

  void _emit() {
    widget.onFiltersChanged(
      selectedTags: _selectedTags,
      selectedKinds: _selectedKinds,
      hasCustomTagSelection: _hasCustomTagSelection,
    );
  }

  void _toggleTag(String topic) {
    setState(() {
      _hasCustomTagSelection = true;
      if (!_selectedTags.remove(topic)) {
        _selectedTags.add(topic);
      }
    });
    _emit();
  }

  void _toggleKind(FeedItemKind kind) {
    setState(() {
      if (!_selectedKinds.remove(kind)) {
        _selectedKinds.add(kind);
      }
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.topics.isNotEmpty) ...[
            const FilterMenuTitle('Tags'),
            for (final topic in widget.topics)
              TopicMenuOption(
                label: topic,
                selected: _selectedTags.contains(topic),
                onTap: () => _toggleTag(topic),
              ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Divider(height: 1, color: Color(0xfff4f4f5)),
            ),
          ],
          const FilterMenuTitle('Type'),
          TopicMenuOption(
            label: 'Essays',
            selected: _selectedKinds.contains(FeedItemKind.document),
            onTap: () => _toggleKind(FeedItemKind.document),
          ),
          TopicMenuOption(
            label: 'Microblogs',
            selected: _selectedKinds.contains(FeedItemKind.microblog),
            onTap: () => _toggleKind(FeedItemKind.microblog),
          ),
        ],
      ),
    );
  }
}

class FilterMenuTitle extends StatelessWidget {
  const FilterMenuTitle(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Color(0xffa1a1aa),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.3,
        ),
      ),
    );
  }
}

class TopicMenuOption extends StatelessWidget {
  const TopicMenuOption({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: selected ? const Color(0xff18181b) : Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: selected
                      ? const Color(0xff18181b)
                      : const Color(0xffd4d4d8),
                ),
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 11,
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xff3f3f46),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FeedItemView extends StatelessWidget {
  const FeedItemView({
    required this.item,
    required this.onEditMicroblog,
    required this.onDeleteMicroblog,
    super.key,
  });

  final FeedItem item;
  final ValueChanged<FeedItem> onEditMicroblog;
  final ValueChanged<FeedItem> onDeleteMicroblog;

  @override
  Widget build(BuildContext context) {
    return item.kind == FeedItemKind.document
        ? DocumentFeedItem(item: item)
        : MicroblogFeedItem(
            item: item,
            onEdit: onEditMicroblog,
            onDelete: onDeleteMicroblog,
          );
  }
}

class DocumentFeedItem extends StatelessWidget {
  const DocumentFeedItem({required this.item, super.key});

  final FeedItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FeedMeta(date: item.date, topic: item.topics.firstOrNull),
        const SizedBox(height: 9),
        Text(
          item.title,
          style: const TextStyle(
            color: Color(0xff18181b),
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1.25,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          item.text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xff52525b),
            fontSize: 15,
            height: 1.65,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Read essay →',
          style: TextStyle(
            color: Color(0xffa1a1aa),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class MicroblogFeedItem extends StatelessWidget {
  const MicroblogFeedItem({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final FeedItem item;
  final ValueChanged<FeedItem> onEdit;
  final ValueChanged<FeedItem> onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: FeedMeta(
                date: item.date,
                topic: item.topics.firstOrNull,
                includeTime: true,
              ),
            ),
            IconButton(
              tooltip: 'Edit post',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 30, height: 30),
              padding: EdgeInsets.zero,
              onPressed: () => onEdit(item),
              icon: const Icon(
                Icons.edit_outlined,
                color: Color(0xffa1a1aa),
                size: 19,
              ),
            ),
            IconButton(
              tooltip: 'Delete post',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 30, height: 30),
              padding: EdgeInsets.zero,
              onPressed: () => onDelete(item),
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xffa1a1aa),
                size: 20,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          item.text,
          style: const TextStyle(
            color: Color(0xff52525b),
            fontSize: 15,
            height: 1.7,
          ),
        ),
        if (item.media.isNotEmpty) ...[
          const SizedBox(height: 16),
          FeedMediaCarousel(media: item.media),
        ],
      ],
    );
  }
}

class FeedMeta extends StatelessWidget {
  const FeedMeta({
    required this.date,
    required this.topic,
    this.includeTime = false,
    super.key,
  });

  final DateTime? date;
  final String? topic;
  final bool includeTime;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: [
        Text(
          formatDate(date, includeTime: includeTime),
          style: const TextStyle(
            color: Color(0xffa1a1aa),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (topic != null) ...[const Dot(), TopicPill(topic!)],
      ],
    );
  }
}

class Dot extends StatelessWidget {
  const Dot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 4,
      decoration: const BoxDecoration(
        color: Color(0xffd4d4d8),
        shape: BoxShape.circle,
      ),
    );
  }
}

class TopicPill extends StatelessWidget {
  const TopicPill(this.topic, {super.key});

  final String topic;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xfff4f4f5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          topic,
          style: const TextStyle(
            color: Color(0xff71717a),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class FeedMediaCarousel extends StatefulWidget {
  const FeedMediaCarousel({required this.media, super.key});

  final List<FeedMedia> media;

  @override
  State<FeedMediaCarousel> createState() => _FeedMediaCarouselState();
}

class _FeedMediaCarouselState extends State<FeedMediaCarousel> {
  late final PageController _controller;
  var _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasMultiple = widget.media.length > 1;
    if (!hasMultiple) {
      return FeedSingleMediaFrame(media: widget.media.first);
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 450),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xffe4e4e7)),
            color: const Color(0xfff4f4f5),
          ),
          child: SizedBox(
            height: 400,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  controller: _controller,
                  itemCount: widget.media.length,
                  onPageChanged: (index) => setState(() => _index = index),
                  itemBuilder: (context, index) => FeedMediaPreview(
                    media: widget.media[index],
                    fit: BoxFit.contain,
                  ),
                ),
                _CarouselButton(
                  alignment: Alignment.centerLeft,
                  icon: Icons.chevron_left_rounded,
                  onPressed: () => _goTo(_index - 1),
                ),
                _CarouselButton(
                  alignment: Alignment.centerRight,
                  icon: Icons.chevron_right_rounded,
                  onPressed: () => _goTo(_index + 1),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.30),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var i = 0; i < widget.media.length; i++)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                width: 6,
                                height: 6,
                                margin: EdgeInsets.only(
                                  right: i == widget.media.length - 1 ? 0 : 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(
                                    alpha: i == _index ? 1 : 0.42,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _goTo(int index) {
    final next = index < 0
        ? widget.media.length - 1
        : index >= widget.media.length
        ? 0
        : index;
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }
}

class FeedSingleMediaFrame extends StatelessWidget {
  const FeedSingleMediaFrame({required this.media, super.key});

  final FeedMedia media;

  @override
  Widget build(BuildContext context) {
    final aspectRatio = media.layout == MediaLayout.portrait
        ? 9 / 16
        : media.layout == MediaLayout.square
        ? 1.0
        : 16 / 9;
    final maxWidth = media.layout == MediaLayout.portrait
        ? 320.0
        : media.layout == MediaLayout.square
        ? 400.0
        : double.infinity;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xffe4e4e7)),
            color: const Color(0xfff4f4f5),
          ),
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: FeedMediaPreview(media: media, fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }
}

class _CarouselButton extends StatelessWidget {
  const _CarouselButton({
    required this.alignment,
    required this.icon,
    required this.onPressed,
  });

  final Alignment alignment;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Material(
          color: Colors.white.withValues(alpha: 0.92),
          shape: const CircleBorder(),
          elevation: 2,
          shadowColor: const Color(0x2418181b),
          child: IconButton(
            tooltip: icon == Icons.chevron_left_rounded
                ? 'Previous image'
                : 'Next image',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            padding: EdgeInsets.zero,
            onPressed: onPressed,
            icon: Icon(icon, color: const Color(0xff3f3f46), size: 22),
          ),
        ),
      ),
    );
  }
}

class FeedMediaPreview extends StatelessWidget {
  const FeedMediaPreview({required this.media, required this.fit, super.key});

  final FeedMedia media;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (media.previewUrl != null)
          Image.network(
            media.previewUrl!,
            fit: fit,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.image_not_supported_outlined),
          )
        else
          const Icon(Icons.image_outlined, color: Color(0xffa1a1aa)),
        if (media.type == FeedMediaType.video) ...[
          ColoredBox(color: Colors.black.withValues(alpha: 0.07)),
          Center(
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x2418181b),
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Color(0xff18181b),
                size: 30,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class FeedMessage extends StatelessWidget {
  const FeedMessage({
    required this.title,
    required this.body,
    this.action,
    super.key,
  });

  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xff18181b),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xff71717a), height: 1.5),
            ),
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
}

Future<bool?> showComposeSheet(
  BuildContext context, {
  required MicroblogPostRepository repository,
  FeedItem? item,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => ComposeSheet(repository: repository, item: item),
  );
}

class ComposeSheet extends StatefulWidget {
  const ComposeSheet({required this.repository, this.item, super.key});

  final MicroblogPostRepository repository;
  final FeedItem? item;

  @override
  State<ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<ComposeSheet> {
  final _textController = TextEditingController();
  final _mediaController = TextEditingController();
  final _imagePicker = image_picker.ImagePicker();
  final List<SelectedPostImage> _selectedImages = [];
  final List<ExistingPostMedia> _existingMedia = [];
  DateTime _postedAt = DateTime.now();
  bool _publishEnabled = true;
  bool _saving = false;
  String _savingLabel = 'Saving...';

  bool get _isEditing => widget.item?.modelId != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item == null) return;
    _textController.text = item.text;
    _postedAt = item.date ?? DateTime.now();
    _existingMedia.addAll(
      item.media.map((media) => ExistingPostMedia.fromFeedMedia(media)),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _mediaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 18, 20, bottomInset + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _isEditing ? 'Edit microblog' : 'New microblog',
                    style: TextStyle(
                      color: Color(0xff18181b),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _textController,
              minLines: 5,
              maxLines: 8,
              autofocus: true,
              decoration: inputDecoration('What do you want to post?'),
            ),
            const SizedBox(height: 14),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _saving ? null : _pickPostedAt,
              child: InputDecorator(
                decoration: inputDecoration('Date and time'),
                child: Row(
                  children: [
                    const Icon(
                      Icons.event_outlined,
                      color: Color(0xff71717a),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        formatDateTime(_postedAt),
                        style: const TextStyle(
                          color: Color(0xff18181b),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xff71717a),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _mediaController,
              decoration: inputDecoration('Image, YouTube, or Instagram URL'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xff18181b),
                side: const BorderSide(color: Color(0xffd4d4d8)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _saving ? null : _pickImages,
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
              label: Text(
                _selectedImages.isEmpty && _existingMedia.isEmpty
                    ? 'Add images'
                    : 'Add more images (${_selectedImages.length})',
              ),
            ),
            if (_existingMedia.isNotEmpty || _selectedImages.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < _existingMedia.length; i++)
                    ComposeMediaPreviewTile(
                      label: _existingMedia[i].label,
                      previewUrl: _existingMedia[i].previewUrl,
                      isVideo: _existingMedia[i].isVideo,
                      onRemove: _saving
                          ? null
                          : () => setState(() => _existingMedia.removeAt(i)),
                    ),
                  for (var i = 0; i < _selectedImages.length; i++)
                    ComposeMediaPreviewTile(
                      image: _selectedImages[i],
                      onRemove: _saving
                          ? null
                          : () => setState(() => _selectedImages.removeAt(i)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _publishEnabled,
              activeThumbColor: const Color(0xff18181b),
              title: const Text('Publish to mirror'),
              subtitle: const Text(
                'Triggers the mirror publisher after saving.',
              ),
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _publishEnabled = value),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xff18181b),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(_savingLabel),
                        ],
                      )
                    : Text(_isEditing ? 'Update microblog' : 'Save microblog'),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _saving && _publishEnabled
                  ? const Padding(
                      key: ValueKey('compose-syncing'),
                      padding: EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              minHeight: 3,
                              color: Color(0xff18181b),
                              backgroundColor: Color(0xffe4e4e7),
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Waiting for mirror',
                            style: TextStyle(
                              color: Color(0xff71717a),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('compose-idle')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Write something first.')));
      return;
    }
    setState(() {
      _saving = true;
      _savingLabel = _publishEnabled ? 'Syncing...' : 'Saving...';
    });
    try {
      final modelId = widget.item?.modelId;
      if (modelId == null) {
        await widget.repository.createMicroblog(
          text: text,
          postedAt: _postedAt,
          mediaUrl: _mediaController.text.trim(),
          images: _selectedImages,
          publishEnabled: _publishEnabled,
        );
      } else {
        await widget.repository.updateMicroblog(
          id: modelId,
          text: text,
          postedAt: _postedAt,
          mediaUrl: _mediaController.text.trim(),
          existingMedia: _existingMedia.map((media) => media.raw).toList(),
          images: _selectedImages,
          publishEnabled: _publishEnabled,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _publishEnabled
                ? 'Microblog saved and synced.'
                : 'Microblog saved as draft.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      logNxPost(
        '${_isEditing ? 'edit' : 'create'} microblog failed error=$error',
      );
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save microblog: $error')),
      );
    }
  }

  Future<void> _pickPostedAt() async {
    var draft = _postedAt;
    final picked = await showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (context) {
        return Container(
          height: 320,
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: Column(
            children: [
              SizedBox(
                height: 48,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      onPressed: () => Navigator.pop(context, draft),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.dateAndTime,
                  initialDateTime: _postedAt,
                  maximumDate: DateTime.now().add(const Duration(minutes: 1)),
                  use24hFormat: false,
                  onDateTimeChanged: (value) => draft = value,
                ),
              ),
            ],
          ),
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _postedAt = picked);
    }
  }

  Future<void> _pickImages() async {
    final source = await _showImageSourceSheet();
    if (source == null || !mounted) return;
    switch (source) {
      case PostImageSource.camera:
        await _pickCameraImage();
      case PostImageSource.photos:
        await _pickPhotoImages();
      case PostImageSource.files:
        await _pickImageFiles();
    }
  }

  Future<PostImageSource?> _showImageSourceSheet() {
    return showCupertinoModalPopup<PostImageSource>(
      context: context,
      builder: (context) {
        return CupertinoActionSheet(
          title: const Text('Add image'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, PostImageSource.camera),
              child: const Text('Camera'),
            ),
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, PostImageSource.photos),
              child: const Text('Photos'),
            ),
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, PostImageSource.files),
              child: const Text('Files'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        );
      },
    );
  }

  Future<void> _pickCameraImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: image_picker.ImageSource.camera,
        imageQuality: 90,
      );
      if (!mounted || image == null) {
        return;
      }
      final selected = await SelectedPostImage.fromXFile(image);
      if (!mounted) return;
      setState(() => _selectedImages.add(selected));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open camera: $error')));
    }
  }

  Future<void> _pickPhotoImages() async {
    try {
      final images = await _imagePicker.pickMultiImage(imageQuality: 90);
      if (!mounted || images.isEmpty) {
        return;
      }
      final selected = <SelectedPostImage>[];
      for (final image in images) {
        selected.add(await SelectedPostImage.fromXFile(image));
      }
      if (!mounted) return;
      setState(() => _selectedImages.addAll(selected));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not choose photos: $error')),
      );
    }
  }

  Future<void> _pickImageFiles() async {
    try {
      final result = await file_picker.FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: file_picker.FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png'],
        withData: true,
      );
      if (!mounted || result == null || result.files.isEmpty) {
        return;
      }
      setState(
        () => _selectedImages.addAll(
          result.files.map(SelectedPostImage.fromPickedFile),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not choose files: $error')));
    }
  }
}

enum PostImageSource { camera, photos, files }

class SelectedPostImage {
  const SelectedPostImage({required this.name, this.path, this.bytes});

  final String name;
  final String? path;
  final Uint8List? bytes;

  factory SelectedPostImage.fromPickedFile(file_picker.PlatformFile file) {
    final bytes = file.bytes;
    final path = !kIsWeb && file.path != null && file.path!.isNotEmpty
        ? file.path
        : null;
    if ((bytes == null || bytes.isEmpty) && path == null) {
      throw StateError('Could not read selected image bytes');
    }
    return SelectedPostImage(name: file.name, path: path, bytes: bytes);
  }

  static Future<SelectedPostImage> fromXFile(image_picker.XFile file) async {
    final bytes = await file.readAsBytes();
    return SelectedPostImage(
      name: file.name,
      path: kIsWeb ? null : file.path,
      bytes: bytes,
    );
  }

  String get mimeType {
    final lower = name.toLowerCase();
    return lower.endsWith('.png') ? 'image/png' : 'image/jpeg';
  }
}

class ExistingPostMedia {
  const ExistingPostMedia({
    required this.raw,
    required this.label,
    required this.previewUrl,
    required this.isVideo,
  });

  final Map<String, dynamic> raw;
  final String label;
  final String? previewUrl;
  final bool isVideo;

  factory ExistingPostMedia.fromFeedMedia(FeedMedia media) {
    final urlLabel = firstNonEmpty([
      media.raw['alt']?.toString(),
      media.raw['provider']?.toString(),
      media.raw['url']?.toString(),
    ]);
    final previewUrl = media.previewUrl;
    return ExistingPostMedia(
      raw: Map<String, dynamic>.from(media.raw),
      label: urlLabel == null || urlLabel.isEmpty ? 'Media' : urlLabel,
      previewUrl: previewUrl,
      isVideo: media.type == FeedMediaType.video,
    );
  }
}

class ComposeMediaPreviewTile extends StatelessWidget {
  const ComposeMediaPreviewTile({
    required this.onRemove,
    this.image,
    this.label,
    this.previewUrl,
    this.isVideo = false,
    super.key,
  });

  final SelectedPostImage? image;
  final String? label;
  final String? previewUrl;
  final bool isVideo;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final selectedImage = image;
    final tileLabel = label ?? selectedImage?.name ?? 'Media';
    return SizedBox(
      width: 68,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xfff4f4f5),
                    border: Border.all(color: const Color(0xffe4e4e7)),
                  ),
                  child: SizedBox(
                    width: 58,
                    height: 58,
                    child: _preview(selectedImage),
                  ),
                ),
              ),
              Positioned(
                right: -6,
                top: -6,
                child: Material(
                  color: const Color(0xff18181b),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onRemove,
                    child: const SizedBox(
                      width: 22,
                      height: 22,
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            tileLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xff71717a),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _preview(SelectedPostImage? selectedImage) {
    final bytes = selectedImage?.bytes;
    if (bytes != null && bytes.isNotEmpty) {
      return Image.memory(bytes, fit: BoxFit.cover);
    }
    final url = previewUrl;
    if (url != null && url.isNotEmpty && !isVideo) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Center(
      child: Icon(
        isVideo ? Icons.play_circle_outline_rounded : Icons.image_outlined,
        color: const Color(0xff71717a),
        size: 24,
      ),
    );
  }
}

InputDecoration inputDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: const Color(0xfffafafa),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xffe4e4e7)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xffe4e4e7)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xff18181b)),
    ),
  );
}

class MicroblogPostRepository {
  MicroblogPostRepository(
    this.baseUrl, {
    required this.graphqlUrl,
    required this.userId,
    http.Client? client,
  }) : _client = client ?? http.Client(),
       _graphqlClient = createClient(
         graphqlUrl,
         userId,
         auditSourceKind: 'nx_post',
       );

  final String baseUrl;
  final String graphqlUrl;
  final String userId;
  final http.Client _client;
  final dynamic _graphqlClient;
  int? _microblogDomainId;

  Future<void> createMicroblog({
    required String text,
    required DateTime postedAt,
    required String mediaUrl,
    required List<SelectedPostImage> images,
    required bool publishEnabled,
  }) async {
    logNxPost('creating microblog publish=$publishEnabled');
    final cleanText = text.trim();
    final linkMedia = mediaUrl.isEmpty
        ? <Map<String, dynamic>>[]
        : [_mediaFromUrl(mediaUrl)];
    final timestamp = postedAt.toUtc().toIso8601String();
    final draftHash = microblogContentHash(
      text: cleanText,
      media: const [],
      topic: null,
    );

    final microblogId = await setKgqlModel(
      _graphqlClient,
      SetModelRequest(
        modelType: 'Microblog',
        name: _nameFromText(cleanText),
        attributes: [
          SetModelAttribute(key: 'text', value: cleanText),
          SetModelAttribute(key: 'posted_at', value: timestamp),
          SetModelAttribute(
            key: 'media',
            value: const <Map<String, dynamic>>[],
          ),
          SetModelAttribute(
            key: 'publish',
            value: {
              'enabled': false,
              'dirty': false,
              'content_hash': draftHash,
              'last_published_hash': null,
              'first_published_at': null,
              'last_published_at': null,
              'status': 'draft',
              'last_error': null,
            },
          ),
        ],
      ),
      domainId: await _domainId(),
      auditSourceKind: 'nx_post',
    );

    try {
      final uploadedMedia = <Map<String, dynamic>>[];
      for (final image in images) {
        uploadedMedia.add(await uploadMicroblogImage(microblogId, image));
      }
      final media = [...uploadedMedia, ...linkMedia];
      final contentHash = microblogContentHash(
        text: cleanText,
        media: media,
        topic: null,
      );

      await setKgqlModel(
        _graphqlClient,
        SetModelRequest(
          id: microblogId,
          name: _nameFromText(cleanText),
          attributes: [
            SetModelAttribute(key: 'text', value: cleanText),
            SetModelAttribute(key: 'posted_at', value: timestamp),
            SetModelAttribute(key: 'media', value: media),
            SetModelAttribute(
              key: 'publish',
              value: {
                'enabled': publishEnabled,
                'dirty': publishEnabled,
                'content_hash': contentHash,
                'last_published_hash': null,
                'first_published_at': null,
                'last_published_at': null,
                'status': publishEnabled ? 'queued' : 'draft',
                'last_error': null,
              },
            ),
          ],
        ),
        domainId: await _domainId(),
        auditSourceKind: 'nx_post',
      );
    } catch (error) {
      logNxPost(
        'create microblog media step failed id=$microblogId error=$error',
      );
      await _bestEffortDeleteMicroblog(microblogId);
      rethrow;
    }

    if (publishEnabled) {
      await triggerPublish(reason: 'microblog_post');
      await waitForPublishSync();
    }
    logNxPost('create microblog complete publish=$publishEnabled');
  }

  Future<void> updateMicroblog({
    required int id,
    required String text,
    required DateTime postedAt,
    required String mediaUrl,
    required List<Map<String, dynamic>> existingMedia,
    required List<SelectedPostImage> images,
    required bool publishEnabled,
  }) async {
    logNxPost('updating microblog id=$id publish=$publishEnabled');
    final cleanText = text.trim();
    final linkMedia = mediaUrl.isEmpty
        ? <Map<String, dynamic>>[]
        : [_mediaFromUrl(mediaUrl)];
    final timestamp = postedAt.toUtc().toIso8601String();
    final uploadedMedia = <Map<String, dynamic>>[];
    for (final image in images) {
      uploadedMedia.add(await uploadMicroblogImage(id, image));
    }
    final media = [...existingMedia, ...uploadedMedia, ...linkMedia];
    final contentHash = microblogContentHash(
      text: cleanText,
      media: media,
      topic: null,
    );

    await setKgqlModel(
      _graphqlClient,
      SetModelRequest(
        id: id,
        name: _nameFromText(cleanText),
        attributes: [
          SetModelAttribute(key: 'text', value: cleanText),
          SetModelAttribute(key: 'posted_at', value: timestamp),
          SetModelAttribute(key: 'media', value: media),
          SetModelAttribute(
            key: 'publish',
            value: {
              'enabled': publishEnabled,
              'dirty': publishEnabled,
              'content_hash': contentHash,
              'last_published_hash': null,
              'first_published_at': null,
              'last_published_at': null,
              'status': publishEnabled ? 'queued' : 'draft',
              'last_error': null,
            },
          ),
        ],
      ),
      domainId: await _domainId(),
      auditSourceKind: 'nx_post',
    );

    if (publishEnabled) {
      await triggerPublish(reason: 'microblog_edit');
      await waitForPublishSync();
    }
    logNxPost('update microblog complete id=$id publish=$publishEnabled');
  }

  Future<Map<String, dynamic>> uploadMicroblogImage(
    int microblogId,
    SelectedPostImage image,
  ) async {
    logNxPost('uploading microblog image id=$microblogId name=${image.name}');
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('$normalizedBaseUrl/microblogs/assets/images'),
          )
          ..headers.addAll(httpHeaders())
          ..fields['microblog_id'] = '$microblogId';

    final path = image.path;
    if (path != null && path.isNotEmpty) {
      request.files.add(
        await http.MultipartFile.fromPath('file', path, filename: image.name),
      );
    } else {
      final bytes = image.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw StateError('Could not read selected image bytes');
      }
      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: image.name),
      );
    }

    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      logNxPost(
        'microblog image upload failed status=${response.statusCode} '
        'body=${response.body}',
      );
      throw StateError(_httpErrorMessage(response));
    }
    final payload = jsonDecode(response.body);
    if (payload is! Map || payload['url'] is! String) {
      throw StateError('Invalid microblog image upload response');
    }
    return {
      'type': 'image',
      'source': 'local',
      'url': payload['url'] as String,
      'mime_type': image.mimeType,
      'alt': image.name,
    };
  }

  Future<void> deleteMicroblog(int id) async {
    logNxPost('deleting microblog id=$id');
    try {
      await setKgqlModel(
        _graphqlClient,
        SetModelRequest(id: id, delete: true),
        domainId: await _domainId(),
        auditSourceKind: 'nx_post',
      );
    } catch (error) {
      if (!_isMissingOrDeniedDelete(error)) {
        rethrow;
      }
      // The mirror can still contain a stale item after a previous successful
      // KGQL delete if the publish trigger failed. Treat this as idempotent and
      // let the full-manifest sync remove it by absence.
    }
    await triggerPublish(reason: 'microblog_delete');
    await waitForPublishSync();
    logNxPost('delete microblog complete id=$id');
  }

  Future<void> _bestEffortDeleteMicroblog(int id) async {
    try {
      await setKgqlModel(
        _graphqlClient,
        SetModelRequest(id: id, delete: true),
        domainId: await _domainId(),
        auditSourceKind: 'nx_post',
      );
    } catch (error) {
      logNxPost('best-effort delete failed id=$id error=$error');
    }
  }

  Future<void> triggerPublish({required String reason}) async {
    logNxPost('triggering mirror publish reason=$reason');
    final response = await _client.post(
      Uri.parse('$normalizedBaseUrl/mirror/publish/trigger'),
      headers: httpHeaders(contentTypeJson: true),
      body: jsonEncode({'reason': reason, 'immediate': true}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      logNxPost(
        'trigger publish failed status=${response.statusCode} '
        'body=${response.body}',
      );
      throw StateError(_httpErrorMessage(response));
    }
    logNxPost('trigger publish accepted body=${response.body}');
  }

  Future<void> waitForPublishSync({
    Duration timeout = const Duration(seconds: 45),
    Duration interval = const Duration(milliseconds: 900),
  }) async {
    final deadline = DateTime.now().add(timeout);
    MirrorPublishStatus? lastStatus;

    while (DateTime.now().isBefore(deadline)) {
      final status = await fetchPublishStatus();
      lastStatus = status;
      logNxPost(
        'mirror publish status=${status.status} '
        'running=${status.running} pending=${status.pendingReason}',
      );

      if (status.running || status.pendingReason != null) {
        await Future<void>.delayed(interval);
        continue;
      }
      if (status.status == 'succeeded') {
        return;
      }
      if (status.status == 'failed') {
        logNxPost('mirror publish failed error=${status.lastError}');
        throw StateError(status.lastError ?? 'Mirror publish failed');
      }

      await Future<void>.delayed(interval);
    }

    throw StateError(
      lastStatus?.running == true
          ? 'Mirror publish is still running'
          : 'Timed out waiting for mirror publish',
    );
  }

  Future<MirrorPublishStatus> fetchPublishStatus() async {
    final response = await _client.get(
      Uri.parse('$normalizedBaseUrl/mirror/publish/status'),
      headers: httpHeaders(),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      logNxPost(
        'fetch publish status failed status=${response.statusCode} '
        'body=${response.body}',
      );
      throw StateError(_httpErrorMessage(response));
    }
    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic>) {
      throw StateError('Invalid mirror status response');
    }
    return MirrorPublishStatus.fromJson(payload);
  }

  Future<int> _domainId() async {
    final cached = _microblogDomainId;
    if (cached != null) return cached;
    final options = await fetchModelTypeDomainOptions(
      _graphqlClient,
      modelTypeName: 'Microblog',
    );
    final domain = options.domains
        .where((domain) => domain.source == 'personal_default')
        .firstOrNull;
    final fallback = domain ?? options.domains.firstOrNull;
    if (fallback == null) {
      throw StateError('No Microblog domain available');
    }
    _microblogDomainId = fallback.id;
    return fallback.id;
  }

  String _httpErrorMessage(http.Response response) {
    var message = 'HTTP ${response.statusCode}';
    try {
      final payload = jsonDecode(response.body);
      if (payload is Map && payload['error'] != null) {
        message = payload['error'].toString();
      }
    } catch (_) {
      // Keep the HTTP status fallback.
    }
    return message;
  }

  bool _isMissingOrDeniedDelete(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('not found') ||
        message.contains('permission denied');
  }

  String get normalizedBaseUrl {
    var value = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    if (CfAccess.endpointNeedsCfAccess(value) && value.startsWith('http://')) {
      value = value.replaceFirst('http://', 'https://');
    }
    return value;
  }

  Map<String, String> httpHeaders({bool contentTypeJson = false}) {
    final base = normalizedBaseUrl;
    return {
      if (contentTypeJson) 'content-type': 'application/json',
      'x-user-id': userId,
      if (CfAccess.shouldAttachHeaders(base)) ...CfAccess.headers,
    };
  }

  Map<String, dynamic> _mediaFromUrl(String url) {
    final uri = Uri.tryParse(url);
    final host = uri?.host.toLowerCase() ?? '';
    if (host.contains('youtube.com') || host.contains('youtu.be')) {
      final videoId = _youtubeId(uri);
      final media = {'type': 'youtube', 'url': url};
      if (videoId != null) {
        media['video_id'] = videoId;
      }
      return media;
    }
    if (host.contains('instagram.com')) {
      return {'type': 'embed', 'provider': 'instagram', 'url': url};
    }
    return {'type': 'image', 'source': 'external', 'url': url};
  }

  String? _youtubeId(Uri? uri) {
    if (uri == null) return null;
    if (uri.host.toLowerCase().contains('youtu.be')) {
      return uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
    }
    return uri.queryParameters['v'];
  }

  String _nameFromText(String text) {
    final clean = text
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .join(' ');
    if (clean.isEmpty) return 'Microblog';
    return clean.length > 80 ? clean.substring(0, 80) : clean;
  }
}

class MirrorPublishStatus {
  const MirrorPublishStatus({
    required this.status,
    required this.running,
    required this.pendingReason,
    required this.lastError,
  });

  final String status;
  final bool running;
  final String? pendingReason;
  final String? lastError;

  factory MirrorPublishStatus.fromJson(Map<String, dynamic> json) {
    return MirrorPublishStatus(
      status: json['status']?.toString() ?? 'unknown',
      running: json['running'] == true,
      pendingReason: json['pending_reason']?.toString(),
      lastError: json['last_error']?.toString(),
    );
  }
}

class MirrorFeedRepository {
  MirrorFeedRepository(this.baseUrl, {http.Client? client})
    : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<List<FeedItem>> fetchFeed() async {
    final manifestResponse = await _client.get(
      Uri.parse('$baseUrl/public/manifest'),
    );
    if (manifestResponse.statusCode != 200) {
      throw StateError('Mirror HTTP ${manifestResponse.statusCode}');
    }

    final payload = jsonDecode(manifestResponse.body) as Map<String, dynamic>;
    final manifest = payload['manifest'] as Map<String, dynamic>? ?? {};
    final documents = (manifest['documents'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>();
    final microblogs = (manifest['microblogs'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>();

    final items = <FeedItem>[];
    for (final document in documents) {
      items.add(await _documentItem(document));
    }
    for (final microblog in microblogs) {
      items.add(_microblogItem(microblog));
    }

    items.sort(
      (a, b) => (b.date ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
        a.date ?? DateTime.fromMillisecondsSinceEpoch(0),
      ),
    );
    return items;
  }

  Future<FeedItem> _documentItem(Map<String, dynamic> document) async {
    final blobHash = document['blob_hash']?.toString();
    var body = '';
    if (blobHash != null) {
      final response = await _client.get(
        Uri.parse('$baseUrl/public/blobs/${Uri.encodeComponent(blobHash)}'),
      );
      if (response.statusCode == 200) {
        final blob = jsonDecode(response.body) as Map<String, dynamic>;
        body = blob['document']?.toString() ?? '';
      }
    }

    return FeedItem(
      id: 'document-${document['id']}',
      modelId: int.tryParse(document['id']?.toString() ?? ''),
      kind: FeedItemKind.document,
      title: document['title']?.toString() ?? 'Untitled',
      text: shorten(body.isEmpty ? document['title']?.toString() ?? '' : body),
      date: parseDate(document['updated_at']),
      topics: topicTags(document['tags']),
    );
  }

  FeedItem _microblogItem(Map<String, dynamic> microblog) {
    final media = (microblog['media'] as List<dynamic>?)
        ?.whereType<Map<String, dynamic>>()
        .map(_feedMedia)
        .whereType<FeedMedia>()
        .toList(growable: false);
    return FeedItem(
      id: 'microblog-${microblog['id']}',
      modelId: int.tryParse(microblog['id']?.toString() ?? ''),
      kind: FeedItemKind.microblog,
      title: '',
      text: microblog['text']?.toString() ?? '',
      date: parseDate(microblog['posted_at']),
      topics: topicTags(microblog['tags']),
      media: media ?? const [],
    );
  }

  FeedMedia? _feedMedia(Map<String, dynamic> media) {
    final type = media['type']?.toString();
    final url =
        media['thumbnail_url']?.toString() ??
        media['url']?.toString() ??
        media['blob_hash']?.toString();
    if (type == null || url == null || url.isEmpty) return null;

    final isBlob = url.startsWith('sha256:');
    return FeedMedia(
      type: type == 'youtube' || type == 'embed' || type.startsWith('video')
          ? FeedMediaType.video
          : FeedMediaType.image,
      previewUrl: isBlob
          ? '$baseUrl/public/blobs/${Uri.encodeComponent(url)}'
          : url,
      layout: MediaLayout.wide,
      raw: Map<String, dynamic>.from(media),
    );
  }
}

enum FeedItemKind { document, microblog }

class FeedItem {
  const FeedItem({
    required this.id,
    required this.modelId,
    required this.kind,
    required this.title,
    required this.text,
    required this.date,
    required this.topics,
    this.media = const [],
  });

  final String id;
  final int? modelId;
  final FeedItemKind kind;
  final String title;
  final String text;
  final DateTime? date;
  final List<String> topics;
  final List<FeedMedia> media;
}

enum FeedMediaType { image, video }

enum MediaLayout { wide, square, portrait }

class FeedMedia {
  const FeedMedia({
    required this.type,
    required this.previewUrl,
    required this.layout,
    required this.raw,
  });

  final FeedMediaType type;
  final String? previewUrl;
  final MediaLayout layout;
  final Map<String, dynamic> raw;
}

List<String> topicTags(Object? tags) {
  if (tags is! Map<String, dynamic>) return const [];
  final topic = tags['Topic'];
  if (topic is! List) return const [];
  return topic
      .map((item) => item.toString())
      .where((item) => item.isNotEmpty)
      .toList()
    ..sort();
}

DateTime? parseDate(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

String formatDate(DateTime? date, {bool includeTime = false}) {
  if (date == null) return 'Undated';
  final local = date.toLocal();
  return includeTime
      ? DateFormat('MMM d, y · h:mm a').format(local)
      : DateFormat('MMM d, y').format(local);
}

String formatDateTime(DateTime date) {
  return DateFormat('MMM d, y · h:mm a').format(date.toLocal());
}

String shorten(String value) {
  final clean = value
      .replaceAll(r'\n', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (clean.isEmpty) return 'A published document from the mirror.';
  return clean.length > 220 ? '${clean.substring(0, 220).trim()}...' : clean;
}

String? firstNonEmpty(Iterable<String?> values) {
  for (final value in values) {
    final clean = value?.trim();
    if (clean != null && clean.isNotEmpty) return clean;
  }
  return null;
}

String microblogContentHash({
  required String text,
  required List<Map<String, dynamic>> media,
  required String? topic,
}) {
  final envelope = {
    'format': 'nexus_microblog',
    'media': media,
    'tags': {
      'Topic': topic == null || topic.isEmpty ? <String>[] : [topic],
    },
    'text': text,
  };
  final encoded = canonicalJson(envelope);
  return 'sha256:${sha256.convert(utf8.encode(encoded))}';
}

String canonicalJson(Object? value) {
  if (value is Map) {
    final entries = value.entries.toList()
      ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
    return '{${entries.map((entry) {
      return '${jsonEncode(entry.key.toString())}:${canonicalJson(entry.value)}';
    }).join(',')}}';
  }
  if (value is Iterable) {
    return '[${value.map(canonicalJson).join(',')}]';
  }
  return jsonEncode(value);
}
