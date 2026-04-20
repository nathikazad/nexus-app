import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nx_db/auth.dart';
import 'package:http_parser/http_parser.dart';

import 'package:nx_expense/core/theme/app_theme.dart';
import 'package:nx_expense/data/images/expense_image_upload_api.dart';
import 'package:nx_expense/data/teller/expense_timeline_api.dart';
import 'package:nx_expense/core/layout/layout.dart';
import 'package:nx_expense/data/providers.dart';
import 'package:nx_expense/domain/teller/teller_link.dart';

String _basenameFromPayloadPath(Map<String, dynamic> payload) {
  final p = payload['path']?.toString();
  if (p == null || p.isEmpty) return '';
  return p.replaceAll('\\', '/').split('/').last;
}

/// Same rules as [normalizeHttpEndpointForCf] in nx_db (public API is @visibleForTesting).
String _normalizeImageBaseForCf(String url) {
  var ep = url;
  if (CfAccess.endpointNeedsCfAccess(ep) && ep.startsWith('http://')) {
    ep = ep.replaceFirst('http://', 'https://');
  }
  return ep;
}

Map<String, String> _imageGetHeaders(String imageBaseUrl, String userId) {
  final ep = _normalizeImageBaseForCf(imageBaseUrl);
  final h = <String, String>{'x-user-id': userId};
  if (CfAccess.shouldAttachHeaders(ep)) {
    h.addAll(CfAccess.headers);
  }
  return h;
}

Future<void> _showBillImageFullScreen(
  BuildContext context,
  String imageUrl,
  Map<String, String> headers,
) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (ctx) => _BillFullScreenPage(imageUrl: imageUrl, headers: headers),
    ),
  );
}

/// Expense detail / form: bill thumbnails + add (camera or library).
class ExpenseBillsSection extends ConsumerStatefulWidget {
  const ExpenseBillsSection({super.key, required this.expenseId});

  final int expenseId;

  @override
  ConsumerState<ExpenseBillsSection> createState() => _ExpenseBillsSectionState();
}

class _ExpenseBillsSectionState extends ConsumerState<ExpenseBillsSection> {
  bool _busy = false;
  final _picker = ImagePicker();

  Future<void> _run(Future<void> Function() fn) async {
    setState(() => _busy = true);
    try {
      await fn();
      if (!mounted) return;
      ref.invalidate(expenseTimelineLinksProvider(widget.expenseId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onRemove(TellerExpenseLink link) async {
    final client = ref.read(expenseGraphqlClientProvider);
    await _run(() => deleteExpenseTimelineLink(client, link.linkId));
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    final x = await _picker.pickImage(source: source, imageQuality: 85);
    if (x == null || !mounted) return;

    final base = ref.read(imageBaseUrlProvider);
    final uid = ref.read(userIdProvider);
    if (base == null || base.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image server URL is not configured.')),
        );
      }
      return;
    }
    if (uid == null || uid.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not signed in.')),
        );
      }
      return;
    }

    final bytes = await x.readAsBytes();
    final name = x.name;
    final lower = name.toLowerCase();
    final isPng = lower.endsWith('.png');
    final uploadName = isPng ? 'upload.png' : 'upload.jpg';
    final mediaType = isPng ? MediaType('image', 'png') : MediaType('image', 'jpeg');

    await _run(() async {
      final client = ref.read(expenseGraphqlClientProvider);
      final up = await uploadExpenseSnapshot(
        imageBaseUrl: base,
        userId: uid,
        bytes: bytes,
        filename: uploadName,
        imageContentType: mediaType,
      );
      await linkExpenseToTimelineEvent(
        client,
        modelId: widget.expenseId,
        eventTime: up.eventTime,
        eventId: up.eventId,
      );
    });
  }

  Future<void> _showSourceSheet() async {
    if (_busy) return;
    final choice = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from library'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    await _pickAndUpload(choice);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(expenseTimelineLinksProvider(widget.expenseId));
    final base = ref.watch(imageBaseUrlProvider);
    final uid = ref.watch(userIdProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: Text('Bills', style: refSectionTitle(context))),
            if (_busy)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.teal600),
              )
            else
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _busy ? null : _showSourceSheet,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.add_rounded,
                      size: 22,
                      color: AppColors.teal600,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text(
            'Could not load bills: $e',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate500),
          ),
          data: (links) {
            final bills = links.where((l) => l.isBillImageEvent).toList();
            if (base == null || base.isEmpty || uid == null || uid.isEmpty) {
              return Text(
                'Sign in and configure backend to attach bill photos.',
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.slate400),
              );
            }
            if (bills.isEmpty) {
              return Text(
                'No bill photos yet.',
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.slate400),
              );
            }
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final link in bills)
                  _BillThumb(
                    imageBaseUrl: base,
                    userId: uid,
                    filename: _basenameFromPayloadPath(link.payload),
                    onRemove: _busy ? null : () => _onRemove(link),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _BillThumb extends StatelessWidget {
  const _BillThumb({
    required this.imageBaseUrl,
    required this.userId,
    required this.filename,
    this.onRemove,
  });

  final String imageBaseUrl;
  final String userId;
  final String filename;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    if (filename.isEmpty) {
      return const SizedBox(width: 64, height: 64);
    }
    final baseRaw = imageBaseUrl.endsWith('/')
        ? imageBaseUrl.substring(0, imageBaseUrl.length - 1)
        : imageBaseUrl;
    final base = _normalizeImageBaseForCf(baseRaw);
    final uri = Uri.parse('$base/images/file').replace(
      queryParameters: {'name': filename},
    );
    final headers = _imageGetHeaders(imageBaseUrl, userId);

    final url = uri.toString();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showBillImageFullScreen(context, url, headers),
            borderRadius: BorderRadius.circular(RefLayout.rounded2xl),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(RefLayout.rounded2xl),
              child: Image.network(
                url,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                headers: headers,
                errorBuilder: (_, __, ___) => Container(
                  width: 64,
                  height: 64,
                  color: AppColors.slate100,
                  alignment: Alignment.center,
                  child: Icon(Icons.broken_image_outlined, color: AppColors.slate400, size: 28),
                ),
              ),
            ),
          ),
        ),
        if (onRemove != null)
          Positioned(
            top: -6,
            right: -6,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 1,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onRemove,
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.close_rounded, size: 16, color: AppColors.slate500),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _BillFullScreenPage extends StatelessWidget {
  const _BillFullScreenPage({
    required this.imageUrl,
    required this.headers,
  });

  final String imageUrl;
  final Map<String, String> headers;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 6,
              child: Image.network(
                imageUrl,
                headers: headers,
                fit: BoxFit.contain,
                width: size.width,
                height: size.height,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white.withValues(alpha: 0.9),
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white.withValues(alpha: 0.6),
                  size: 56,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: Icon(Icons.close_rounded, color: Colors.white.withValues(alpha: 0.95)),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
