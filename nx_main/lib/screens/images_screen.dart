import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nx_db/nx_db.dart';
import '../services/image_service.dart';
import 'widgets/timeline_slider.dart';

/// Browse images by day for necklace or desktop capture sources.
class ImagesScreen extends ConsumerStatefulWidget {
  const ImagesScreen({super.key, required this.source});

  /// `necklace` or `desktop` (matches server `source` query param).
  final String source;

  @override
  ConsumerState<ImagesScreen> createState() => _ImagesScreenState();
}

class _ImagesScreenState extends ConsumerState<ImagesScreen> {
  bool _loading = true;
  String? _error;
  Set<DateTime> _available = {};
  late DateTime _selected;

  bool _loadingDay = false;
  List<ImageEntry> _dayEntries = [];
  double _sliderValue = 0;
  double _minTime = 0;
  double _maxTime = 1439;

  Timer? _pollTimer;

  String get _title =>
      widget.source == 'desktop' ? 'Desktop Images' : 'Necklace Images';

  bool get _isToday {
    final now = DateTime.now();
    return _selected.year == now.year &&
        _selected.month == now.month &&
        _selected.day == now.day;
  }

  /// Index of the image shown for [_sliderValue] (last entry with time <= slider).
  int get _currentIndex {
    var idx = -1;
    for (var i = 0; i < _dayEntries.length; i++) {
      if (_dayEntries[i].minutesSinceMidnight <= _sliderValue) {
        idx = i;
      } else {
        break;
      }
    }
    return idx;
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _startPolling() {
    _stopPolling();
    if (!_isToday) return;
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _pollForNewImages();
    });
  }

  Future<void> _pollForNewImages() async {
    if (!mounted || !_isToday) return;
    final base = ref.read(imageBaseUrlProvider);
    final uid = ref.read(userIdProvider);
    if (base == null || uid == null || uid.isEmpty) return;

    try {
      final fresh =
          await fetchImagesForDay(base, uid, widget.source, _selected);
      if (!mounted) return;

      final existing = _dayEntries.map((e) => e.filename).toSet();
      final newOnes =
          fresh.where((e) => !existing.contains(e.filename)).toList();
      if (newOnes.isEmpty) return;

      final merged = [..._dayEntries, ...newOnes]..sort((a, b) {
          final c = a.minutesSinceMidnight.compareTo(b.minutesSinceMidnight);
          if (c != 0) return c;
          return a.filename.compareTo(b.filename);
        });

      final mins = merged.map((e) => e.minutesSinceMidnight).toList();
      final minT = mins.reduce((a, b) => a < b ? a : b);
      final maxT = mins.reduce((a, b) => a > b ? a : b);

      setState(() {
        _dayEntries = merged;
        _minTime = minT;
        _maxTime = maxT;
      });
    } catch (_) {
      // Next poll will retry
    }
  }

  void _stepPrev() {
    final i = _currentIndex;
    if (i <= 0) return;
    setState(() {
      _sliderValue = _dayEntries[i - 1].minutesSinceMidnight;
    });
  }

  void _stepNext() {
    final i = _currentIndex;
    if (i < 0 || i >= _dayEntries.length - 1) return;
    setState(() {
      _sliderValue = _dayEntries[i + 1].minutesSinceMidnight;
    });
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selected = DateTime(now.year, now.month, now.day);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDates());
  }

  Future<void> _loadDates() async {
    final base = ref.read(imageBaseUrlProvider);
    final uid = ref.read(userIdProvider);
    if (base == null || uid == null || uid.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Not logged in or missing image server URL.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dates = await fetchAvailableDates(base, uid, widget.source);
      if (!mounted) return;
      final initial = _initialSelected(dates);
      setState(() {
        _available = dates.toSet();
        _selected = initial;
        _loading = false;
      });
      await _loadImagesForSelectedDay();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  DateTime _initialSelected(List<DateTime> dates) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (dates.contains(today)) return today;
    if (dates.isNotEmpty) return dates.first;
    return today;
  }

  Future<void> _loadImagesForSelectedDay() async {
    final base = ref.read(imageBaseUrlProvider);
    final uid = ref.read(userIdProvider);
    if (base == null || uid == null || uid.isEmpty) return;

    _stopPolling();

    setState(() {
      _loadingDay = true;
      _dayEntries = [];
    });

    try {
      final entries =
          await fetchImagesForDay(base, uid, widget.source, _selected);
      if (!mounted) return;
      if (entries.isEmpty) {
        setState(() {
          _dayEntries = [];
          _minTime = 0;
          _maxTime = 1439;
          _sliderValue = 0;
          _loadingDay = false;
        });
        _startPolling();
        return;
      }
      final mins = entries.map((e) => e.minutesSinceMidnight).toList();
      final minT = mins.reduce((a, b) => a < b ? a : b);
      final maxT = mins.reduce((a, b) => a > b ? a : b);
      setState(() {
        _dayEntries = entries;
        _minTime = minT;
        _maxTime = maxT;
        _sliderValue = minT;
        _loadingDay = false;
      });
      _startPolling();
    } catch (e) {
      if (!mounted) return;
      _stopPolling();
      setState(() {
        _dayEntries = [];
        _loadingDay = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load images: $e')),
      );
    }
  }

  ImageEntry? _entryForSlider(double v) {
    ImageEntry? best;
    for (final e in _dayEntries) {
      if (e.minutesSinceMidnight <= v) {
        best = e;
      } else {
        break;
      }
    }
    return best;
  }

  Future<void> _pickDate() async {
    if (_available.isEmpty) return;

    final first = _available.reduce((a, b) => a.isBefore(b) ? a : b);
    final last = _available.reduce((a, b) => a.isAfter(b) ? a : b);

    final picked = await showDatePicker(
      context: context,
      initialDate: _selected.isBefore(first)
          ? first
          : (_selected.isAfter(last) ? last : _selected),
      firstDate: first,
      lastDate: last,
      selectableDayPredicate: (d) {
        final day = DateTime(d.year, d.month, d.day);
        return _available.contains(day);
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _selected = DateTime(picked.year, picked.month, picked.day);
      });
      await _loadImagesForSelectedDay();
    }
  }

  String _formatTimeLabel(ImageEntry? e) {
    if (e == null) return '—';
    final secs =
        (e.minutesSinceMidnight * 60).round().clamp(0, 24 * 3600 - 1);
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    final s = secs % 60;
    final dt = DateTime(
      _selected.year,
      _selected.month,
      _selected.day,
      h,
      m,
      s,
    );
    return DateFormat.jm().format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final base = ref.watch(imageBaseUrlProvider);
    final uid = ref.watch(userIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _loadDates,
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
                      if (_available.isEmpty)
                        const Text(
                          'No images for this source yet.',
                          style: TextStyle(color: Colors.grey),
                        )
                      else ...[
                        OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            DateFormat.yMMMd().format(_selected),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_loadingDay)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_dayEntries.isEmpty)
                          Text(
                            'No images on ${DateFormat.yMMMd().format(_selected)}.',
                            style: TextStyle(color: Colors.grey.shade600),
                          )
                        else ...[
                          TimelineSlider(
                            value: _sliderValue,
                            minTime: _minTime,
                            maxTime: _maxTime,
                            marks: _dayEntries
                                .map((e) => e.minutesSinceMidnight)
                                .toList(),
                            onChanged: (v) {
                              setState(() => _sliderValue = v);
                            },
                          ),
                          const SizedBox(height: 8),
                          Builder(
                            builder: (context) {
                              final idx = _currentIndex;
                              final canPrev = idx > 0;
                              final canNext =
                                  idx >= 0 && idx < _dayEntries.length - 1;
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    onPressed: canPrev ? _stepPrev : null,
                                    icon: const Icon(Icons.chevron_left),
                                    tooltip: 'Previous image',
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Time: ${_formatTimeLabel(_entryForSlider(_sliderValue))}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: canNext ? _stepNext : null,
                                    icon: const Icon(Icons.chevron_right),
                                    tooltip: 'Next image',
                                  ),
                                ],
                              );
                            },
                          ),
                          if (_entryForSlider(_sliderValue)?.currentApp !=
                              null) ...[
                            const SizedBox(height: 4),
                            Text(
                              _entryForSlider(_sliderValue)!.currentApp!,
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
                            _entryForSlider(_sliderValue)?.filename ?? '',
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
                                _entryForSlider(_sliderValue),
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
