import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_voice_assistant/services/hardware_service/hardware_service.dart';
import 'package:nexus_voice_assistant/services/logging_service.dart';
import 'package:nexus_voice_assistant/services/file_transfer_service/file_transfer_service.dart';
import 'package:nexus_voice_assistant/bg_ble_client.dart';
import 'device_selection_screen.dart';

class HardwareScreen extends ConsumerStatefulWidget {
  const HardwareScreen({super.key});

  @override
  ConsumerState<HardwareScreen> createState() => _HardwareScreenState();
}

class _HardwareScreenState extends ConsumerState<HardwareScreen> {
  late final HardwareService _hardwareService;
  
  int? _batteryPercentage;
  double? _voltage;
  bool? _isCharging;
  String? _rtcTimeDisplay;
  String? _rtcTimezone; // Will store formatted timezone (e.g., "-8")
  String? _deviceName;
  bool _isConnected = false;
  bool _isSettingRTC = false;
  bool _isPulsingHaptic = false;
  bool _isSettingDeviceName = false;
  
  StreamSubscription<BleConnectionState>? _connectionSubscription;
  Timer? _dataRefreshTimer;

  @override
  void initState() {
    super.initState();
    _hardwareService = ref.read(hardwareServiceProvider);
    _setupListeners();
    _startRefreshTimers();
  }

