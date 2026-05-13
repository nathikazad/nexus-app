import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nx_db/nx_db.dart';
import 'package:nx_time/core/widgets/timeline_slider.dart';
import 'package:nx_time/features/images/images_view_model.dart';

/// Browse images by day for necklace or desktop capture sources.
class ImagesPage extends ConsumerStatefulWidget {
  const ImagesPage({super.key, this.initialSource = 'desktop'})
    : assert(
        initialSource == 'necklace' || initialSource == 'desktop',
        'initialSource must be necklace or desktop',
      );

  /// Starting capture channel; use the app bar action to switch at runtime.
  ///
  /// Matches server `source` query param (`necklace` | `desktop`).
  /// Copy this screen and change [initialSource] for a different default (e.g. necklace).
  final String initialSource;

  @override
  ConsumerState<ImagesPage> createState() => _ImagesPageState();
}

class _ImagesPageState extends ConsumerState<ImagesPage> {
  late String _source;

  @override
  void initState() {
    super.initState();
    _source = widget.initialSource;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(imagesViewModelProvider(_source).notifier).loadDates();
    });
  }

  void _switchSource() {
    final next = _source == 'necklace' ? 'desktop' : 'necklace';
    setState(() => _source = next);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(imagesViewModelProvider(_source).notifier).loadDates();
    });
  }

  String get _title =>
      _source == 'desktop' ? 'Desktop Images' : 'Necklace Images';

  String _formatTimeLabel(DateTime selected, ImageEntry? e) {
    if (e == null) return '—';
    final secs = (e.minutesSinceMidnight * 60).round().clamp(0, 24 * 3600 - 1);
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    final s = secs % 60;
    final dt = DateTime(selected.year, selected.month, selected.day, h, m, s);
    return DateFormat.jm().format(dt);
  }

  Future<void> _pickDate(ImagesViewState vm) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    late final DateTime firstDate;
    late final DateTime lastDate;
    late final DateTime? initialDate;
    late final bool Function(DateTime day) selectablePredicate;

    if (vm.available.isEmpty) {
      firstDate = today.subtract(const Duration(days: 365 * 5));
      lastDate = today;
      initialDate = null;
      selectablePredicate = (_) => false;
    } else {
      firstDate = vm.available.reduce((a, b) => a.isBefore(b) ? a : b);
      lastDate = vm.available.reduce((a, b) => a.isAfter(b) ? a : b);
      var initial = DateTime(
        vm.selected.year,
        vm.selected.month,
        vm.selected.day,
      );
      if (initial.isBefore(firstDate)) initial = firstDate;
      if (initial.isAfter(lastDate)) initial = lastDate;
      initialDate = initial;
      selectablePredicate = (DateTime d) {
        final day = DateTime(d.year, d.month, d.day);
        return vm.available.contains(day);
      };
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      selectableDayPredicate: selectablePredicate,
    );
    if (picked != null && mounted) {
      await ref
          .read(imagesViewModelProvider(_source).notifier)
          .applyPickedDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(imagesViewModelProvider(_source));
    final notifier = ref.read(imagesViewModelProvider(_source).notifier);

    ref.listen(imagesViewModelProvider(_source), (prev, next) {
      final msg = next.transientNotice;
      if (msg != null && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
        notifier.clearTransientNotice();
      }
    });

    final base = ref.watch(imageBaseUrlProvider);
    final uid = ref.watch(userIdProvider);

    final idx = imagesCurrentIndex(vm);
    final entry = imagesEntryForSlider(vm, vm.sliderValue);

    final metaCaptionStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700);

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(
            icon: Icon(
              _source == 'necklace' ? Icons.desktop_windows : Icons.camera_alt,
            ),
            tooltip: _source == 'necklace'
                ? 'Switch to desktop images'
                : 'Switch to necklace images',
            onPressed: _switchSource,
          ),
        ],
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
                    Text(vm.error!, textAlign: TextAlign.center),
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
                  OutlinedButton.icon(
                    onPressed: () => _pickDate(vm),
                    icon: const Icon(Icons.calendar_today),
                    label: Text(DateFormat.yMMMd().format(vm.selected)),
                  ),
                  const SizedBox(height: 12),
                  if (vm.loadingDay)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (vm.dayEntries.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          'No images on ${DateFormat.yMMMd().format(vm.selected)}.',
                          style: TextStyle(color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Builder(
                            builder: (context) {
                              final canPrev = idx > 0;
                              final canNext =
                                  idx >= 0 && idx < vm.dayEntries.length - 1;
                              final timeText = _formatTimeLabel(
                                vm.selected,
                                entry,
                              );

                              return Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    onPressed: canPrev
                                        ? notifier.stepPrev
                                        : null,
                                    icon: const Icon(Icons.chevron_left),
                                    tooltip: 'Previous image',
                                  ),
                                  Expanded(
                                    child: Text(
                                      timeText,
                                      style: metaCaptionStyle,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: canNext
                                        ? notifier.stepNext
                                        : null,
                                    icon: const Icon(Icons.chevron_right),
                                    tooltip: 'Next image',
                                  ),
                                ],
                              );
                            },
                          ),
                          if (_source == 'desktop') ...[
                            if (entry?.currentApp != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                entry!.currentApp!,
                                style: metaCaptionStyle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ] else ...[
                            if (entry?.currentApp != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                entry!.currentApp!,
                                style: metaCaptionStyle,
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
                          ],
                          const SizedBox(height: 12),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: _buildImage(context, base, uid, entry),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: EdgeInsets.only(
                              top: 4,
                              bottom: MediaQuery.paddingOf(context).bottom + 28,
                            ),
                            child: Align(
                              alignment: Alignment.center,
                              child: FractionallySizedBox(
                                widthFactor: 0.9,
                                child: TimelineSlider(
                                  value: vm.sliderValue,
                                  minTime: vm.minTime,
                                  maxTime: vm.maxTime,
                                  marks: vm.dayEntries
                                      .map((e) => e.minutesSinceMidnight)
                                      .toList(),
                                  onChanged: notifier.setSlider,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
    if (baseUrl == null || userId == null || userId.isEmpty || entry == null) {
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
      placeholder: (context, url) =>
          const Center(child: CircularProgressIndicator()),
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
