import FlutterMacOS
import opus

public final class NxOpusMacosPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        // Keep a native link dependency so Xcode embeds the dynamic framework.
        _ = opus_get_version_string()
    }
}
