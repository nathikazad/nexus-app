import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:nx_db/auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import '../../data/sync/expense_sync_providers.dart';

final receiptBytesProvider = FutureProvider.autoDispose
    .family<Uint8List, ({String filename, String? hash})>((ref, key) async {
      final cache = ref.watch(expenseAssetsProvider);
      if (cache == null) throw StateError('Sign in to view this receipt');
      return cache.read(key.filename, hash: key.hash);
    });

class ReceiptFileView extends ConsumerWidget {
  const ReceiptFileView({
    super.key,
    required this.url,
    this.hash,
    this.fit = BoxFit.contain,
  });
  final String url;
  final String? hash;
  final BoxFit fit;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(authProvider).value?.sessionKey;
    final filename = Uri.parse(url).queryParameters['name'] ?? '';
    final key = (filename: filename, hash: hash);
    return ref
        .watch(receiptBytesProvider(key))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: TextButton(
              onPressed: () => ref.invalidate(receiptBytesProvider(key)),
              child: const Text('Retry receipt'),
            ),
          ),
          data: (bytes) => filename.toLowerCase().endsWith('.pdf')
              ? PdfViewer.data(
                  bytes,
                  key: ValueKey('$account:$filename:${sha256.convert(bytes)}'),
                  sourceName: '$account:$filename:${sha256.convert(bytes)}',
                )
              : Image.memory(
                  bytes,
                  fit: fit,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.broken_image_outlined),
                ),
        );
  }
}

class ReceiptPdfView extends StatelessWidget {
  const ReceiptPdfView({super.key, required this.url, this.hash});
  final String url;
  final String? hash;
  @override
  Widget build(BuildContext context) => ReceiptFileView(url: url, hash: hash);
}
