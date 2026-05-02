part of '../sprint_cart.dart';

class _SprintNavStrip extends ConsumerStatefulWidget {
  _SprintNavStrip({
    required this.sp,
    required this.sprintIdx,
    required this.sprints,
    required this.onPrev,
    required this.onNext,
  });

  final Sprint sp;
  final int sprintIdx;
  final List<Sprint> sprints;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  ConsumerState<_SprintNavStrip> createState() => _SprintNavStripState();
}

class _SprintNavStripState extends ConsumerState<_SprintNavStrip> {
  late final TextEditingController _nameController;
  late final FocusNode _nameFocus;
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.sp.name);
    _nameFocus = FocusNode();
    _nameFocus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_nameFocus.hasFocus || !_editing) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_nameFocus.hasFocus || !_editing) return;
      _saveName();
    });
  }

  @override
  void didUpdateWidget(covariant _SprintNavStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing &&
        (oldWidget.sp.id != widget.sp.id ||
            oldWidget.sp.name != widget.sp.name)) {
      _nameController.text = widget.sp.name;
    }
  }

  @override
  void dispose() {
    _nameFocus.removeListener(_onFocusChange);
    _nameFocus.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _beginEdit() {
    if (_editing) return;
    setState(() {
      _editing = true;
      _nameController.text = widget.sp.name;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _nameFocus.requestFocus();
      _nameController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _nameController.text.length,
      );
    });
  }

  Future<void> _saveName() async {
    if (_saving) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _editing = false;
        _nameController.text = widget.sp.name;
      });
      return;
    }
    if (name == widget.sp.name) {
      setState(() => _editing = false);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(sprintRepositoryProvider)
          .update(widget.sp.copyWith(name: name));
      ref.invalidate(sprintsListAsyncProvider);
      if (mounted) {
        setState(() {
          _editing = false;
          _nameController.text = name;
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPrev = widget.sprintIdx > 0;
    final canNext = widget.sprintIdx < widget.sprints.length - 1;
    return Container(
      padding: EdgeInsets.fromLTRB(10, 12, 10, 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.colors.border)),
      ),
      child: Row(
        children: [
          _Chev(label: '‹', enabled: canPrev, onTap: widget.onPrev),
          Expanded(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: _editing
                          ? SizedBox(
                              height: 28,
                              child: TextField(
                                controller: _nameController,
                                focusNode: _nameFocus,
                                enabled: !_saving,
                                onSubmitted: (_) => _saveName(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: context.colors.text,
                                ),
                                cursorColor: context.colors.accent,
                                decoration: InputDecoration(
                                  isDense: true,
                                  filled: true,
                                  fillColor: context.colors.panel2,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(5),
                                    borderSide: BorderSide(
                                      color: context.colors.border,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(5),
                                    borderSide: BorderSide(
                                      color: context.colors.border,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(5),
                                    ),
                                    borderSide: BorderSide(
                                      color: context.colors.accent,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : InkWell(
                              onTap: _beginEdit,
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                child: Text(
                                  widget.sp.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: context.colors.text,
                                  ),
                                ),
                              ),
                            ),
                    ),
                    SizedBox(width: 8),
                    _Badge(label: widget.sp.badge),
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  widget.sp.dates,
                  style: TextStyle(fontSize: 11, color: context.colors.muted),
                ),
              ],
            ),
          ),
          _Chev(label: '›', enabled: canNext, onTap: widget.onNext),
        ],
      ),
    );
  }
}

class _Chev extends StatelessWidget {
  _Chev({required this.label, required this.enabled, required this.onTap});

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: enabled ? context.colors.muted : context.colors.dim,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SprintDots extends StatelessWidget {
  _SprintDots({
    required this.sprints,
    required this.currentIdx,
    required this.onPick,
    required this.onAdd,
  });

  final List<Sprint> sprints;
  final int currentIdx;
  final ValueChanged<int> onPick;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(10, 4, 10, 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.colors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < sprints.length; i++) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                onTap: () => onPick(i),
                customBorder: CircleBorder(),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == currentIdx
                        ? context.colors.accent
                        : context.colors.border2,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
          SizedBox(width: 4),
          _SprintAddPlus(onTap: onAdd),
        ],
      ),
    );
  }
}

class _SprintAddPlus extends StatefulWidget {
  _SprintAddPlus({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_SprintAddPlus> createState() => _SprintAddPlusState();
}

class _SprintAddPlusState extends State<_SprintAddPlus> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '+',
            style: TextStyle(
              fontSize: 10,
              color: _hover ? context.colors.text : context.colors.dim,
            ),
          ),
        ),
      ),
    );
  }
}

