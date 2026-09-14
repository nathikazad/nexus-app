import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_flutter_ink_test/main.dart';

void main() {
  testWidgets('static shell creates one hybrid native widget', (tester) async {
    final calls = <MethodCall>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      calls.add(call);
      return null;
    });
    await tester.pumpWidget(const InkTest());
    await tester.pumpAndSettle();
    expect(find.text('NX Flutter Ink Test'), findsOneWidget);
    final create = calls.where((c) => c.method == 'create').single;
    expect((create.arguments as Map)['viewType'], 'nx_ink_test/stock');
    expect((create.arguments as Map)['hybrid'], true);
    final count = calls.length;
    await tester.pump(const Duration(seconds: 3));
    expect(calls.length, count);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
  });
}
