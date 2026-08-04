import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/composition/cards_composition.dart';
import 'package:nx_offline/nx_offline.dart';

final class CardsOfflineLifecycle extends ConsumerWidget {
  const CardsOfflineLifecycle({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OfflineLifecycle(
      synchronize: ref.watch(cardsLifecycleSyncProvider),
      onlineChanges: ref.watch(cardsConnectivityChangesProvider),
      child: child,
    );
  }
}
