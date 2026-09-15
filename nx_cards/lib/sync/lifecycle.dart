import 'package:nx_db/app_session.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/browser/browser_providers.dart';

final class CardSyncLifecycle extends ConsumerWidget {
  const CardSyncLifecycle({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppDataHost(
      session: ref.watch(cardsDataSessionProvider),
      child: child,
    );
  }
}
