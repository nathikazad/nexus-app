import 'package:flutter_test/flutter_test.dart';
import 'package:nx_expense/util/teller_display.dart';

void main() {
  group('tellerDetailHeadline', () {
    test('counterparty name when present', () {
      expect(
        tellerDetailHeadline({
          'details': {'counterparty': {'name': 'Vendor Inc'}},
        }),
        'Vendor Inc',
      );
    });

    test('Transaction when no counterparty', () {
      expect(tellerDetailHeadline({'description': 'x'}), 'Transaction');
    });
  });

  group('tellerDetailDateLabel', () {
    test('uses payload date when set', () {
      final eventTime = DateTime.utc(2026, 1, 15);
      final s = tellerDetailDateLabel({'date': '2026-03-20'}, eventTime);
      expect(s, isNot('—'));
      expect(s.contains('2026'), isTrue);
    });

    test('falls back to eventTime when no payload date', () {
      final eventTime = DateTime.utc(2026, 2, 1, 12);
      final s = tellerDetailDateLabel({}, eventTime);
      expect(s, isNot('—'));
    });
  });
}
