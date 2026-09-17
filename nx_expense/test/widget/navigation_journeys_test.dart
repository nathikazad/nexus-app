import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:nx_expense/core/theme/app_theme.dart';
import 'package:nx_expense/core/motion/expense_motion.dart';
import 'package:flutter/services.dart';
import 'package:nx_expense/features/expense/expense_list_view_model.dart';
import 'package:nx_expense/domain/expense/expense_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_expense/data/providers.dart';
import 'package:nx_expense/domain/expense/expense.dart';
import 'package:nx_expense/domain/expense/related_model.dart';
import 'package:nx_expense/domain/order/order.dart';
import 'package:nx_expense/domain/schema/model_type_view.dart';
import 'package:nx_expense/domain/teller/teller_transaction.dart';
import 'package:nx_expense/features/desktop/desktop_nav.dart';
import 'package:nx_expense/features/desktop/desktop_shell.dart';
import 'package:nx_expense/features/products/widgets/product_line_card.dart';
import 'package:nx_expense/router.dart';

const _expense = Expense(
  id: 1,
  name: 'Birthday shopping',
  modelTypeId: 1,
  attributes: {'cost': 25, 'date': '2026-09-15'},
  relations: {
    'Order': [RelatedModel(id: 8, name: 'Amazon order 111')],
  },
);
const _schema = ModelTypeView(
  id: 1,
  name: 'Expense',
  attributes: [
    AttributeDefView(key: 'cost', valueType: 'number'),
    AttributeDefView(key: 'date', valueType: 'date'),
  ],
);
const _order = Order(
  id: 8,
  name: 'Amazon order',
  orderNumber: '111-123',
  orderDate: '2026-09-15',
  total: 25,
  extras: {
    'source_url':
        'https://www.amazon.com/your-orders/order-details?orderID=111-123',
  },
  products: [
    OrderProduct(
      id: 9,
      name: 'Power adapters',
      unitPrice: 12.5,
      quantity: 2,
      imageUrl: '/images/test.jpg',
      itemUrl: 'https://www.amazon.com/dp/TEST',
    ),
  ],
);
final _transaction = TellerTransaction(
  time: DateTime(2026, 9, 15),
  eventId: '77',
  payload: {'description': 'Amazon payment', 'amount': '25'},
  linkedModels: const [
    LinkedTellerModel(
      id: 1,
      name: 'Birthday shopping',
      modelTypeName: 'Expense',
      linkId: '5',
    ),
  ],
);

Widget _screen(BuildContext context, Uri uri, {bool realLists = false}) {
  if (!realLists && DesktopShell.sections.contains(uri.path)) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => navPush(context, '/expense/1'),
          child: Text('List ${uri.path}'),
        ),
      ),
    );
  }
  // List data itself is tested separately; keep the real destination builder for details.
  if (uri.path.startsWith('/expenses/by-')) {
    return Scaffold(
      appBar: AppBar(leading: BackButton(onPressed: () => navBack(context))),
      body: const Text('Scoped expenses'),
    );
  }
  return buildExpenseDestination(context, uri);
}

