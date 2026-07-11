import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

import 'package:nx_time/core/theme/action_color_palette.dart';
import 'package:nx_time/core/theme/app_theme.dart';
import 'package:nx_time/data/providers.dart';
import 'package:nx_time/domain/action/action_subtype_option.dart';

class ActionColorsPage extends ConsumerStatefulWidget {
  const ActionColorsPage({super.key});

  @override
  ConsumerState<ActionColorsPage> createState() => _ActionColorsPageState();
}

class _ActionColorsPageState extends ConsumerState<ActionColorsPage> {
  bool _seedAttempted = false;

  static const List<Color> _swatches = [
    AppColors.sleepBlue,
    Color(0xFF185FA5),
    AppColors.dotOk,
    AppColors.calOrange,
    Color(0xFFD4537E),
    AppColors.calOlive,
    Color(0xFF888780),
    Color(0xFFBA7517),
    AppColors.accent,
    Color(0xFF534AB7),
    Color(0xFF0EA5E9),
    Color(0xFF7C3AED),
    Color(0xFF10B981),
    Color(0xFFE11D48),
    Color(0xFFF59E0B),
    Color(0xFF111827),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // ignore: discarded_futures
      _trySeed();
    });
  }

  /// One batched write so new installs persist defaults from [barColorForModelTypeId].
  Future<void> _trySeed() async {
    if (!mounted || _seedAttempted) return;
    try {
      final subtypes = await ref.read(actionSubtypeOptionsProvider.future);
      final person = await ref.read(mainPersonProvider.future);
      if (!mounted) return;
      if (person == null) return;
      final map = readModelTypeColorHexByName(person.preference);
      var allPresent = true;
      for (final t in subtypes) {
        if (!map.containsKey(t.name)) {
          allPresent = false;
          break;
        }
      }
      if (allPresent) return;
      _seedAttempted = true;
      final repo = ref.read(personRepositoryProvider);
      await seedMissingModelTypeColors(
        repo: repo,
        person: person,
        subtypes: subtypes,
      );
      if (mounted) {
        ref.invalidate(mainPersonProvider);
      }
    } catch (e) {
      debugPrint('[ActionColorsPage] seed: $e');
    }
  }

  Future<void> _pickColor({
    required Person person,
    required String modelTypeName,
    required Color current,
  }) async {
    final selected = await showModalBottomSheet<Color>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose color for $modelTypeName',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate900,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _swatches.map((c) {
                    final selectedSwatch = c.toARGB32() == current.toARGB32();
                    return GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(c),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c,
                          border: Border.all(
                            color: selectedSwatch
                                ? AppColors.slate900
                                : AppColors.slate200,
                            width: selectedSwatch ? 2.2 : 1.2,
                          ),
                        ),
                        child: selectedSwatch
                            ? const Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null || !mounted) return;
    final repo = ref.read(personRepositoryProvider);
    final hex = hexFromColor(selected);
    try {
      await setModelTypeColor(
        repo: repo,
        person: person,
        modelTypeName: modelTypeName,
        hex: hex,
      );
      if (mounted) {
        ref.invalidate(mainPersonProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtypes = ref.watch(actionSubtypeOptionsProvider);
    final colorsAsync = ref.watch(modelTypeColorsProvider);
    final personAsync = ref.watch(mainPersonProvider);

    final colorsLast = colorsAsync.asData?.value;
    final personLast = personAsync.asData?.value;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(SolarLinearIcons.arrowLeft, size: 22),
                    color: AppColors.slate600,
                  ),
                  const Expanded(
                    child: Text(
                      'Colors',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: AppColors.slate900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.slate100),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Text(
                'Tap a color to choose a new swatch',
                style: TextStyle(fontSize: 13, color: AppColors.slate500),
              ),
            ),
            Expanded(
              child: _buildBody(
                subtypes: subtypes,
                colorsLast: colorsLast,
                personAsync: personAsync,
                personLast: personLast,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody({
    required AsyncValue<List<ActionSubtypeOption>> subtypes,
    required ModelTypeColors? colorsLast,
    required AsyncValue<Person?> personAsync,
    required Person? personLast,
  }) {
    final types = subtypes.asData?.value;
    if (types == null) {
      if (subtypes.hasError) return _error(subtypes.error!);
      return const Center(child: CircularProgressIndicator());
    }
    if (colorsLast == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (personLast == null) {
      if (personAsync.hasError) return _error(personAsync.error!);
      if (personAsync.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return const Center(
        child: Text(
          'No linked Person profile found for this user.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.slate500),
        ),
      );
    }
    return _buildList(types, colorsLast, person: personLast);
  }

  Widget _error(Object e) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Error: $e', textAlign: TextAlign.center),
      ),
    );
  }

  Widget _buildList(
    List<ActionSubtypeOption> types,
    ModelTypeColors c, {
    required Person person,
  }) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: types.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: AppColors.slate100),
      itemBuilder: (context, index) {
        final mt = types[index];
        final name = mt.name;
        final id = mt.id;
        final color = c.forId(id, name: name);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.slate900,
                  ),
                ),
              ),
              InkWell(
                onTap: () => _pickColor(
                  person: person,
                  modelTypeName: name,
                  current: color,
                ),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.slate200),
                    borderRadius: BorderRadius.circular(999),
                    color: Colors.white,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        hexFromColor(color),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.slate600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        SolarLinearIcons.altArrowDown,
                        size: 14,
                        color: AppColors.slate400,
                      ),
                    ],
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
