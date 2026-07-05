import 'dart:async';
import 'dart:ffi';

import 'package:opus_flutter_platform_interface/opus_flutter_platform_interface.dart';

/// An implementation of [OpusFlutterPlatform] for iOS.
class OpusFlutterIOS extends OpusFlutterPlatform {
  /// Opens the Opus symbols linked into the current iOS process.
  Future<dynamic> load() async {
    return DynamicLibrary.process();
  }
}