class _CapBlock extends ConsumerStatefulWidget {
  _CapBlock({required this.stats, required this.sprint});

  final SprintHeaderStats stats;
  final Sprint sprint;

  @override
  ConsumerState<_CapBlock> createState() => _CapBlockState();
}

class _CapBlockState extends ConsumerState<_CapBlock> {
  late final TextEditingController _capController;
  late final FocusNode _capFocus;
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _capController = TextEditingController(
      text: _formatHours(widget.sprint.capH),
    );
    _capFocus = FocusNode();
    _capFocus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_capFocus.hasFocus || !_editing) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_capFocus.hasFocus || !_editing) return;
      _saveCapacity();
    });
  }

  @override
  void didUpdateWidget(covariant _CapBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing &&
        (oldWidget.sprint.id != widget.sprint.id ||
            oldWidget.sprint.capH != widget.sprint.capH)) {
      _capController.text = _formatHours(widget.sprint.capH);
    }
  }

  @override
  void dispose() {
    _capFocus.removeListener(_onFocusChange);
    _capFocus.dispose();
    _capController.dispose();
    super.dispose();
  }

  String _formatHours(double v) {
    return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
  }

  void _beginEdit() {
    if (_editing) return;
    setState(() {
      _editing = true;
      _capController.text = _formatHours(widget.sprint.capH);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _capFocus.requestFocus();
      _capController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _capController.text.length,
      );
    });
  }

  Future<void> _saveCapacity() async {
    if (_saving) return;
    final parsed = double.tryParse(_capController.text.trim());
    if (parsed == null || parsed < 0) {
      setState(() {
        _editing = false;
        _capController.text = _formatHours(widget.sprint.capH);
      });
      return;
    }

    if (parsed == widget.sprint.capH) {
      setState(() => _editing = false);
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(sprintRepositoryProvider)
          .update(widget.sprint.copyWith(capH: parsed));
      ref.invalidate(sprintsListAsyncProvider);
      if (mounted) {
        setState(() {
          _editing = false;
          _capController.text = _formatHours(parsed);
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalLabel =
        widget.stats.totalH == widget.stats.totalH.roundToDouble()
        ? '${widget.stats.totalH.toInt()}'
        : widget.stats.totalH.toStringAsFixed(1);
    final cap = widget.sprint.capH;
    double fillRatio = 0.0;
    if (cap > 0 && widget.stats.totalH.isFinite) {
      final raw = widget.stats.totalH / cap;
      if (raw.isFinite) {
        fillRatio = raw.clamp(0.0, 1.0).toDouble();
      }
    }
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.colors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: _beginEdit,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                  child: Text(
                    'Capacity',
                    style: TextStyle(fontSize: 12, color: context.colors.muted),
                  ),
                ),
              ),
              _editing
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${totalLabel}h / ',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.colors.text,
                          ),
                        ),
                        SizedBox(
                          width: 48,
                          height: 24,
                          child: TextField(
                            controller: _capController,
                            focusNode: _capFocus,
                            enabled: !_saving,
                            keyboardType: TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onSubmitted: (_) => _saveCapacity(),
                            style: TextStyle(
                              fontSize: 12,
                              color: context.colors.text,
                            ),
                            cursorColor: context.colors.accent,
                            decoration: InputDecoration(
                              isDense: true,
                              filled: true,
                              fillColor: context.colors.panel2,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 5,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(5),
                                borderSide: BorderSide(
                                  color: context.colors.border,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(5),
                                borderSide: BorderSide(
                                  color: context.colors.border,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(5),
                                ),
                                borderSide: BorderSide(
                                  color: context.colors.accent,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Text(
                          'h',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colors.muted,
                          ),
                        ),
                      ],
                    )
                  : InkWell(
                      onTap: _beginEdit,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 1,
                        ),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${totalLabel}h',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: context.colors.text,
                                ),
                              ),
                              TextSpan(
                                text: ' / ${_formatHours(cap)}h',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.colors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ],
          ),
          SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxW = constraints.maxWidth.isFinite
                      ? constraints.maxWidth
                      : 0.0;
                  final fillW = (maxW * fillRatio).clamp(0.0, maxW).toDouble();
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: ColoredBox(color: context.colors.panel3),
                      ),
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: fillW,
                        child: ColoredBox(color: context.colors.accent),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Project? _projectById(List<Project> projects, int id) {
  for (final p in projects) {
    if (p.id == id) return p;
  }
  return null;
}
