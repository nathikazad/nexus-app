import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_db/kgql.dart';

const mirrorPublicUrl = String.fromEnvironment(
  'MIRROR_PUBLIC_URL',
  defaultValue: 'http://188.245.46.13:8787',
);
void main() {
  runApp(const NexusPostApp());
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

class PostAppShell extends StatefulWidget {
  const PostAppShell({super.key});

  @override
  State<PostAppShell> createState() => _PostAppShellState();
}

class _PostAppShellState extends State<PostAppShell> {
  PostSession? _session;

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null) {
      return PostLoginScreen(
        onLogin: (value) => setState(() => _session = value),
      );
    }
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
}

class PostLoginScreen extends StatefulWidget {
  const PostLoginScreen({required this.onLogin, super.key});

  final ValueChanged<PostSession> onLogin;

  @override
  State<PostLoginScreen> createState() => _PostLoginScreenState();
}

class _PostLoginScreenState extends State<PostLoginScreen> {
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

  void _login() {
    if (!_formKey.currentState!.validate()) return;
    final urls = resolve(_selectedPreset);
    widget.onLogin(
      PostSession(
        userId: _selectedProfile.userId,
        mcpUrl: normalizeEndpoint(urls.imageHttp),
        graphqlUrl: urls.graphqlHttp,
        mirrorUrl: mirrorPublicUrl,
      ),
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
  String _selectedTopic = 'All Topics';
  final Set<String> _deletedItemIds = {};

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
              final visibleItems =
                  (_selectedTopic == 'All Topics'
                          ? items
                          : items.where(
                              (item) => item.topics.contains(_selectedTopic),
                            ))
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
                          child: FeedHeader(
                            topics: topics,
                            selectedTopic: _selectedTopic,
                            onTopicChanged: (topic) {
                              setState(() => _selectedTopic = topic);
                            },
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
                        separatorBuilder: (_, _) => const SizedBox(height: 52),
                        itemBuilder: (context, index) {
                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 672),
                              child: FeedItemView(
                                item: visibleItems[index],
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
      topics.addAll(item.topics);
    }
    return ['All Topics', ...topics.toList()..sort()];
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
      await widget.postRepository.deleteMicroblog(modelId);
      if (!mounted) return;
      setState(() => _deletedItemIds.add(item.id));
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microblog deleted. Publishing queued.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete microblog: $error')),
      );
    }
  }
}

class FeedHeader extends StatelessWidget {
  const FeedHeader({
    required this.topics,
    required this.selectedTopic,
    required this.onTopicChanged,
    super.key,
  });

  final List<String> topics;
  final String selectedTopic;
  final ValueChanged<String> onTopicChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DecoratedBox(
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
              DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xfff4f4f5),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(left: 14, right: 8),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: topics.contains(selectedTopic)
                          ? selectedTopic
                          : 'All Topics',
                      borderRadius: BorderRadius.circular(12),
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: Color(0xff71717a),
                      ),
                      dropdownColor: Colors.white,
                      style: const TextStyle(
                        color: Color(0xff3f3f46),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      items: topics
                          .map(
                            (topic) => DropdownMenuItem(
                              value: topic,
                              child: Text(topic),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) onTopicChanged(value);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FeedItemView extends StatelessWidget {
  const FeedItemView({
    required this.item,
    required this.onDeleteMicroblog,
    super.key,
  });

  final FeedItem item;
  final ValueChanged<FeedItem> onDeleteMicroblog;

  @override
  Widget build(BuildContext context) {
    return item.kind == FeedItemKind.document
        ? DocumentFeedItem(item: item)
        : MicroblogFeedItem(item: item, onDelete: onDeleteMicroblog);
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
        const SizedBox(height: 10),
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
    required this.onDelete,
    super.key,
  });

  final FeedItem item;
  final ValueChanged<FeedItem> onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FeedMeta(
                date: item.date,
                topic: item.topics.firstOrNull,
                includeTime: true,
              ),
            ),
            IconButton(
              tooltip: 'Delete post',
              visualDensity: VisualDensity.compact,
              onPressed: () => onDelete(item),
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xffa1a1aa),
                size: 20,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          item.text,
          style: const TextStyle(
            color: Color(0xff52525b),
            fontSize: 15,
            height: 1.7,
          ),
        ),
        if (item.media != null) ...[
          const SizedBox(height: 16),
          FeedMediaPreview(media: item.media!),
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

class FeedMediaPreview extends StatelessWidget {
  const FeedMediaPreview({required this.media, super.key});

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
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (media.previewUrl != null)
                  Image.network(
                    media.previewUrl!,
                    fit: BoxFit.cover,
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
            ),
          ),
        ),
      ),
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
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => ComposeSheet(repository: repository),
  );
}

