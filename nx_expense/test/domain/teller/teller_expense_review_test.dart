import 'package:flutter_test/flutter_test.dart';
import 'package:nx_expense/domain/teller/teller_expense_review.dart';

void main() {
  group('TellerExpenseReview', () {
    test('parses review items and serializes create decisions', () {
      final review = TellerExpenseReview.fromJson({
        'domain_id': 2,
        'summary': {'needs_review': 1},
        'items': [
          {
            'review_id': 'teller:tx-1',
            'event': {'event_id': 123, 'event_time': '2026-05-18T12:00:00'},
            'transaction': {
              'id': 'tx-1',
              'date': '2026-05-18',
              'amount': '-59.75',
              'description': 'TRADER JOE',
              'counterparty_name': 'Trader Joe',
              'type': 'card_payment',
            },
            'suggested_expense': {
              'name': 'Trader Joe',
              'description': 'TRADER JOE',
              'cost': '-59.75',
              'date': '2026-05-18T12:00:00',
              'company': {'existing_company_id': 55, 'name': 'Trader Joe'},
              'tags': [
                {
                  'system': 'Spending Category',
                  'path': ['Food', 'Groceries'],
                  'tag_node_id': 77,
                },
              ],
            },
            'candidate_existing_expenses': <dynamic>[],
            'recommended_action': 'create_expense',
            'available_actions': ['create_expense', 'skip'],
          },
        ],
      });

      expect(review.domainId, 2);
      expect(review.items.single.transaction.counterpartyName, 'Trader Joe');
      expect(review.items.single.suggestedExpense.companyId, 55);
      expect(
        review.items.single.suggestedExpense.tags.single.label,
        'Spending Category / Food / Groceries',
      );
      expect(review.items.single.createExpenseDecision(), {
        'review_id': 'teller:tx-1',
        'event_id': 123,
        'action': 'create_expense',
        'expense': {
          'name': 'Trader Joe',
          'description': 'TRADER JOE',
          'cost': '-59.75',
          'date': '2026-05-18T12:00:00',
          'company_id': 55,
          'tags': [
            {
              'system': 'Spending Category',
              'path': ['Food', 'Groceries'],
              'tag_node_id': 77,
            },
          ],
        },
      });
    });

    test('serializes link and skip decisions', () {
      final item = TellerExpenseReviewItem.fromJson({
        'review_id': 'teller:tx-2',
        'event': {'event_id': '124'},
        'transaction': {'amount': '-5.97'},
        'suggested_expense': {},
        'candidate_existing_expenses': [
          {'model_id': '3131', 'name': 'Amazon order', 'cost': '-5.97'},
        ],
      });

      expect(item.linkExistingDecision(3131), {
        'review_id': 'teller:tx-2',
        'event_id': 124,
        'action': 'link_existing_expense',
        'existing_expense_id': 3131,
      });
      expect(item.skipDecision(), {
        'review_id': 'teller:tx-2',
        'event_id': 124,
        'action': 'skip',
        'reason': 'user_review_skip',
      });
    });
  });
}
