import 'package:nx_expense/data/sync/expense_sync_providers.dart';
import 'package:file_picker/file_picker.dart';
import 'receipt_pdf_view.dart';
import 'package:nx_expense/features/shell/expense_app_end_drawer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_expense/core/theme/app_theme.dart';
import 'package:nx_expense/data/images/expense_image_upload_api.dart';
import 'package:nx_expense/data/images/expense_images.dart';
import 'package:nx_expense/data/teller/expense_timeline_api.dart';
import 'package:nx_expense/domain/images/expense_image.dart';
import 'package:nx_expense/features/desktop/desktop_nav.dart';

final expenseImagePickerProvider = Provider<ImagePicker>(
  (ref) => ImagePicker(),
);

class ExpenseImagesScreen extends ConsumerStatefulWidget {
  const ExpenseImagesScreen({super.key, this.filter = 'all'});
  final String filter;
  @override
  ConsumerState<ExpenseImagesScreen> createState() =>
      _ExpenseImagesScreenState();
}

class _ExpenseImagesScreenState extends ConsumerState<ExpenseImagesScreen> {
  bool _uploading = false;
  String? get _session {
    final user = ref.read(authProvider).value;
    return user?.domainId == null ? null : user!.sessionKey;
  }

  Future<void> _upload() async {
    if (_uploading) return;
    final session = _session;
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign in and select a domain to upload images.'),
        ),
      );
      return;
    }
    final cameraAvailable =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android);
    final source = await showModalBottomSheet<Object>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (cameraAvailable)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Choose PDF'),
              onTap: () => Navigator.pop(context, 'pdf'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose image'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final pdf = source == 'pdf';
      XFile? file;
      if (pdf) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          withData: true,
        );
        if (result != null) {
          file = result.xFiles.single;
        }
      } else {
        file = await ref
            .read(expenseImagePickerProvider)
            .pickImage(source: source as ImageSource, imageQuality: 85);
      }
      if (file == null || !mounted || _session != session) {
        return;
      }
      final base = ref.read(imageBaseUrlProvider);
      final userId = ref.read(userIdProvider);
      final client = ref.read(nexusHttpClientProvider);
      if (base == null || userId == null || client == null) {
        throw StateError('Sign in to upload an image');
      }
      final bytes = await file.readAsBytes();
      if (!mounted || _session != session) {
        return;
      }
      final png = file.name.toLowerCase().endsWith('.png');
      await uploadExpenseSnapshot(
        imageBaseUrl: base,
        userId: userId,
        domainId: ref.read(authProvider).value!.requiredDomainId,
        bytes: bytes,
        filename: pdf
            ? 'upload.pdf'
            : png
            ? 'upload.png'
            : 'upload.jpg',
        imageContentType: pdf
            ? MediaType('application', 'pdf')
            : MediaType('image', png ? 'png' : 'jpeg'),
        httpClient: client,
      );
      if (!mounted || _session != session) {
        return;
      }
      ref.read(expenseTransportProvider)?.reads.invalidate();
      ref.invalidate(expenseImagesProvider);
      // New standalone uploads are unlinked and must be visible after success.
      if (widget.filter == 'linked') context.go('/images?filter=unlinked');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receipt uploaded. Ready to reconcile later.'),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not upload the image. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final images = ref.watch(expenseImagesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Images'),
        automaticallyImplyLeading: false,
        leading: !isDesktopLayout(context)
            ? BackButton(
                onPressed: () => navBack(context, fallback: '/expenses'),
              )
            : null,
        actions: [
          IconButton(
            tooltip: 'Refresh images',
            onPressed: () => ref.invalidate(expenseImagesProvider),
            icon: const Icon(Icons.refresh),
          ),
          const ExpenseAppMenuButton(),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploading ? null : _upload,
        icon: _uploading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add_photo_alternate_outlined),
        label: Text(_uploading ? 'Uploading…' : 'Add receipt'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Wrap(
              spacing: 8,
              children: [
                for (final entry in const {
                  'all': 'All',
                  'unlinked': 'Unlinked',
                  'linked': 'Linked',
                }.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: widget.filter == entry.key,
                    onSelected: (_) =>
                        context.go('/images?filter=${entry.key}'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: images.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(expenseImagesProvider),
                  child: const Text('Unable to load images. Retry'),
                ),
              ),
              data: (all) {
                final rows = all
                    .where(
                      (image) => widget.filter == 'linked'
                          ? image.isLinked
                          : widget.filter == 'unlinked'
                          ? !image.isLinked
                          : true,
                    )
                    .toList();
                if (rows.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.photo_library_outlined,
                            size: 48,
                            color: AppColors.slate400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.filter == 'all'
                                ? 'No expense images yet'
                                : 'No ${widget.filter} images',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Upload a receipt now. Link it to an expense or order later.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(expenseImagesProvider);
                    await ref.read(expenseImagesProvider.future);
                  },
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    physics: const AlwaysScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 250,
                          mainAxisExtent: 252,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final image = rows[index];
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => navPush(
                            context,
                            Uri(
                              path: '/images/${image.id}',
                              queryParameters: {
                                'time': formatTimelineLocalTimestamp(
                                  image.time,
                                ),
                              },
                            ).toString(),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: ExpenseImageView(
                                  image: image,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      DateFormat(
                                        'MMM d, y · h:mm a',
                                      ).format(image.time),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelMedium,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      image.isLinked
                                          ? 'Linked · ${image.links.length}'
                                          : 'Unlinked',
                                      style: TextStyle(
                                        color: image.isLinked
                                            ? AppColors.teal700
                                            : AppColors.slate500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ExpenseImageView extends ConsumerWidget {
  const ExpenseImageView({
    super.key,
    required this.image,
    this.fit = BoxFit.contain,
  });
  final ExpenseImage image;
  final BoxFit fit;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final base = ref.watch(imageBaseUrlProvider);

    if (base == null || image.filename.isEmpty) {
      return const Center(child: Icon(Icons.image_not_supported_outlined));
    }
    final uri = Uri.parse(
      '${normalizeHttpEndpoint(base).replaceAll(RegExp(r'/+$'), '')}/images/file',
    ).replace(queryParameters: {'name': image.filename}).toString();
    if (image.filename.toLowerCase().endsWith('.pdf')) {
      if (fit == BoxFit.cover) {
        return const Center(
          child: Icon(Icons.picture_as_pdf_outlined, size: 64),
        );
      }
      return ReceiptPdfView(url: uri, hash: image.hash);
    }
    return ReceiptFileView(url: uri, hash: image.hash, fit: fit);
  }
}

class ExpenseImageDetailScreen extends ConsumerWidget {
  const ExpenseImageDetailScreen({
    super.key,
    required this.id,
    required this.time,
  });
  final String id;
  final String? time;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timestamp = DateTime.tryParse(time ?? '');
    if (timestamp == null) {
      return const NavigationErrorScreen(message: 'Missing image date');
    }
    final image = ref.watch(expenseImageProvider((id: id, time: timestamp)));
    return image.when(
      loading: () => const NavigationLoadingScreen(),
      error: (_, _) => Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: () => navBack(context))),
        body: Center(
          child: TextButton(
            onPressed: () =>
                ref.invalidate(expenseImageProvider((id: id, time: timestamp))),
            child: const Text('Unable to load image. Retry'),
          ),
        ),
      ),
      data: (image) {
        if (image == null) {
          return const NavigationErrorScreen(message: 'Image not found');
        }
        return Scaffold(
          appBar: AppBar(
            leading: BackButton(onPressed: () => navBack(context)),
            title: const Text('Expense image'),
            actions: [
              IconButton(
                tooltip: 'Full screen',
                icon: const Icon(Icons.fullscreen),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => Dialog.fullscreen(
                    child: Scaffold(
                      appBar: AppBar(
                        leading: CloseButton(
                          onPressed: () => Navigator.pop(context),
                        ),
                        title: const Text('Expense image'),
                      ),
                      body: InteractiveViewer(
                        minScale: .5,
                        maxScale: 5,
                        child: ExpenseImageView(image: image),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: ColoredBox(
                  color: AppColors.slate100,
                  child: InteractiveViewer(
                    minScale: .5,
                    maxScale: 5,
                    child: ExpenseImageView(image: image),
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Uploaded ${DateFormat('MMM d, y · h:mm a').format(image.time)}',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 12),
                        if (!image.isLinked)
                          const Text('Unlinked · Ready to reconcile later.'),
                        for (final link in image.links)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              link.type == 'Order'
                                  ? Icons.shopping_bag_outlined
                                  : Icons.receipt_long_outlined,
                            ),
                            title: Text(link.name),
                            subtitle: Text(link.type),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => navPush(
                              context,
                              link.type == 'Order'
                                  ? '/orders/${link.id}'
                                  : '/expense/${link.id}',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
