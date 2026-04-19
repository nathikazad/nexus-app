import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nx_db/auth.dart';
import 'package:nexus_voice_assistant/core/widgets/timeline_slider.dart';
import 'package:nexus_voice_assistant/data/images/image_service.dart';
import 'package:nexus_voice_assistant/domain/images/image_entry.dart';
import 'package:nexus_voice_assistant/features/data_browser/images_view_model.dart';

/// Browse images by day for necklace or desktop capture sources.
class ImagesPage extends ConsumerStatefulWidget {
  const ImagesPage({super.key, required this.source});

  /// `necklace` or `desktop` (matches server `source` query param).
  final String source;

  @override
  ConsumerState<ImagesPage> createState() => _ImagesPageState();
}

class _ImagesPageState extends ConsumerState<ImagesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(imagesViewModelProvider(widget.source).notifier).loadDates();
    });
  }

  String get _title =>
      widget.source == 'desktop' ? 'Desktop Images' : 'Necklace Images';

  String _formatTimeLabel(DateTime selected, ImageEntry? e) {
    if (e == null) return '—';
    final secs =
        (e.minutesSinceMidnight * 60).round().clamp(0, 24 * 3600 - 1);
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    final s = secs % 60;
    final dt = DateTime(
      selected.year,
      selected.month,
      selected.day,
      h,
      m,
      s,
    );
    return DateFormat.jm().format(dt);
  }

  Future<void> _pickDate(ImagesViewState vm) async {
    if (vm.available.isEmpty) return;

    final first = vm.available.reduce((a, b) => a.isBefore(b) ? a : b);
    final last = vm.available.reduce((a, b) => a.isAfter(b) ? a : b);

    final picked = await showDatePicker(
      context: context,
      initialDate: vm.selected.isBefore(first)
          ? first
          : (vm.selected.isAfter(last) ? last : vm.selected),
      firstDate: first,
      lastDate: last,
      selectableDayPredicate: (d) {
        final day = DateTime(d.year, d.month, d.day);
        return vm.available.contains(day);
      },
    );
    if (picked != null && mounted) {
      await ref
          .read(imagesViewModelProvider(widget.source).notifier)
          .applyPickedDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(imagesViewModelProvider(widget.source));
    final notifier =
        ref.read(imagesViewModelProvider(widget.source).notifier);

    ref.listen(imagesViewModelProvider(widget.source), (prev, next) {
      final msg = next.transientNotice;
      if (msg != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
        notifier.clearTransientNotice();
      }
    });

    final base = ref.watch(imageBaseUrlProvider);
    final uid = ref.watch(userIdProvider);

    final idx = imagesCurrentIndex(vm);
    final entry = imagesEntryForSlider(vm, vm.sliderValue);

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
      ),
      body: vm.loading
          ? const Center(child: CircularProgressIndicator())
          : vm.error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          vm.error!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: notifier.loadDates,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (vm.available.isEmpty)
                        const Text(
                          'No images for this source yet.',
                          style: TextStyle(color: Colors.grey),
                        )
                      else ...[
                        OutlinedButton.icon(
                          onPressed: () => _pickDate(vm),
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            DateFormat.yMMMd().format(vm.selected),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (vm.loadingDay)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (vm.dayEntries.isEmpty)
                          Text(
                            'No images on ${DateFormat.yMMMd().format(vm.selected)}.',
                            style: TextStyle(color: Colors.grey.shade600),
                          )
                        else ...[
                          TimelineSlider(
                            value: vm.sliderValue,
                            minTime: vm.minTime,
                            maxTime: vm.maxTime,
                            marks: vm.dayEntries
                                .map((e) => e.minutesSinceMidnight)
                                .toList(),
                            onChanged: notifier.setSlider,
                          ),
                          const SizedBox(height: 8),
                          Builder(
                            builder: (context) {
                              final canPrev = idx > 0;
                              final canNext =
                                  idx >= 0 && idx < vm.dayEntries.length - 1;
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    onPressed: canPrev ? notifier.stepPrev : null,
                                    icon: const Icon(Icons.chevron_left),
                                    tooltip: 'Previous image',
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Time: ${_formatTimeLabel(vm.selected, entry)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: canNext ? notifier.stepNext : null,
                                    icon: const Icon(Icons.chevron_right),
                                    tooltip: 'Next image',
                                  ),
                                ],
                              );
                            },
                          ),
                          if (entry?.currentApp != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              entry!.currentApp!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: Colors.grey.shade700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            entry?.filename ?? '',
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: _buildImage(
                                context,
                                base,
                                uid,
                                entry,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildImage(
    BuildContext context,
    String? baseUrl,
    String? userId,
    ImageEntry? entry,
  ) {
    if (baseUrl == null ||
        userId == null ||
        userId.isEmpty ||
        entry == null) {
      return ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(
          child: Icon(Icons.image_not_supported_outlined, size: 48),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: entry.url,
      cacheManager: imageCacheManager,
      httpHeaders: imageHeaders(baseUrl, userId),
      fit: BoxFit.contain,
      placeholder: (context, url) => const Center(
        child: CircularProgressIndicator(),
      ),
      errorWidget: (context, url, error) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Could not load image\n$error',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