Future<GoRouter> _mount(
  WidgetTester tester, {
  required Size size,
  String initial = '/expense/1',
  bool realLists = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      ShellRoute(
        builder: (context, state, child) => DesktopShell(
          uri: state.uri,
          child: child,
          buildDestination: (uri) => Builder(
            builder: (context) => _screen(context, uri, realLists: realLists),
          ),
        ),
        routes: [
          for (final path in [
            '/expenses',
            '/dashboard',
            '/budget',
            '/teller',
            '/orders',
            '/tag-systems',
            '/expense/:id',
            '/orders/:id',
            '/teller/transaction/:eventId',
            '/teller/link-expense',
            '/expenses/by-relation/:type/:id/:name',
          ])
            GoRoute(
              path: path,
              pageBuilder: (context, state) => ExpenseMotion.page(
                context,
                state,
                NavigationLocation(
                  uri: state.uri,
                  child: Builder(
                    builder: (context) =>
                        _screen(context, state.uri, realLists: realLists),
                  ),
                ),
              ),
            ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        expenseListDisplayedProvider.overrideWith((ref) async => [_expense]),
        expenseListSummaryProvider.overrideWith(
          (ref) async => const ExpenseSummary(count: 1, sumTotal: 25),
        ),
        orderListForUiProvider.overrideWith((ref) async => [_order]),
        orderListSummaryProvider.overrideWith(
          (ref) async => const ExpenseSummary(count: 1, sumTotal: 25),
        ),
        imageBaseUrlProvider.overrideWith((ref) => null),
        userIdProvider.overrideWith((ref) => null),
        expenseSchemaViewProvider.overrideWith((ref) async => _schema),
        expenseDetailProvider.overrideWith((ref, id) async => _expense),
        expenseTimelineLinksProvider.overrideWith((ref, id) async => []),
        orderDetailProvider.overrideWith(
          (ref, id) async => id == 8 ? _order : null,
        ),
        transactionRouteProvider.overrideWith((ref, key) async => _transaction),
      ],
      child: RepaintBoundary(
        key: const Key('preview'),
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: buildExpenseTheme(),
          routerConfig: router,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (Platform.environment['NX_PREVIEW_DIR'] != null) {
    await tester.runAsync(() async {
      final loader = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await loader.load();
      await GoogleFonts.pendingFonts();
    });
    await tester.pumpAndSettle();
  }
  return router;
}

void main() {
  testWidgets('real three-panel list layout fits the desktop breakpoint', (
    tester,
  ) async {
    await _mount(tester, size: const Size(1100, 900), realLists: true);
    await tester.ensureVisible(find.text('Amazon order 111').last);
    await tester.tap(find.text('Amazon order 111').last);
    await tester.pumpAndSettle();
    expect(find.text('111-123'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(tester, 'desktop');
  });
  testWidgets('real Orders list fits alongside Order details', (tester) async {
    await _mount(
      tester,
      size: const Size(1100, 900),
      realLists: true,
      initial: '/orders/8',
    );
    expect(find.text('Power adapters'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('order and product actions launch their saved URLs', (
    tester,
  ) async {
    final launched = <String>[];
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method == 'launch') {
        launched.add((call.arguments as Map)['url'] as String);
      }
      return true;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await _mount(tester, size: const Size(390, 844), initial: '/orders/8');
    await tester.tap(find.text('Open original order'));
    await tester.pumpAndSettle();
    tester.widget<ProductLineCard>(find.byType(ProductLineCard)).onOpenItem!();
    await tester.pumpAndSettle();
    expect(launched, [_order.sourceUrl, _order.products.single.itemUrl]);
    await _capture(tester, 'phone');
  });

  for (final size in [
    const Size(390, 844),
    const Size(1100, 900),
    const Size(1440, 900),
  ]) {
    testWidgets('expense opens actual Order and returns at ${size.width}', (
      tester,
    ) async {
      final router = await _mount(tester, size: size);
      await tester.ensureVisible(find.text('Amazon order 111').last);
      await tester.tap(find.text('Amazon order 111').last);
      await tester.pumpAndSettle();
      expect(find.text('111-123'), findsOneWidget);
      expect(find.text('Power adapters'), findsOneWidget);
      expect(find.text('Open original order'), findsOneWidget);
      final card = tester.widget<ProductLineCard>(find.byType(ProductLineCard));
      expect(card.imageUrl, '/images/test.jpg');
      expect(card.lineTotal, 25);
      expect(card.onOpenItem, isNotNull);
      if (size.width >= 1100) {
        expect(find.text('Birthday shopping'), findsOneWidget);
        expect(find.text('List /expenses'), findsOneWidget);
      }
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Birthday shopping'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('resize preserves Order and desktop source pane', (tester) async {
    await _mount(tester, size: const Size(1440, 900));
    await tester.ensureVisible(find.text('Amazon order 111').last);
    await tester.tap(find.text('Amazon order 111').last);
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(find.text('111-123'), findsOneWidget);
    expect(find.text('Birthday shopping'), findsNothing);
    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpAndSettle();
    expect(find.text('111-123'), findsOneWidget);
    expect(find.text('Birthday shopping'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'direct Order deep link has safe Back and selected Orders section',
    (tester) async {
      await _mount(tester, size: const Size(1440, 900), initial: '/orders/8');
      expect(
        tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .selectedIndex,
        4,
      );
      await tester.tap(find.byIcon(Icons.arrow_back).last);
      await tester.pumpAndSettle();
      expect(find.text('List /orders'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('transaction to expense retains transaction for Back', (
    tester,
  ) async {
    await _mount(
      tester,
      size: const Size(390, 844),
      initial: transactionLocation(_transaction),
    );
    await tester.ensureVisible(find.text('Birthday shopping'));
    await tester.tap(find.text('Birthday shopping'));
    await tester.pumpAndSettle();
    expect(find.text('Amazon order 111'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await tester.pumpAndSettle();
    expect(find.text('Amazon payment'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('malformed Order ID shows recoverable page', (tester) async {
    await _mount(tester, size: const Size(390, 844), initial: '/orders/bad');
    expect(find.text('Invalid page address'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _capture(WidgetTester tester, String name) async {
  final directory = Platform.environment['NX_PREVIEW_DIR'];
  if (directory == null) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('preview')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File('$directory/$name.png').writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}
