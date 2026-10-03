import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/features/tasks/task_participants.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_time/data/domains/domain_appearance.dart';
import 'package:nx_time/data/domains/domain_workspace.dart';
import 'package:nx_time/domain/tasks/task.dart';
import 'package:nx_time/features/tasks/tasks_page.dart';
import 'package:nx_time/features/tasks/task_view_models.dart';

class _Domains extends TimeDomains {
  @override
  Future<DomainWorkspace> build() async =>
      DomainWorkspace(
          user: User(userId: '3', preset: BackendPreset.localhost),
          memberships: const [
            DomainMembership(
              id: 3,
              name: 'Personal',
              role: 'owner',
              kind: 'personal',
            ),
            DomainMembership(
              id: 1,
              name: 'Home',
              role: 'member',
              kind: 'shared',
            ),
          ],
          personalId: 3,
          selectedIds: {1, 3},
          clients: {},
        )
        ..remember(3, [30])
        ..remember(1, [10, 40]);
}

void main() {
  test('an account with null preferences loads an empty root', () async {
    final client = GraphQLClient(
      cache: GraphQLCache(),
      link: Link.function((request, [forward]) async* {
        yield const Response(
          response: {},
          data: {
            '__typename': 'Query',
            'allUsers': {
              '__typename': 'UsersConnection',
              'nodes': [
                {'__typename': 'User', 'id': 3, 'preferences': null},
              ],
            },
          },
        );
      }),
    );
    addTearDown(client.link.dispose);
    expect(await readDomainPreferenceRoot(client, 3), isEmpty);
  });
  test('preferences preserve unrelated root and domain fields', () {
    final root = <String, dynamic>{
      'model_type_colors': {'Work': '#123456'},
      'domains': {
        '3': {'custom': true},
        '1': {'label': 'Family'},
      },
    };
    final style = DomainAppearance.defaults('Personal', 0);
    final merged = mergeDomainAppearance(root, 3, style);
    expect(merged['model_type_colors'], root['model_type_colors']);
    expect(merged['domains']['1'], {'label': 'Family'});
    expect(merged['domains']['3']['custom'], true);
    expect(root['domains']['3'], {'custom': true});
    expect(style.accent, isNot(style.secondary));
    final decoded = DomainAppearance.read(
      merged['domains']['3'],
      DomainAppearance.defaults('Other', 1),
    );
    expect(decoded.accent, style.accent);
    expect(decoded.secondary.toARGB32(), style.secondary.toARGB32());
    expect(decoded.label, 'Personal');
  });
  test('invalid stored colors use stable defaults', () {
    final fallback = DomainAppearance.defaults('Home', 1);
    final parsed = DomainAppearance.read({
      'label': '',
      'accent': 'bad',
      'secondary_accent': '#00AA88',
    }, fallback);
    expect(parsed.label, 'Home');
    expect(parsed.accent, fallback.accent);
    expect(parsed.secondary, const Color(0xFF00AA88));
  });
  testWidgets('unassigned tasks stay in the main list without headings', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          timeDomainsProvider.overrideWith(_Domains.new),
          taskDomainMembersProvider.overrideWith(
            (ref, id) async => {'3': 'Me'},
          ),
          domainAppearancesProvider.overrideWith(
            (ref) async => {
              3: DomainAppearance.defaults('My life', 0),
              1: DomainAppearance.defaults('Our home', 1),
            },
          ),
          recentlyCompletedTasksProvider.overrideWith((ref) async => []),
          tasksForTodayProvider.overrideWith(
            (ref) async => const [
              Task(id: 10, name: 'Laundry', modelTypeId: 9),
              Task(id: 30, name: 'Read book', modelTypeId: 9),
              Task(
                id: 40,
                name: 'Not responsible',
                modelTypeId: 9,
                participants: {
                  '3': {'assigned': false},
                },
              ),
            ],
          ),
          projectBreadcrumbLabelsProvider.overrideWith((ref) async => {}),
        ],
        child: const MaterialApp(home: Scaffold(body: TasksPage())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('My life'), findsNothing);
    expect(find.text('My tasks'), findsNothing);
    expect(find.text('Other shared tasks'), findsNothing);
    expect(find.text('Our home'), findsOneWidget);
    expect(find.text('Unassigned'), findsNothing);
    expect(find.text('Other Tasks (1)'), findsOneWidget);
    expect(find.text('Not responsible'), findsNothing);
    await tester.tap(find.text('Other Tasks (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Not responsible'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Read book')).dy,
      lessThan(tester.getTopLeft(find.text('Laundry')).dy),
    );
  });
}
