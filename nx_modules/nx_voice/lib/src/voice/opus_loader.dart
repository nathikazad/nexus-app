import 'dart:io';
import 'package:nx_opus_macos/nx_opus_macos.dart';
import 'package:opus_flutter/opus_flutter.dart' as opus_flutter;

Future<dynamic> loadOpusLibrary() async =>
    Platform.isMacOS ? loadMacOsOpus() : await opus_flutter.load();
