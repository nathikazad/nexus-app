import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cooking/data/fake_cooking_repository.dart';
import 'package:nx_cooking/domain/cooking_repository.dart';

/// Swap [FakeCookingRepository] for a real implementation when PGDB is wired.
final cookingRepositoryProvider = Provider<CookingRepository>(
  (ref) => FakeCookingRepository(),
);
