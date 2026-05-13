import 'dart:async';
import 'dart:math' as math;
import 'package:nx_db/auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nexus_voice_assistant/core/layout/layout.dart';
import 'package:nexus_voice_assistant/core/theme/app_theme.dart';
import 'package:nexus_voice_assistant/data/providers.dart';
import 'package:nexus_voice_assistant/features/hardware/device_selection_page.dart';
import 'package:nexus_voice_assistant/features/hardware/hardware_view_model.dart';
import 'package:nexus_voice_assistant/features/hardware/widgets/camera_section.dart';

class HardwarePage extends ConsumerStatefulWidget {
  const HardwarePage({super.key});

  @override
  ConsumerState<HardwarePage> createState() => _HardwarePageState();
}

class _HardwarePageState extends ConsumerState<HardwarePage> {
  Future<void> _editDeviceName() async {
    final vm = ref.read(hardwareViewModelProvider);
    final n = ref.read(hardwareViewModelProvider.notifier);
    if (!vm.isConnected || vm.isSettingDeviceName) {
      return;
    }

    final nameController = TextEditingController(text: vm.deviceName ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Device Name'),
          content: TextField(
            controller: nameController,
            autofocus: true,
            maxLength: 19,
            decoration: const InputDecoration(
              labelText: 'Device Name',
              hintText: 'Enter device name (max 19 characters)',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              Navigator.of(context).pop(value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(nameController.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    try {
      if (result != null && mounted) {
        await n.submitDeviceName(result);
      }
    } finally {
      nameController.dispose();
    }
  }

  Future<void> _navigateToDeviceSelection() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const DeviceSelectionPage()),
    );

    if (result == true && mounted) {
      await ref
          .read(hardwareViewModelProvider.notifier)
          .onReturnFromDeviceSelection();
    }
  }

  Future<void> _forgetPairedDevice() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Forget this Nexus?'),
        content: const Text(
          'This phone will stop connecting to the saved device. '
          'The peripheral may still expect its bonded phone until you reset it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Forget'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref
        .read(hardwareViewModelProvider.notifier)
        .forgetPairedAfterConfirm();
  }

  void _showDeviceActionsSheet() {
    final vm = ref.read(hardwareViewModelProvider);
    final n = ref.read(hardwareViewModelProvider.notifier);
    if (vm.menuOpen) {
      n.closeMenu();
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(RefLayout.rounded2xl),
                border: Border.all(color: AppColors.gray100),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: RefLayout.sheetHandleWidth,
                      height: RefLayout.sheetHandleHeight,
                      decoration: BoxDecoration(
                        color: AppColors.gray200,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _DeviceSheetButton(
                      label: 'Edit Name',
                      filled: false,
                      onPressed: () {
                        Navigator.pop(ctx);
                        unawaited(_editDeviceName());
                      },
                    ),
                    const SizedBox(height: 8),
                    _DeviceSheetButton(
                      label: 'Restart',
                      filled: false,
                      onPressed: () {
                        Navigator.pop(ctx);
                        unawaited(n.powerCycle());
                      },
                    ),
                    const SizedBox(height: 8),
                    _DeviceSheetButton(
                      label: 'Forget',
                      filled: false,
                      onPressed: () {
                        Navigator.pop(ctx);
                        unawaited(_forgetPairedDevice());
                      },
                    ),
                    const SizedBox(height: 8),
                    _DeviceSheetButton(
                      label: 'Disconnect',
                      filled: true,
                      onPressed: () {
                        Navigator.pop(ctx);
                        n.disconnectBle();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openPreferences() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Preferences'),
            surfaceTintColor: Colors.transparent,
          ),
          body: Center(
            child: Text(
              'Preferences coming soon',
              style: GoogleFonts.inter(fontSize: 15, color: AppColors.gray500),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
  }

  void _onDeviceCardTap() {
    final vm = ref.read(hardwareViewModelProvider);
    if (vm.isConnected) {
      _showDeviceActionsSheet();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(hardwareViewModelProvider);
    final n = ref.read(hardwareViewModelProvider.notifier);
    final hw = ref.watch(hardwareServiceProvider);

    ref.listen(hardwareViewModelProvider, (prev, next) {
      final msg = next.snackbarMessage;
      if (msg != null && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
        n.clearSnackbar();
      }
    });

    final hasPairedDevice =
        vm.pairedRemoteId != null && vm.pairedRemoteId!.isNotEmpty;
    final displayName = vm.deviceName ?? hw.deviceName ?? 'Not connected';

    String rtcSubtitle = '—';
    if (vm.isConnected && vm.rtcTimeDisplay != null) {
      final parts = vm.rtcTimeDisplay!.split('\n');
      if (parts.length >= 2) {
        final tz = vm.rtcTimezone != null ? ' (UTC${vm.rtcTimezone})' : '';
        rtcSubtitle = '${parts[0].trim()} · ${parts[1].trim()}$tz';
      } else {
        rtcSubtitle = vm.rtcTimeDisplay!.replaceAll('\n', ' ');
      }
    }

    final paddingTop = MediaQuery.paddingOf(context).top;

    return PopScope(
      canPop: !vm.menuOpen,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && vm.menuOpen) {
          n.closeMenu();
        }
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Scaffold(
            backgroundColor: AppColors.gray50,
            appBar: AppBar(
              title: Text('Nexus', style: refAppBarTitleLarge()),
              surfaceTintColor: Colors.transparent,
              actions: [
                Tooltip(
                  message: 'Menu',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => n.toggleMenu(),
                      child: const SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(Icons.menu,
                            color: AppColors.gray600, size: 24),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            body: LayoutBuilder(
              builder: (context, constraints) {
                if (vm.isConnected) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      RefLayout.p4,
                      RefLayout.p4,
                      RefLayout.p4,
                      96,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _DeviceCard(
                          displayName: displayName,
                          pairedOffline: false,
                          isRenaming: vm.isSettingDeviceName,
                          onCardTap: _onDeviceCardTap,
                          onVibrate: vm.isConnected && !vm.isPulsingHaptic
                              ? () {
                                  unawaited(n.pulseHaptic());
                                }
                              : null,
                          pulseBusy: vm.isPulsingHaptic,
                        ),
                        const SizedBox(height: RefLayout.gap4),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _MetricTile(
                                  label: 'Battery',
                                  trailingIcon:
                                      (vm.isConnected && vm.isCharging == true)
                                          ? Icon(
                                              Icons.bolt_rounded,
                                              size: 18,
                                              color: AppColors.green500,
                                            )
                                          : Icon(
                                              Icons.bolt_rounded,
                                              size: 18,
                                              color: AppColors.gray400,
                                            ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        vm.isConnected &&
                                                vm.batteryPercentage != null
                                            ? '${vm.batteryPercentage}'
                                            : '—',
                                        style: GoogleFonts.inter(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: -0.5,
                                          color: vm.isConnected &&
                                                  vm.batteryPercentage != null
                                              ? AppColors.gray900
                                              : AppColors.gray400,
                                        ),
                                      ),
                                      Text(
                                        '%',
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          color: AppColors.gray500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: RefLayout.gap4),
                              Expanded(
                                child: _MetricTile(
                                  label: 'Voltage',
                                  trailingIcon: Icon(
                                    Icons.show_chart_rounded,
                                    size: 18,
                                    color: AppColors.gray400,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        vm.isConnected && vm.voltage != null
                                            ? vm.voltage!.toStringAsFixed(2)
                                            : '—',
                                        style: GoogleFonts.inter(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: -0.5,
                                          color: vm.isConnected &&
                                                  vm.voltage != null
                                              ? AppColors.gray900
                                              : AppColors.gray400,
                                        ),
                                      ),
                                      Text(
                                        ' v',
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          color: AppColors.gray500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: RefLayout.gap4),
                        Container(
                          padding: const EdgeInsets.all(RefLayout.p4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(RefLayout.rounded2xl),
                            border: Border.all(color: AppColors.gray100),
                            boxShadow: refCardShadow,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Device Clock',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: AppColors.gray500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      rtcSubtitle,
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.gray900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Material(
                                color: AppColors.orange50,
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: vm.isConnected && !vm.isSettingRTC
                                      ? () {
                                          unawaited(n.setRtcTimeNow());
                                        }
                                      : null,
                                  child: SizedBox(
                                    width: 40,
                                    height: 40,
                                    child: vm.isSettingRTC
                                        ? const Padding(
                                            padding: EdgeInsets.all(10),
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Icon(
                                            Icons.refresh_rounded,
                                            color: vm.isConnected
                                                ? AppColors.orange600
                                                : AppColors.gray400,
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: RefLayout.gap4),
                        CameraSection(
                          isConnected: vm.isConnected,
                          captureInProgress: vm.isTriggeringCamera,
                          onCapture: () {
                            unawaited(n.triggerCamera());
                          },
                        ),
                      ],
                    ),
                  );
                }
                if (hasPairedDevice) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      RefLayout.p4,
                      RefLayout.p4,
                      RefLayout.p4,
                      96,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _DeviceCard(
                          displayName: n.rememberedDisplayName(),
                          pairedOffline: true,
                          isRenaming: false,
                          onVibrate: null,
                          pulseBusy: false,
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: n.reconnectPaired,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.orange600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                            shadowColor:
                                AppColors.orange600.withValues(alpha: 0.35),
                          ),
                          icon: const Icon(Icons.bluetooth_rounded, size: 22),
                          label: Text(
                            'Connect',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => unawaited(_forgetPairedDevice()),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.gray600,
                            side: const BorderSide(color: AppColors.gray200),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Forget Device',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final minH = math.max(0.0, constraints.maxHeight - 120);
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                      RefLayout.p4, 0, RefLayout.p4, 96),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: minH),
                    child: Center(
                      child: _NoHardwareEmptyState(
                        onFindDevice: () =>
                            unawaited(_navigateToDeviceSelection()),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (vm.menuOpen) ...[
            Positioned.fill(
              child: GestureDetector(
                onTap: () => n.closeMenu(),
                behavior: HitTestBehavior.opaque,
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.32),
                ),
              ),
            ),
            Positioned(
              top: paddingTop + kToolbarHeight + 4,
              right: 20,
              width: 220,
              child: Material(
                elevation: 8,
                shadowColor: Colors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.gray100),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InkWell(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        onTap: () {
                          n.closeMenu();
                          _openPreferences();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.settings_outlined,
                                size: 18,
                                color: AppColors.gray500,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Preferences',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.gray900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: AppColors.gray100,
                        ),
                      ),
                      InkWell(
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(12),
                        ),
                        onTap: () async {
                          n.closeMenu();
                          await _logout();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.logout_rounded,
                                size: 18,
                                color: AppColors.gray500,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Log out',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.gray900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.displayName,
    required this.pairedOffline,
    required this.isRenaming,
    this.onCardTap,
    required this.onVibrate,
    required this.pulseBusy,
  });

  final String displayName;
  final bool pairedOffline;
  final bool isRenaming;
  final VoidCallback? onCardTap;
  final VoidCallback? onVibrate;
  final bool pulseBusy;

  @override
  Widget build(BuildContext context) {
    final nameBlock = Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Expanded(
              child: Text(
                displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.gray900,
                ),
              ),
            ),
            if (!pairedOffline && isRenaming) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
      ),
    );

    Widget leadingNameAndTap() {
      if (pairedOffline) {
        return Expanded(child: nameBlock);
      }
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onCardTap,
          child: nameBlock,
        ),
      );
    }

    Widget trailing() {
      if (pairedOffline) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 16, color: AppColors.gray400),
            const SizedBox(width: 4),
            Text(
              'Offline',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.gray400,
              ),
            ),
          ],
        );
      }
      return Material(
        color: AppColors.gray50,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onVibrate,
          child: SizedBox(
            width: 32,
            height: 32,
            child: pulseBusy
                ? const Padding(
                    padding: EdgeInsets.all(6),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.vibration_rounded,
                    size: 18,
                    color: onVibrate != null
                        ? AppColors.gray600
                        : AppColors.gray400,
                  ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(RefLayout.p4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(RefLayout.rounded2xl),
        border: Border.all(color: AppColors.gray100),
        boxShadow: refCardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _DownTriangleBadge(offline: pairedOffline),
          const SizedBox(width: 12),
          leadingNameAndTap(),
          trailing(),
        ],
      ),
    );
  }
}

class _NoHardwareEmptyState extends StatelessWidget {
  const _NoHardwareEmptyState({required this.onFindDevice});

  final VoidCallback onFindDevice;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: AppColors.gray100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.bluetooth_disabled_rounded,
              size: 38,
              color: AppColors.gray400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Device Paired',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: AppColors.gray900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect your Nexus wearable to start talking with your AI.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 16,
              height: 1.4,
              color: AppColors.gray500,
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: onFindDevice,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.orange600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
              shadowColor: AppColors.orange600.withValues(alpha: 0.35),
            ),
            icon: const Icon(Icons.bluetooth_searching_rounded, size: 22),
            label: Text(
              'Find Device',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.child,
    this.trailingIcon,
  });

  final String label;
  final Widget child;
  final Widget? trailingIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(RefLayout.p4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(RefLayout.rounded2xl),
        border: Border.all(color: AppColors.gray100),
        boxShadow: refCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.gray500,
                ),
              ),
              if (trailingIcon != null) trailingIcon!,
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _DeviceSheetButton extends StatelessWidget {
  const _DeviceSheetButton({
    required this.label,
    required this.filled,
    required this.onPressed,
  });

  final String label;
  final bool filled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.gray900,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.gray900,
          side: const BorderSide(color: AppColors.gray200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
    );
  }
}

class _DownTriangleBadge extends StatelessWidget {
  const _DownTriangleBadge({this.offline = false});

  final bool offline;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: offline ? AppColors.gray100 : AppColors.orange50,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: CustomPaint(
        size: const Size(28, 28),
        painter: _DownTrianglePainter(offline: offline),
      ),
    );
  }
}

class _DownTrianglePainter extends CustomPainter {
  const _DownTrianglePainter({this.offline = false});

  final bool offline;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = offline ? const Color(0xFF9CA3AF) : const Color(0xFF171717);
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 5 / 24, h * 6.5 / 24)
      ..lineTo(w * 19 / 24, h * 6.5 / 24)
      ..lineTo(w * 12 / 24, h * 18.2 / 24)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DownTrianglePainter oldDelegate) {
    return oldDelegate.offline != offline;
  }
}
