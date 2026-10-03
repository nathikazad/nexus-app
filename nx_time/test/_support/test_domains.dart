import 'package:nx_time/domain/goals/goal_repository.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_time/data/domains/domain_workspace.dart';

class TestDomains extends TimeDomains {
  TestDomains(this.client, {this.goals});
  final GoalRepository? goals;
  final GraphQLClient client;
  @override
  Future<DomainWorkspace> build() async => _Workspace(
    goalRepository: goals,
    user: User(userId: '1', preset: BackendPreset.localhost),
    memberships: const [
      DomainMembership(
        id: 1,
        name: 'Personal',
        role: 'owner',
        kind: 'personal',
      ),
    ],
    personalId: 1,
    selectedIds: {1},
    clients: {1: client},
  );
}

class _Workspace extends DomainWorkspace {
  _Workspace({
    this.goalRepository,
    required super.user,
    required super.memberships,
    required super.personalId,
    required super.selectedIds,
    required super.clients,
  });
  final GoalRepository? goalRepository;
  @override
  GoalRepository goals(int id) => goalRepository ?? super.goals(id);
}
