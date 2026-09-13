import 'dart:ffi';
import 'dart:io';

/// The framework is embedded and signed by Xcode, not loaded from system paths.
DynamicLibrary loadMacOsOpus() => DynamicLibrary.open(
      '${File(Platform.resolvedExecutable).parent.parent.path}/Frameworks/opus.framework/opus',
    );