class ComposeSheet extends StatefulWidget {
  const ComposeSheet({required this.repository, super.key});

  final MicroblogPostRepository repository;

  @override
  State<ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<ComposeSheet> {
  final _textController = TextEditingController();
  final _mediaController = TextEditingController();
  String? _topic;
  bool _publishEnabled = true;
  bool _saving = false;

  @override
  void dispose() {
    _textController.dispose();
    _mediaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, bottomInset + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'New microblog',
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
          DropdownButtonFormField<String?>(
            initialValue: _topic,
            decoration: inputDecoration('Topic (optional)'),
            items: const [
              DropdownMenuItem<String?>(value: null, child: Text('No topic')),
              DropdownMenuItem<String?>(
                value: 'Spiritual',
                child: Text('Spiritual'),
              ),
              DropdownMenuItem<String?>(
                value: 'Architecture',
                child: Text('Architecture'),
              ),
              DropdownMenuItem<String?>(
                value: 'Personal',
                child: Text('Personal'),
              ),
              DropdownMenuItem<String?>(
                value: 'Economics',
                child: Text('Economics'),
              ),
            ],
            onChanged: (value) {
              setState(() => _topic = value);
            },
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _mediaController,
            decoration: inputDecoration('Image, YouTube, or Instagram URL'),
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _publishEnabled,
            activeThumbColor: const Color(0xff18181b),
            title: const Text('Publish to mirror'),
            subtitle: const Text('Triggers the mirror publisher after saving.'),
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
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save microblog'),
            ),
          ),
        ],
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
    setState(() => _saving = true);
    try {
      await widget.repository.createMicroblog(
        text: text,
        topic: _topic,
        mediaUrl: _mediaController.text.trim(),
        publishEnabled: _publishEnabled,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microblog saved. Publishing queued.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save microblog: $error')),
      );
    }
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
    required String? topic,
    required String mediaUrl,
    required bool publishEnabled,
  }) async {
    final cleanText = text.trim();
    final cleanTopic = topic?.trim();
    final media = mediaUrl.isEmpty
        ? <Map<String, dynamic>>[]
        : [_mediaFromUrl(mediaUrl)];
    final now = DateTime.now().toUtc().toIso8601String();
    final contentHash = microblogContentHash(
      text: cleanText,
      media: media,
      topic: cleanTopic == null || cleanTopic.isEmpty ? null : cleanTopic,
    );

    await setKgqlModel(
      _graphqlClient,
      SetModelRequest(
        modelType: 'Microblog',
        name: _nameFromText(cleanText),
        attributes: [
          SetModelAttribute(key: 'text', value: cleanText),
          SetModelAttribute(key: 'created_at', value: now),
          SetModelAttribute(key: 'updated_at', value: now),
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
        tags: cleanTopic == null || cleanTopic.isEmpty
            ? null
            : [
                SetModelTag(system: 'Topic', nodes: [cleanTopic]),
              ],
      ),
      domainId: await _domainId(),
      auditSourceKind: 'nx_post',
    );

    if (publishEnabled) {
      await triggerPublish(reason: 'microblog_post');
    }
  }

  Future<void> deleteMicroblog(int id) async {
    await setKgqlModel(
      _graphqlClient,
      SetModelRequest(id: id, delete: true),
      domainId: await _domainId(),
      auditSourceKind: 'nx_post',
    );
    await triggerPublish(reason: 'microblog_delete');
  }

  Future<void> triggerPublish({required String reason}) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/mirror/publish/trigger'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'reason': reason, 'immediate': true}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(_httpErrorMessage(response));
    }
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
        .firstOrNull;
    return FeedItem(
      id: 'microblog-${microblog['id']}',
      modelId: int.tryParse(microblog['id']?.toString() ?? ''),
      kind: FeedItemKind.microblog,
      title: '',
      text: microblog['text']?.toString() ?? '',
      date:
          parseDate(microblog['updated_at']) ??
          parseDate(microblog['created_at']),
      topics: topicTags(microblog['tags']),
      media: media,
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
    this.media,
  });

  final String id;
  final int? modelId;
  final FeedItemKind kind;
  final String title;
  final String text;
  final DateTime? date;
  final List<String> topics;
  final FeedMedia? media;
}

enum FeedMediaType { image, video }

enum MediaLayout { wide, square, portrait }

class FeedMedia {
  const FeedMedia({
    required this.type,
    required this.previewUrl,
    required this.layout,
  });

  final FeedMediaType type;
  final String? previewUrl;
  final MediaLayout layout;
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

String shorten(String value) {
  final clean = value
      .replaceAll(r'\n', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (clean.isEmpty) return 'A published document from the mirror.';
  return clean.length > 220 ? '${clean.substring(0, 220).trim()}...' : clean;
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
