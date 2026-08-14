part of 'note_companion.dart';

class _AudioPanel extends StatelessWidget {
  const _AudioPanel({required this.controller, required this.onClose});

  final NoteCompanionController controller;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.panel,
      elevation: 8,
      shadowColor: Colors.black45,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: (MediaQuery.sizeOf(context).width - 24).clamp(280, 380),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 7, 8, 0),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.headphones_rounded,
                    size: 16,
                    color: AppColors.blue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Note playback',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Minimize playback',
                    visualDensity: VisualDensity.compact,
                    onPressed: onClose,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            _AudioControls(controller: controller),
            if (controller.error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 8, 8),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        controller.error!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.red, fontSize: 12),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Dismiss error',
                      visualDensity: VisualDensity.compact,
                      onPressed: controller.clearError,
                      icon: const Icon(Icons.close, size: 16),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AudioControls extends StatelessWidget {
  const _AudioControls({required this.controller});

  final NoteCompanionController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.hasAudio) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: controller.generatingAudio
                ? null
                : () => unawaited(controller.generateAudio()),
            icon: controller.generatingAudio
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.headphones_rounded, size: 18),
            label: Text(
              controller.generatingAudio ? 'Creating audio…' : 'Create audio',
            ),
          ),
        ),
      );
    }
    final durationMs = controller.audioDuration.inMilliseconds;
    final positionMs = controller.audioPosition.inMilliseconds.clamp(
      0,
      durationMs,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 12, 4),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: controller.loadingNoteAudio
                ? 'Loading audio'
                : controller.noteAudioPlaying
                ? 'Pause note'
                : 'Play note',
            onPressed: controller.loadingNoteAudio
                ? null
                : () => unawaited(controller.toggleNoteAudio()),
            icon: controller.loadingNoteAudio
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    controller.noteAudioPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
          ),
          Expanded(
            child: Slider(
              value: durationMs <= 0 ? 0 : positionMs.toDouble(),
              max: durationMs <= 0 ? 1 : durationMs.toDouble(),
              onChanged: durationMs <= 0
                  ? null
                  : (value) => unawaited(
                      controller.seekNoteAudio(
                        Duration(milliseconds: value.round()),
                      ),
                    ),
            ),
          ),
          Text(
            _formatDuration(controller.audioPosition),
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
          NotePlaybackSpeedButton(
            speed: controller.noteAudioPlaybackSpeed,
            onSelected: (speed) async {
              await controller.setNoteAudioPlaybackSpeed(speed);
              if (controller.noteAudioPlaybackSpeed != speed) return;
              try {
                final preferences = await SharedPreferences.getInstance();
                await preferences.setDouble(
                  _notePlaybackSpeedPreferenceKey,
                  speed,
                );
              } catch (_) {
                // The selected speed still applies for this app session.
              }
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'Audio options',
            onSelected: (_) =>
                unawaited(controller.generateAudio(overwrite: true)),
            itemBuilder: (_) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'regenerate',
                child: Text('Regenerate audio'),
              ),
            ],
            icon: const Icon(Icons.more_horiz_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class NotePlaybackSpeedButton extends StatelessWidget {
  const NotePlaybackSpeedButton({
    required this.speed,
    required this.onSelected,
    super.key,
  });

  final double speed;
  final ValueChanged<double> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<double>(
      key: const ValueKey<String>('note-playback-speed-button'),
      tooltip: 'Playback speed',
      initialValue: speed,
      onSelected: onSelected,
      position: PopupMenuPosition.under,
      offset: const Offset(-112, -224),
      color: Colors.black,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black54,
      elevation: 10,
      menuPadding: const EdgeInsets.symmetric(vertical: 6),
      constraints: const BoxConstraints.tightFor(width: 124),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xff3f3f46)),
      ),
      itemBuilder: (_) => <PopupMenuEntry<double>>[
        for (final option in notePlaybackSpeeds)
          PopupMenuItem<double>(
            key: ValueKey<String>('note-playback-speed-$option'),
            value: option,
            height: 38,
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: option == speed
                      ? const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Text(
                  formatNotePlaybackSpeed(option),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: option == speed
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 10),
        child: Text(
          formatNotePlaybackSpeed(speed),
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

String formatNotePlaybackSpeed(double speed) =>
    '${speed.toStringAsFixed(speed == speed.roundToDouble() ? 0 : 2).replaceFirst(RegExp(r'0$'), '')}×';

ThemeData _neutralCompanionTheme(ThemeData base) {
  final scheme = base.colorScheme.copyWith(
    primary: AppColors.text,
    onPrimary: AppColors.panel,
    primaryContainer: AppColors.subtle,
    onPrimaryContainer: AppColors.text,
    secondary: AppColors.text,
    onSecondary: AppColors.panel,
    secondaryContainer: AppColors.subtle,
    onSecondaryContainer: AppColors.text,
    surfaceTint: Colors.transparent,
  );
  return base.copyWith(
    colorScheme: scheme,
    progressIndicatorTheme: ProgressIndicatorThemeData(color: AppColors.text),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: AppColors.text,
      inactiveTrackColor: AppColors.line,
      thumbColor: AppColors.text,
      overlayColor: AppColors.text.withValues(alpha: 0.08),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.text),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AppColors.text,
        backgroundColor: Colors.transparent,
        disabledForegroundColor: AppColors.faint,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.panel,
      surfaceTintColor: Colors.transparent,
      textStyle: TextStyle(color: AppColors.text),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppColors.line),
      ),
    ),
  );
}
