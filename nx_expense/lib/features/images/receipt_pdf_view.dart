import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';
import 'package:pdfrx/pdfrx.dart';

/// Fetch through the authenticated client; never put credentials in a PDF URL.
class ReceiptPdfView extends ConsumerStatefulWidget {
  const ReceiptPdfView({super.key, required this.url});
  final String url;
  @override
  ConsumerState<ReceiptPdfView> createState() => _ReceiptPdfViewState();
}

class _ReceiptPdfViewState extends ConsumerState<ReceiptPdfView> {
  Future<Uint8List>? _bytes;
  Object? _client;
  String? _session;
  String? _url;

  @override
  Widget build(BuildContext context) {
    final client = ref.watch(nexusHttpClientProvider);
    final session = ref.watch(authProvider).value?.sessionKey;
    if (client == null || session == null) {
      return const Center(child: Text('Sign in to view this receipt.'));
    }
    if (_client != client || _session != session || _url != widget.url) {
      _client = client;
      _session = session;
      _url = widget.url;
      _bytes = client.get(Uri.parse(widget.url)).then((response) {
        if (response.statusCode != 200) {
          throw StateError('Unable to load PDF (${response.statusCode})');
        }
        return response.bodyBytes;
      });
    }
    return FutureBuilder<Uint8List>(
      key: ValueKey('$session:${widget.url}'),
      future: _bytes,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(() => _url = null),
              child: const Text('Unable to load PDF. Retry'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return PdfViewer.data(
          snapshot.data!,
          sourceName: '$session:${widget.url}',
        );
      },
    );
  }
}
