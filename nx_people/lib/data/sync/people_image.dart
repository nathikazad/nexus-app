import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_people/data/sync/people_sync_providers.dart';

final peopleImageBytesProvider = FutureProvider.autoDispose
    .family<Uint8List, String>((ref, url) {
      ref.watch(peopleDataGenerationProvider);
      final assets = ref.watch(peopleAssetsProvider);
      if (assets == null) throw StateError('Sign in to view this image');
      return assets.read(url);
    });

class PeopleImage extends ConsumerWidget {
  const PeopleImage(
    this.url, {
    super.key,
    this.headers,
    this.height,
    this.width,
    this.fit,
    this.errorBuilder,
    this.loadingBuilder,
  });
  final String url;
  final Map<String, String>? headers;
  final double? height, width;
  final BoxFit? fit;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ImageLoadingBuilder? loadingBuilder;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assets = ref.watch(peopleAssetsProvider);
    final uri = Uri.tryParse(url);
    if (!url.startsWith('people-local:') &&
        uri?.hasAuthority == true &&
        uri?.origin != assets?.remote.reads.origin.origin) {
      return Image.network(
        url,
        height: height,
        width: width,
        fit: fit,
        errorBuilder: errorBuilder,
      );
    }
    final bytes = ref.watch(peopleImageBytesProvider(url));
    return bytes.when(
      data: (value) => Image.memory(
        value,
        height: height,
        width: width,
        fit: fit,
        errorBuilder: errorBuilder,
      ),
      loading: () => SizedBox(
        height: height,
        width: width,
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, stack) =>
          errorBuilder?.call(context, e, stack) ??
          SizedBox(
            height: height,
            width: width,
            child: const Center(child: Text('Image unavailable offline')),
          ),
    );
  }
}