  Future<void> _startRefreshTimers() async {
    // Read immediately
    await _readBatteryData();
    await _readRTCData();
    await _readDeviceName();
    
    // Refresh battery and RTC data periodically
    _dataRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await _readBatteryData();
      await _readRTCData();
    });
  }

  Future<void> _readBatteryData() async {
    if (!_isConnected) {
      return;
    }
    try {
      final batteryData = await _hardwareService.readBattery();
      if (mounted && batteryData != null) {
        setState(() {
          _batteryPercentage = batteryData.percentage;
          _voltage = batteryData.voltage;
          _isCharging = batteryData.isCharging;
        });
      }
    } catch (e) {
      LoggingService.instance.log('Error reading battery data: $e');
    }
  }

  void _stopRefreshTimers() {
    _dataRefreshTimer?.cancel();
    _dataRefreshTimer = null;
  }

  void _setupListeners() {
    // Listen to connection state
    _connectionSubscription = _hardwareService.statusStream.listen((status) {
      if (mounted) {
        
        final isConnected = status == BleConnectionState.connected;
        setState(() {
          _isConnected = isConnected;
          if (!isConnected) {
            _batteryPercentage = null;
            _voltage = null;
            _isCharging = null;
            _rtcTimeDisplay = null;
            _rtcTimezone = null;
            _deviceName = null;


            _stopRefreshTimers();
          } else {

            // Restart timers when connected
            _startRefreshTimers();
          }
        });
      }
    });
    
    // Battery updates are handled via polling in _startRefreshTimers
    // No battery stream available in new HardwareService
    
    // Set initial connection state
    setState(() {
      _isConnected = _hardwareService.isConnected;
    });
  }


  Future<void> _readRTCData() async {
    if (!_isConnected) {
      return;
    }

    try {
      final rtcTime = await _hardwareService.readRTC();
      if (mounted && rtcTime != null) {
        setState(() {
          _rtcTimeDisplay = rtcTime.toDisplayString();
          // Format timezone as just the hours (e.g., "-8" instead of "UTC-8:00")
          final tzHours = rtcTime.timezoneHours;
          _rtcTimezone = tzHours >= 0 ? '+$tzHours' : '$tzHours';
        });
      }
    } catch (e) {
      LoggingService.instance.log('Error reading RTC data: $e');
    }
  }

  Future<void> _readDeviceName() async {
    LoggingService.instance.log('Reading device name');
    if (!_isConnected) {
      return;
    }

    try {
      LoggingService.instance.log('Reading device name from device');
      final name = await _hardwareService.readDeviceName();
      LoggingService.instance.log('Device name read: $name');
      if (mounted) {
        setState(() {
          // Use read name if available, otherwise fall back to advertising name
          _deviceName = name ?? _hardwareService.deviceName;
        });
      }
    } catch (e) {
      LoggingService.instance.log('Error reading device name: $e');
      // Fall back to advertising name on error
      if (mounted) {
        setState(() {
          _deviceName = _hardwareService.deviceName;
        });
      }
    }
  }

  Future<void> _editDeviceName() async {
    if (!_isConnected || _isSettingDeviceName) {
      return;
    }

    // Show dialog with current name pre-filled
    final TextEditingController nameController = TextEditingController(text: _deviceName ?? '');
    
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

    if (result != null && mounted) {
      setState(() {
        _isSettingDeviceName = true;
      });

      try {
        final success = await _hardwareService.writeDeviceName(result);
        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Device name updated successfully')),
            );
            // Refresh device name
            await _readDeviceName();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to update device name')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating device name: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSettingDeviceName = false;
          });
        }
      }
    }
  }

  Future<void> _setRTCTime() async {
    if (!_isConnected || _isSettingRTC) {
      return;
    }

    setState(() {
      _isSettingRTC = true;
    });

    try {
      final success = await _hardwareService.setRTCTimeNow();
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('RTC time set successfully')),
          );
          // Refresh RTC display
          await _readRTCData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to set RTC time')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error setting RTC time: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSettingRTC = false;
        });
      }
    }
  }

  Future<void> _pulseHaptic() async {
    if (!_isConnected || _isPulsingHaptic) {
      return;
    }

    setState(() {
      _isPulsingHaptic = true;
    });

    try {
      final success = await _hardwareService.triggerHapticPulse();
      if (mounted) {
        if (success) {
          // ScaffoldMessenger.of(context).showSnackBar(
          //   const SnackBar(content: Text('Haptic pulse triggered')),
          // );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to trigger haptic pulse')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error triggering haptic pulse: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPulsingHaptic = false;
        });
      }
    }
  }

  @override
  @override
  void dispose() {
    _stopRefreshTimers();
    _connectionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _selectDevice() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const DeviceSelectionScreen()),
    );
    
    if (result == true && mounted) {
      // Device connected successfully, refresh UI
      setState(() {
        _isConnected = _hardwareService.isConnected;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use stored device name if available, otherwise fall back to advertising name
    final displayName = _deviceName ?? _hardwareService.deviceName ?? 'Unknown';
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hardware Status'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.bluetooth_searching),
            onPressed: _selectDevice,
            tooltip: 'Select Device',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Device name
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _isConnected && !_isSettingDeviceName ? _editDeviceName : null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
            Text(
                        displayName,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
                      ),
                      if (_isSettingDeviceName) ...[
                        const SizedBox(width: 8),
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_isConnected) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: _isPulsingHaptic
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.vibration, size: 20),
                    onPressed: _isPulsingHaptic ? null : _pulseHaptic,
                    tooltip: 'Vibrate',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 32),
            // Battery and Voltage as separate columns on same row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Battery column
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Battery',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            _isConnected && _batteryPercentage != null
                                ? '$_batteryPercentage%'
                                : '--',
                            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _isConnected && _batteryPercentage != null
                                  ? _getBatteryColor(_batteryPercentage!)
                                  : Colors.grey,
                            ),
                          ),
                          if (_isConnected && _isCharging == true) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.battery_charging_full,
                              color: Colors.green,
                              size: 24,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Voltage column
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Voltage',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isConnected && _voltage != null
                            ? '${_voltage!.toStringAsFixed(2)} V'
                            : '-- V',
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _isConnected && _voltage != null
                              ? Colors.orange
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // RTC Time (date and time+zone+button as columns on same row)
            Text(
              'RTC Time',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                // Calculate font size based on screen width
                final screenWidth = constraints.maxWidth;
                final double fontSize = screenWidth /19;
                
                // Parse date and time from display string (format: "MM/DD/YY\nhh:mm am/pm")
                String? datePart;
                String? timePart;
                if (_isConnected && _rtcTimeDisplay != null) {
                  final parts = _rtcTimeDisplay!.split('\n');
                  if (parts.length >= 2) {
                    datePart = parts[0]; // "MM/DD/YY"
                    timePart = parts[1]; // "hh:mm am/pm"
                  } else {
                    datePart = _rtcTimeDisplay;
                    timePart = null;
                  }
                }
                
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Date column
                    Expanded(
                      child: Text(
                        datePart ?? '--',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold,
                          color: _isConnected && datePart != null
                              ? Colors.blue
                              : Colors.grey,
                        ),
                      ),
                    ),
                    // Time + Zone + Button column
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              timePart != null && _rtcTimezone != null
                                  ? '$timePart $_rtcTimezone'
                                  : timePart ?? '--',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: fontSize,
                                fontWeight: FontWeight.bold,
                                color: _isConnected && timePart != null
                                    ? Colors.blue
                                    : Colors.grey,
                              ),
                            ),
                          ),
                          if (_isConnected && _rtcTimeDisplay != null) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: _isSettingRTC
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.sync, size: 20),
                              onPressed: _isSettingRTC ? null : _setRTCTime,
                              tooltip: 'Sync with System Time',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            
            
            // File transfer buttons
            if (_isConnected) ...[
              const SizedBox(height: 48),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'File Operations',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isConnected ? _listFiles : null,
                    icon: const Icon(Icons.folder),
                    label: const Text('List Files'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isConnected ? _requestFile : null,
                    icon: const Icon(Icons.download),
                    label: const Text('Request File'),
                  ),
                ],
              ),
            ],
            
            if (!_isConnected) ...[
              const SizedBox(height: 32),
              Text(
                'Not connected to device',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey,
                ),
              ),
            ],
          ],
            ),
          ),
        ),
      ),
    );
  }
  
  Future<void> _listFiles() async {
    if (!_isConnected) return;
    
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      final files = await FileTransferService.instance.listFiles();
      
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Files'),
            content: SizedBox(
              width: double.maxFinite,
              child: files.isEmpty
                  ? const Text('No files found')
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: files.length,
                      itemBuilder: (context, index) {
                        final file = files[index];
                        return ListTile(
                          leading: Icon(
                            file.isDirectory ? Icons.folder : Icons.insert_drive_file,
                          ),
                          title: Text(file.name),
                          subtitle: Text(
                            file.isDirectory 
                                ? 'Directory' 
                                : '${file.size} bytes',
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog if still open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error listing files: $e')),
        );
      }
    }
  }
  
  Future<void> _requestFile() async {
    if (!_isConnected) return;
    
    final TextEditingController fileNameController = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Request File'),
          content: TextField(
            controller: fileNameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'File Name',
              hintText: 'Enter file name to request',
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
              onPressed: () => Navigator.of(context).pop(fileNameController.text),
              child: const Text('Request'),
            ),
          ],
        );
      },
    );
    
    if (result != null && result.isNotEmpty && mounted) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
        
        final fileEntry = await FileTransferService.instance.requestFile(result);
        
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('File Received'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('File: ${fileEntry.name}'),
                  Text('Size: ${fileEntry.size} bytes'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog if still open
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error requesting file: $e')),
          );
        }
      }
    }
  }
  
  Color _getBatteryColor(int percentage) {
    if (percentage >= 50) {
      return Colors.green;
    } else if (percentage >= 20) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}

