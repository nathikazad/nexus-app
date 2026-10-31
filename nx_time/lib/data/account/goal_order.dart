import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/account.dart';

final goalOrderProvider = FutureProvider<List<int>>((ref) async {
  final account = await ref.watch(currentAccountProvider.future);
  final order = account?.preferences['goal_order'];
  return order is List ? order.whereType<int>().toList() : [];
});
