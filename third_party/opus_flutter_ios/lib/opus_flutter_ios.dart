import 'dart:async';
import 'dart:ffi';

import 'package:opus_flutter_platform_interface/opus_flutter_platform_interface.dart';

/// The iOS implementation of [OpusFlutterPlatform].
class OpusFlutterIOS extends OpusFlutterPlatform {
  /// Opens the Opus symbols linked into the application process.
  Future<dynamic> load() async => DynamicLibrary.process();
}
