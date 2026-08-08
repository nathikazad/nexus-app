import 'package:flutter_test/flutter_test.dart';
import 'package:nx_live_agent_burner/main.dart';

void main() {
  testWidgets('shows the burner credential gate and validation surfaces', (
    tester,
  ) async {
    await tester.pumpWidget(const BurnerApp());

    expect(find.text('LIVE AGENT BURNER'), findsOneWidget);
    expect(find.text('Start voice session'), findsOneWidget);
    expect(find.text('TRANSCRIPT'), findsOneWidget);
    expect(find.text('TOOL & LIFECYCLE LOG'), findsOneWidget);
  });
}
