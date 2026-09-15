import 'package:flutter_test/flutter_test.dart';
import 'package:nx_offline/nx_offline.dart';

void main() {
  for (final web in [true, false]) {
    test('policy selects only the ${web ? "web" : "native"} data path', () {
      final policy = AppDataPolicy(isWeb: web);
      expect(policy.storesOfflineData, !web);
      expect(policy.downloadsLibrary, !web);
      var nativeCalls = 0;
      var webCalls = 0;
      policy.select(native: () => nativeCalls++, web: () => webCalls++);
      expect(nativeCalls, web ? 0 : 1);
      expect(webCalls, web ? 1 : 0);
    });
  }
}
